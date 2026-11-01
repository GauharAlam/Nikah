import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import {
  accountRef, approvedUid, audit, blockRef, closeMatch, db, idArg, limits, notify, rateLimit, reviewerUid, stringArg, uidOf,
} from './shared';

export const updatePrivacy = onCall(async (req) => {
  const uid = approvedUid(req);
  const update: Record<string, unknown> = {};
  if (typeof req.data?.nearbyOptIn === 'boolean') update.nearbyOptIn = req.data.nearbyOptIn;
  if (typeof req.data?.allowContactRequests === 'boolean') update.allowContactRequests = req.data.allowContactRequests;
  if (req.data?.photoPrivacy === 'everyone' || req.data?.photoPrivacy === 'matches') update.photoPrivacy = req.data.photoPrivacy;
  if (typeof req.data?.showCaste === 'boolean') update.showCaste = req.data.showCaste;
  if (typeof req.data?.allowFamilyShare === 'boolean') update.allowFamilyShare = req.data.allowFamilyShare;
  if (Object.keys(update).length === 0) throw new HttpsError('invalid-argument', 'Nothing to change.');
  await Promise.all([db.doc(`profiles/${uid}`).update(update), db.doc(`drafts/${uid}`).set(update, { merge: true })]);
  return { ok: true };
});

/** Called when the app opens. Stale profiles leave discovery. */
export const touchActive = onCall(async (req) => {
  const uid = approvedUid(req);
  const profile = db.doc(`profiles/${uid}`);
  if ((await profile.get()).exists) await profile.update({ lastActiveAt: FieldValue.serverTimestamp() });
  return { ok: true };
});

export const unmatch = onCall(async (req) => {
  const uid = approvedUid(req);
  await closeMatch(uid, idArg(req.data?.other, 'other'), 'closed');
  return { ok: true };
});

export const blockProfile = onCall(async (req) => {
  const uid = uidOf(req);
  const target = idArg(req.data?.target, 'target');
  if (target === uid) throw new HttpsError('invalid-argument', 'You cannot block yourself.');
  await blockRef(uid, target).set({ target, createdAt: FieldValue.serverTimestamp() });
  await closeMatch(uid, target, 'blocked');
  // Nothing already in flight may survive the block, in either direction.
  await Promise.all([R.proposalId(uid, target), R.proposalId(target, uid)].map((id) => db.runTransaction(async (tx) => {
    const ref = db.doc(`contactRequests/${id}`);
    const request = (await tx.get(ref)).data();
    if (request?.status !== 'pending') return;
    const acc = (await tx.get(accountRef(request.from))).data();
    tx.update(ref, { status: 'closed' });
    tx.set(accountRef(request.from), {
      creditsSpent: R.creditsAfterRefund(request.month, acc?.creditsSpent, acc?.creditMonth),
    }, { merge: true });
  })));
  const pending = [R.proposalId(uid, target), R.proposalId(target, uid)];
  await Promise.all(pending.map((id) => db.runTransaction(async (tx) => {
    const ref = db.doc(`proposals/${id}`);
    if ((await tx.get(ref)).data()?.status === 'pending') tx.update(ref, { status: 'declined' });
  })));
  return { ok: true };
});

export const listBlocks = onCall(async (req) => {
  const uid = uidOf(req);
  const blocks = await accountRef(uid).collection('blocks').limit(200).get();
  const profiles = await Promise.all(blocks.docs.map((d) => db.doc(`profiles/${d.id}`).get()));
  return {
    blocks: blocks.docs.map((d, i) => ({ id: d.id, name: String(profiles[i].data()?.name ?? 'Member').split(' ')[0] })),
  };
});

/** Lifts the block only. A closed match or declined proposal stays closed. */
export const unblockProfile = onCall(async (req) => {
  const uid = uidOf(req);
  await blockRef(uid, idArg(req.data?.target, 'target')).delete();
  return { ok: true };
});

