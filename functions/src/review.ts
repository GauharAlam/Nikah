import { getAuth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import { accountRef, audit, checkUpload, db, idArg, limits, notify, readUrl, reviewerUid, stringArg, tokenUrl } from './shared';

/** What members may see of a reviewed draft. */
function cardFrom(uid: string, d: Record<string, any>, photoUrls: string[], photoPaths: string[]) {
  const location = [d.homeCity, d.homeState].filter(Boolean).join(', ');
  const universities: string[] = d.almaMaters ?? [];
  return {
    id: uid, name: d.fullName, gender: d.gender, dateOfBirth: d.dateOfBirth, photos: photoUrls, photoPaths,
    profession: d.profession, employer: d.company ?? '', education: d.qualification,
    university: universities.join(', '), location, country: d.homeCountry ?? '', caste: d.caste ?? '',
    maritalStatus: d.maritalStatus, marriageReadiness: d.marriageReadiness, height: d.height,
    aboutMe: d.aboutMe ?? '', selfManaged: d.managedBy !== 'family', verified: false, live: true,
    partnerCaste: d.partnerCaste ?? '', sect: d.sect ?? '', prayer: d.prayer ?? '', practices: d.practices ?? [], children: d.children ?? '',
    languages: d.preferredLanguage ?? '', graduationYear: d.graduationYear ?? '', educationStatus: d.educationStatus ?? '',
    employmentStatus: d.employmentStatus ?? '', workCity: d.workCity ?? '', careerDescription: d.careerDescription ?? '',
    family: {
      type: d.familyType ?? '', background: d.familyBackground ?? '', values: d.familyValues ?? '',
      location: d.familyLocation ?? '', siblings: d.siblings ?? '',
    },
    photoPrivacy: d.photoPrivacy === 'matches' ? 'matches' : 'everyone',
    showCaste: d.showCaste !== false, allowFamilyShare: d.allowFamilyShare !== false,
    approvedAt: FieldValue.serverTimestamp(), lastActiveAt: FieldValue.serverTimestamp(),
  };
}

export const listReviewQueue = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const submissions = await db.collection('submissions').orderBy('createdAt').limit(50).get();
  const held = await db.collection('profiles').where('held', '==', true).limit(50).get();
  // Nobody sees their own submission in the queue.
  const queued = submissions.docs.filter((d) => d.id !== reviewer);
  const items = await Promise.all(queued.map(async (s) => {
    const draft = s.data().draft ?? {};
    const docs = await accountRef(s.id).collection('documents').get();
    const paths: string[] = (draft.photos ?? []).filter((p: string) => p.startsWith(`photos/${s.id}/`));
    const photoUrls = await Promise.all(paths.map((p) => readUrl(p, 15).catch(() => '')));
    return {
      uid: s.id, draft, version: s.data().version, isEdit: s.data().kind === 'edit',
      photos: paths.map((path, i) => ({ path, url: photoUrls[i] })),
      documents: docs.docs.map((x) => ({
        type: x.id, status: x.data().status, count: (x.data().paths ?? []).length,
      })),
    };
  }));
  return {
    items,
    held: held.docs.map((d) => ({ uid: d.id, name: d.data().name, reports: d.data().reportCount ?? 0 })),
  };
});

export const getDocumentUrl = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  const type = idArg(req.data?.type, 'type');
  if (uid === reviewer) throw new HttpsError('permission-denied', 'You cannot review your own documents.');
  if (!R.DOC_TYPES.includes(type)) throw new HttpsError('invalid-argument', 'Unknown document type.');
  const ref = db.doc(`accounts/${uid}/documents/${type}`);
  const snap = await ref.get();
  const paths: string[] = snap.data()?.paths ?? [];
  const urls = await Promise.all(paths.map((p) => readUrl(p, 5)));
  const batch = db.batch();
  audit(batch, reviewer, 'document_viewed', uid, type);
  if (snap.data()?.status === 'pending') batch.update(ref, { status: 'under_review' });
  await batch.commit();
  return { urls };
});

/** Copies reviewed photos to a path no client can write, so approval cannot be bypassed. */
async function publishPhotos(uid: string, paths: string[], version: number): Promise<{ urls: string[]; published: string[] }> {
  const bucket = getStorage().bucket();
  const published = await Promise.all(paths.map(async (path, i) => {
    await checkUpload(path, R.PHOTO_TYPES);
    const target = `published/${uid}/${version}-${i}.jpg`;
    await bucket.file(path).copy(bucket.file(target));
    return target;
  }));
  const urls = await Promise.all(published.map(tokenUrl));
  return { urls, published };
}

async function removeOldPublished(uid: string, keep: string[]): Promise<void> {
  const [files] = await getStorage().bucket().getFiles({ prefix: `published/${uid}/` });
  await Promise.all(files.filter((f) => !keep.includes(f.name)).map((f) => f.delete().catch(() => undefined)));
}

