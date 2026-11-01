import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import { accountRef, approvedUid, db, limits, stringArg, uidOf } from './shared';

export const submitProfile = onCall(async (req) => {
  const uid = uidOf(req);
  const draft = (await db.doc(`drafts/${uid}`).get()).data() as R.Draft | undefined;
  if (!draft) throw new HttpsError('failed-precondition', 'Complete your profile first.');
  const problems = R.draftProblems(draft, await limits(), new Date());
  if (problems.length > 0) throw new HttpsError('failed-precondition', problems[0], { problems });
  const lim = await limits();
  if (lim.requireIdProof) {
    const id = await db.doc(`accounts/${uid}/documents/name-proof`).get();
    if (!['pending', 'approved'].includes(id.data()?.status)) {
      throw new HttpsError('failed-precondition', 'Upload your ID before submitting.');
    }
  }
  await accountRef(uid).set({
    stage: 'submitted', submittedAt: FieldValue.serverTimestamp(), rejectionReason: FieldValue.delete(),
  }, { merge: true });
  return { stage: 'submitted' };
});

/** An approved member's changes stay private until a reviewer publishes them. */
export const submitEdits = onCall(async (req) => {
  const uid = approvedUid(req);
  await accountRef(uid).set({ editsPending: true, editsAt: FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true };
});

const DOC_TYPES = ['name-proof', 'education-proof', 'employment-proof'];

export const submitDocument = onCall(async (req) => {
  const uid = uidOf(req);
  const type = stringArg(req.data?.type, 'type');
  if (!DOC_TYPES.includes(type)) throw new HttpsError('invalid-argument', 'Unknown document type.');
  const paths = req.data?.paths;
  if (!Array.isArray(paths) || paths.length === 0 || paths.length > 2) {
    throw new HttpsError('invalid-argument', 'Upload one or two files.');
  }
  const prefix = `verification/${uid}/${type}/`;
  if (!paths.every((p) => typeof p === 'string' && p.startsWith(prefix) && !p.includes('..'))) {
    throw new HttpsError('permission-denied', 'That file does not belong to you.');
  }
  await db.doc(`accounts/${uid}/documents/${type}`).set({
    status: 'pending', paths, submittedAt: FieldValue.serverTimestamp(), rejectionReason: FieldValue.delete(),
  }, { merge: true });
  return { status: 'pending' };
});