export const reportProfile = onCall(async (req) => {
  const uid = approvedUid(req);
  const target = idArg(req.data?.target, 'target');
  if (target === uid) throw new HttpsError('invalid-argument', 'You cannot report yourself.');
  const reason = req.data?.reason;
  if (!R.REPORT_REASONS.includes(reason)) throw new HttpsError('invalid-argument', 'Choose a reason.');
  const details = req.data?.details === undefined ? '' : stringArg(req.data.details, 'details', R.REPORT_DETAILS_MAX);
  const context = req.data?.context === 'conversation' ? 'conversation' : 'profile';
  await rateLimit(uid, 'report', 10, 86400000);
  const ref = db.doc(`reports/${R.proposalId(uid, target)}`);
  // One document per reporter and target, so one member cannot trigger a hold
  // alone, and a closed report stays closed.
  const created = await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return false;
    tx.set(ref, { reporter: uid, target, reason, details, context, status: 'open', createdAt: FieldValue.serverTimestamp() });
    return true;
  });
  if (created) await applyReportCount(target);
  return { ok: true };
});

/** Holds a profile once enough different members have reported it. */
async function applyReportCount(target: string): Promise<void> {
  const reports = await db.collection('reports').where('target', '==', target).where('status', '==', 'open').count().get();
  const count = reports.data().count;
  const profile = db.doc(`profiles/${target}`);
  const snap = await profile.get();
  if (!snap.exists) return;
  const hold = R.shouldHold(count, await limits());
  if (!hold || snap.data()?.held === true) {
    await profile.update({ reportCount: count });
    return;
  }
  const batch = db.batch();
  batch.update(profile, { live: false, held: true, reportCount: count });
  batch.set(accountRef(target), { held: true }, { merge: true });
  notify(batch, target, 'review', 'Your profile is being reviewed', 'Our team is taking a look. You will hear from us soon.', '/review/status');
  await batch.commit();
  await setApproved(target, false);
}

async function setApproved(uid: string, approved: boolean): Promise<void> {
  const user = await getAuth().getUser(uid).catch(() => null);
  if (user) await getAuth().setCustomUserClaims(uid, { ...(user.customClaims ?? {}), approved });
}

export const listReports = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const open = await db.collection('reports').where('status', '==', 'open').orderBy('createdAt').limit(50).get();
  const visible = open.docs.filter((d) => d.data().target !== reviewer);
  const profiles = await Promise.all(visible.map((d) => db.doc(`profiles/${d.data().target}`).get()));
  return {
    // The reporter stays out of this list, so a decision cannot be swayed by who reported.
    reports: visible.map((d, i) => ({
      id: d.id, target: d.data().target, name: profiles[i].data()?.name ?? '', reason: d.data().reason,
      details: d.data().details ?? '', context: d.data().context ?? 'profile', held: profiles[i].data()?.held === true,
      count: profiles[i].data()?.reportCount ?? 0,
    })),
  };
});

export const resolveReport = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const ref = db.doc(`reports/${idArg(req.data?.id, 'id')}`);
  const status = R.REPORT_DECISIONS[req.data?.decision];
  if (!status) throw new HttpsError('invalid-argument', 'Unknown decision.');
  const note = req.data?.note === undefined ? '' : stringArg(req.data.note, 'note', 300);
  await db.runTransaction(async (tx) => {
    const report = (await tx.get(ref)).data();
    if (!report) throw new HttpsError('not-found', 'Report not found.');
    if (report.target === reviewer) throw new HttpsError('permission-denied', 'You cannot decide a report about yourself.');
    if (report.status !== 'open') throw new HttpsError('failed-precondition', 'This report was already decided.');
    tx.update(ref, { status, note, resolvedAt: FieldValue.serverTimestamp() });
    audit(tx, reviewer, `report_${req.data.decision}`, report.target, ref.id);
  });
  return { ok: true };
});

export const releaseHold = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  if (uid === reviewer) throw new HttpsError('permission-denied', 'You cannot release your own hold.');
  const batch = db.batch();
  batch.update(db.doc(`profiles/${uid}`), { live: true, held: FieldValue.delete(), reportCount: 0 });
  batch.set(accountRef(uid), { held: FieldValue.delete() }, { merge: true });
  audit(batch, reviewer, 'hold_released', uid);
  notify(batch, uid, 'review', 'Your profile is live again', 'Our review is finished.', '/home/discovery');
  await batch.commit();
  await setApproved(uid, true);
  return { ok: true };
});
