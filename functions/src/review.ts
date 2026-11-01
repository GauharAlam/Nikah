import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { getDownloadURL, getStorage } from 'firebase-admin/storage';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import { accountRef, db, idArg, limits, notify, reviewerUid, stringArg } from './shared';

function cardFrom(uid: string, d: Record<string, any>, photoUrls: string[]) {
  const location = [d.homeCity, d.homeState].filter(Boolean).join(', ');
  const universities: string[] = d.almaMaters ?? [];
  return {
    id: uid, name: d.fullName, gender: d.gender, dateOfBirth: d.dateOfBirth, photos: photoUrls,
    profession: d.profession, employer: d.company ?? '', education: d.qualification,
    university: universities.join(', '), location, country: d.homeCountry ?? '', caste: d.caste,
    maritalStatus: d.maritalStatus, marriageReadiness: d.marriageReadiness, height: d.height,
    aboutMe: d.aboutMe ?? '', selfManaged: d.managedBy !== 'family', verified: false, live: true,
    partnerCaste: d.partnerCaste ?? '', sect: d.sect ?? '', prayer: d.prayer ?? '', practices: d.practices ?? [], children: d.children ?? '',
    photoPrivacy: d.photoPrivacy === 'matches' ? 'matches' : 'everyone',
    showCaste: d.showCaste !== false, allowFamilyShare: d.allowFamilyShare !== false,
    approvedAt: FieldValue.serverTimestamp(), lastActiveAt: FieldValue.serverTimestamp(),
  };
}

export const listReviewQueue = onCall(async (req) => {
  reviewerUid(req);
  const submitted = await db.collection('accounts').where('stage', '==', 'submitted')
    .orderBy('submittedAt').limit(50).get();
  const held = await db.collection('profiles').where('held', '==', true).limit(50).get();
  const edits = await db.collection('accounts').where('editsPending', '==', true).limit(50).get();
  const queued = { docs: [...submitted.docs, ...edits.docs] };
  const drafts = await Promise.all(queued.docs.map((d) => db.doc(`drafts/${d.id}`).get()));
  const docs = await Promise.all(queued.docs.map((d) => d.ref.collection('documents').get()));
  return {
    items: queued.docs.map((d, i) => ({
      uid: d.id, draft: drafts[i].data() ?? {}, isEdit: d.data().editsPending === true,
      documents: docs[i].docs.map((x) => ({ type: x.id, status: x.data().status, count: (x.data().paths ?? []).length })),
    })),
    held: held.docs.map((d) => ({ uid: d.id, name: d.data().name, reports: d.data().reportCount ?? 0 })),
  };
});

export const getDocumentUrl = onCall(async (req) => {
  reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  const type = idArg(req.data?.type, 'type');
  const snap = await db.doc(`accounts/${uid}/documents/${type}`).get();
  const paths: string[] = snap.data()?.paths ?? [];
  const urls = await Promise.all(paths.map(async (p) => {
    const [url] = await getStorage().bucket().file(p).getSignedUrl({
      action: 'read', expires: Date.now() + 5 * 60 * 1000,
    });
    return url;
  }));
  return { urls };
});

