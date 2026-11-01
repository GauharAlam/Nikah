import { FieldValue } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import { approvedUid, blockRef, closeMatch, db, idArg, limits, stringArg, uidOf } from './shared';

export const updatePrivacy = onCall(async (req) => {
  const uid = approvedUid(req);
  const update: Record<string, unknown> = {};
  if (req.data?.photoPrivacy === 'everyone' || req.data?.photoPrivacy === 'matches') update.photoPrivacy = req.data.photoPrivacy;
  if (typeof req.data?.showCaste === 'boolean') update.showCaste = req.data.showCaste;
  if (typeof req.data?.allowFamilyShare === 'boolean') update.allowFamilyShare = req.data.allowFamilyShare;
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
  await blockRef(uid, target).set({ target, createdAt: FieldValue.serverTimestamp() });
  await closeMatch(uid, target, 'blocked');
  const pending = [R.proposalId(uid, target), R.proposalId(target, uid)];
  await Promise.all(pending.map((id) => db.runTransaction(async (tx) => {
    const ref = db.doc(`proposals/${id}`);
    if ((await tx.get(ref)).data()?.status === 'pending') tx.update(ref, { status: 'declined' });
  })));
  return { ok: true };
});

export const reportProfile = onCall(async (req) => {
  const uid = uidOf(req);
  const target = idArg(req.data?.target, 'target');
  // One document per reporter and target, so one member cannot trigger a hold alone.
  await db.doc(`reports/${R.proposalId(uid, target)}`).set({
    reporter: uid, target, reason: stringArg(req.data?.reason, 'reason', R.REPORT_REASON_MAX),
    status: 'open', createdAt: FieldValue.serverTimestamp(),
  });
  const reports = await db.collection('reports').where('target', '==', target).where('status', '==', 'open').count().get();
  const count = reports.data().count;
  const profile = db.doc(`profiles/${target}`);
  if ((await profile.get()).exists) {
    await profile.update(R.shouldHold(count, await limits())
      ? { live: false, held: true, reportCount: count }
      : { reportCount: count });
  }
  return { ok: true };
});