export const reviewProfile = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  if (uid === reviewer) throw new HttpsError('permission-denied', 'You cannot review your own profile.');
  const decision = req.data?.decision;
  if (!R.isReviewDecision(decision)) throw new HttpsError('invalid-argument', 'Unknown decision.');
  const approve = decision === 'approve';
  const reason = approve ? '' : stringArg(req.data?.reason, 'reason', 300);
  const rejectedPhotos: string[] = Array.isArray(req.data?.rejectedPhotos)
    ? req.data.rejectedPhotos.filter((p: unknown) => typeof p === 'string').slice(0, 6) : [];

  const [subSnap, accSnap] = await Promise.all([db.doc(`submissions/${uid}`).get(), accountRef(uid).get()]);
  const sub = subSnap.data();
  const account = accSnap.data() ?? {};
  if (!sub || (account.stage !== 'submitted' && account.editsPending !== true)) {
    throw new HttpsError('failed-precondition', 'This profile is not waiting for review.');
  }
  if (req.data?.version !== sub.version) {
    throw new HttpsError('failed-precondition', 'This profile changed. Reload the queue.');
  }
  const draft = sub.draft as Record<string, any>;
  const isEdit = sub.kind === 'edit';
  const lim = await limits();

  const batch = db.batch();
  audit(batch, reviewer, `profile_${decision}`, uid, String(sub.version));
  batch.delete(subSnap.ref);
  if (!approve && isEdit) {
    batch.set(accountRef(uid), { editsPending: false, rejectionReason: reason, rejectedPhotos, reviewedBy: reviewer }, { merge: true });
    notify(batch, uid, 'review', 'Your changes were not published', reason, '/profile/edit');
    await batch.commit();
    return { ok: true };
  }
  if (approve) {
    const problems = R.draftProblems(draft as R.Draft, lim, new Date());
    if (problems.length > 0) throw new HttpsError('failed-precondition', problems[0], { problems });
    const paths: string[] = draft.photos ?? [];
    if (!paths.every((p) => p.startsWith(`photos/${uid}/`) && !p.includes('..'))) {
      throw new HttpsError('failed-precondition', 'Photos must belong to this member.');
    }
    const { urls, published } = await publishPhotos(uid, paths, sub.version);
    batch.set(db.doc(`profiles/${uid}`), { ...cardFrom(uid, draft, urls, published), held: FieldValue.delete() }, { merge: true });
    batch.set(accountRef(uid), {
      stage: 'approved', approvedAt: FieldValue.serverTimestamp(), reviewedBy: reviewer, editsPending: false,
      rejectionReason: FieldValue.delete(), rejectedPhotos: FieldValue.delete(),
    }, { merge: true });
    notify(batch, uid, 'review', isEdit ? 'Your changes are live' : 'Your profile is approved',
      isEdit ? 'Your profile was updated.' : 'Your profile is now live.', '/home/discovery');
    await batch.commit();
    await removeOldPublished(uid, published);
  } else {
    const stage = decision === 'changes' ? 'changes_requested' : 'rejected';
    batch.set(accountRef(uid), { stage, rejectionReason: reason, rejectedPhotos, reviewedBy: reviewer }, { merge: true });
    if ((await db.doc(`profiles/${uid}`).get()).exists) batch.update(db.doc(`profiles/${uid}`), { live: false });
    notify(batch, uid, 'review', 'Your profile needs changes', reason, '/review/status');
    await batch.commit();
  }
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
  if (!R.DOC_TYPES.includes(type)) throw new HttpsError('invalid-argument', 'Unknown document type.');
  if (uid === reviewer) throw new HttpsError('permission-denied', 'You cannot review your own documents.');
  const decision = req.data?.decision as R.DocDecision;
  const outcome = R.DOC_OUTCOME[decision];
  if (!outcome) throw new HttpsError('invalid-argument', 'Unknown decision.');
  const approve = decision === 'approve';
  const reason = approve ? '' : stringArg(req.data?.reason, 'reason', 300);
  const ref = db.doc(`accounts/${uid}/documents/${type}`);

  await db.runTransaction(async (tx) => {
    if (!R.documentAwaitsReview((await tx.get(ref)).data()?.status)) {
      throw new HttpsError('failed-precondition', 'This document is not waiting for review.');
    }
    tx.set(ref, {
      status: outcome, reviewedBy: reviewer, reviewedAt: FieldValue.serverTimestamp(),
      rejectionReason: approve ? FieldValue.delete() : reason,
    }, { merge: true });
    audit(tx, reviewer, `document_${decision}`, uid, type);
    notify(tx, uid, 'verification', approve ? 'Document approved' : 'Document needs attention',
      approve ? 'Your document passed review.' : reason, '/profile/verify');
  });

  const docs = await ref.parent.get();
  const approved = new Set(docs.docs.filter((d) => d.data().status === 'approved').map((d) => d.id));
  const verified = approved.has('name-proof') && approved.has('education-proof');
  const profile = db.doc(`profiles/${uid}`);
  if ((await profile.get()).exists) await profile.update({ verified, verifiedDocs: [...approved].sort() });
  return { ok: true };
});