export const reviewProfile = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  const approve = req.data?.approve === true;
  const reason = approve ? '' : stringArg(req.data?.reason, 'reason', 300);
  const draft = (await db.doc(`drafts/${uid}`).get()).data();
  if (!draft) throw new HttpsError('not-found', 'Draft not found.');
  const paths: string[] = draft.photos ?? [];
  if (!paths.every((p) => p.startsWith(`photos/${uid}/`) && !p.includes('..'))) {
    throw new HttpsError('failed-precondition', 'Photos must belong to this member.');
  }
  const photoUrls = approve && paths.length > 0
    ? await Promise.all(paths.map((p) => getDownloadURL(getStorage().bucket().file(p))))
    : [];

  const account = (await accountRef(uid).get()).data() ?? {};
  const isEdit = account.editsPending === true && account.stage === 'approved';
  const batch = db.batch();
  if (isEdit && !approve) {
    batch.set(accountRef(uid), { editsPending: false, rejectionReason: reason }, { merge: true });
    notify(batch, uid, 'review', 'Your changes were not published', reason, '/profile/edit');
    await batch.commit();
    return { ok: true };
  }
  if (approve) {
    batch.set(db.doc(`profiles/${uid}`), { ...cardFrom(uid, draft, photoUrls), held: FieldValue.delete() }, { merge: true });
    batch.set(accountRef(uid), {
      stage: 'approved', approvedAt: FieldValue.serverTimestamp(), reviewedBy: reviewer,
      phone: draft.phone ?? '', editsPending: false,
    }, { merge: true });
    notify(batch, uid, 'review', isEdit ? 'Your changes are live' : 'Your profile is approved',
      isEdit ? 'Your profile was updated.' : 'Your profile is now live.', '/home/discovery');
  } else {
    batch.set(accountRef(uid), { stage: 'rejected', rejectionReason: reason, reviewedBy: reviewer }, { merge: true });
    if ((await db.doc(`profiles/${uid}`).get()).exists) batch.update(db.doc(`profiles/${uid}`), { live: false });
    notify(batch, uid, 'review', 'Your profile needs changes', reason, '/review/status');
  }
  await batch.commit();
  // The claim opens member-only rules, so it follows the committed decision.
  const user = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(uid, { ...(user.customClaims ?? {}), approved: approve });
  if (approve && !isEdit) await rewardInviter(uid, draft.inviteCode);
  return { ok: true };
});

/** Paid once, only when the invited member passes review, so fake sign-ups earn nothing. */
async function rewardInviter(uid: string, rawCode: unknown): Promise<void> {
  const code = R.normalizeCode(rawCode);
  if (!code) return;
  const lim = await limits();
  await db.runTransaction(async (tx) => {
    const invite = await tx.get(db.doc(`inviteCodes/${code}`));
    const inviter = invite.data()?.uid as string | undefined;
    const claim = db.doc(`inviteClaims/${uid}`);
    if (!inviter || inviter === uid || (await tx.get(claim)).exists) return;
    const acc = (await tx.get(accountRef(inviter))).data() ?? {};
    const reward = R.inviteReward(acc.inviteCredits, lim);
    tx.set(claim, { inviter, reward, createdAt: FieldValue.serverTimestamp() });
    tx.set(accountRef(inviter), {
      invitedCount: FieldValue.increment(1), inviteCredits: FieldValue.increment(reward),
      purchasedCredits: FieldValue.increment(reward),
    }, { merge: true });
    if (reward > 0) notify(tx, inviter, 'contact', 'You earned contact credits', 'Someone you invited was approved.', '/invite');
  });
}

export const reviewDocument = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  const type = idArg(req.data?.type, 'type');
  const approve = req.data?.approve === true;
  const reason = approve ? '' : stringArg(req.data?.reason, 'reason', 300);
  const ref = db.doc(`accounts/${uid}/documents/${type}`);

  const batch = db.batch();
  batch.set(ref, approve
    ? { status: 'approved', reviewedBy: reviewer }
    : { status: 'rejected', rejectionReason: reason, reviewedBy: reviewer }, { merge: true });
  notify(batch, uid, 'verification', approve ? 'Document approved' : 'Document needs attention',
    approve ? 'Your document passed review.' : reason, '/profile/verify');
  await batch.commit();

  const docs = await ref.parent.get();
  const approved = new Set(docs.docs.filter((d) => d.data().status === 'approved').map((d) => d.id));
  const verified = approved.has('name-proof') && approved.has('education-proof');
  const profile = db.doc(`profiles/${uid}`);
  if ((await profile.get()).exists) await profile.update({ verified, verifiedDocs: [...approved].sort() });
  return { ok: true };
});
