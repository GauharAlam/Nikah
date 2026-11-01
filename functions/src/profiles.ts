import { FieldValue, Transaction } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { issueSubjectCode } from './family';
import * as R from './rules';
import { accountRef, approvedUid, checkUpload, db, limits, rateLimit, stringArg, uidOf } from './shared';

async function policyVersion(): Promise<string> {
  return (await db.doc('config/app').get()).data()?.policyVersion ?? R.POLICY_VERSION;
}

function recordConsents(tx: Transaction, uid: string, draft: R.Draft, version: string): void {
  const given = ['data_processing', 'marriage_intent', ...(draft.managedBy === 'family' ? ['family_authorised'] : [])];
  for (const category of given) {
    tx.set(accountRef(uid).collection('consents').doc(category), {
      category, purpose: R.CONSENTS[category], policyVersion: version,
      acceptedAt: FieldValue.serverTimestamp(), revokedAt: null,
    });
  }
}

/**
 * Validates the draft and freezes a copy. Reviewers decide on that copy, so a
 * later draft edit cannot reach members.
 */
export const submitProfile = onCall(async (req) => {
  const uid = uidOf(req);
  const phone = req.auth?.token.phone_number as string | undefined;
  if (!phone) throw new HttpsError('failed-precondition', 'Verify your phone number first.');
  await rateLimit(uid, 'submit', 10, 86400000);
  const [lim, version] = await Promise.all([limits(), policyVersion()]);
  const proof = lim.requireIdProof ? await db.doc(`accounts/${uid}/documents/name-proof`).get() : null;
  if (proof && !['pending', 'under_review', 'approved'].includes(proof.data()?.status)) {
    throw new HttpsError('failed-precondition', 'Upload your ID before submitting.');
  }
  let needsSubjectCode: string | undefined;
  const result = await db.runTransaction(async (tx) => {
    const [draftSnap, accSnap] = await Promise.all([tx.get(db.doc(`drafts/${uid}`)), tx.get(accountRef(uid))]);
    const draft = draftSnap.data() as R.Draft | undefined;
    const acc = accSnap.data() ?? {};
    const stage: string = acc.stage ?? 'draft';
    needsSubjectCode = draft?.managedBy === 'family' && acc.subjectConfirmed !== true ? draft.subjectPhone : undefined;
    if (stage === 'submitted') return { stage, version: acc.submissionVersion as number };
    if (!R.canSubmit(stage)) throw new HttpsError('failed-precondition', 'Your profile is already approved.');
    if (!draft) throw new HttpsError('failed-precondition', 'Complete your profile first.');
    const problems = R.draftProblems(draft, lim, new Date());
    if (problems.length > 0) throw new HttpsError('failed-precondition', problems[0], { problems });
    const next = (acc.submissionVersion ?? 0) + 1;
    tx.set(db.doc(`submissions/${uid}`), { kind: 'new', version: next, draft, createdAt: FieldValue.serverTimestamp() });
    tx.set(accountRef(uid), {
      stage: 'submitted', submittedAt: FieldValue.serverTimestamp(), submissionVersion: next, phone,
      rejectionReason: FieldValue.delete(), rejectedPhotos: FieldValue.delete(),
    }, { merge: true });
    recordConsents(tx, uid, draft, version);
    return { stage: 'submitted', version: next };
  });
  // The person the profile is about confirms from their own phone.
  if (result.stage === 'submitted' && needsSubjectCode) {
    const subjectCode = await issueSubjectCode(uid, needsSubjectCode);
    await accountRef(uid).set({ subjectCode }, { merge: true });
    return { ...result, subjectCode };
  }
  return result;
});

/** An approved member's changes stay private until a reviewer publishes them. */
export const submitEdits = onCall(async (req) => {
  const uid = approvedUid(req);
  const lim = await limits();
  await db.runTransaction(async (tx) => {
    const [draftSnap, accSnap] = await Promise.all([tx.get(db.doc(`drafts/${uid}`)), tx.get(accountRef(uid))]);
    const draft = draftSnap.data() as R.Draft | undefined;
    if (!draft) throw new HttpsError('failed-precondition', 'Nothing to submit.');
    const problems = R.draftProblems(draft, lim, new Date());
    if (problems.length > 0) throw new HttpsError('failed-precondition', problems[0], { problems });
    const next = (accSnap.data()?.submissionVersion ?? 0) + 1;
    tx.set(db.doc(`submissions/${uid}`), { kind: 'edit', version: next, draft, createdAt: FieldValue.serverTimestamp() });
    tx.set(accountRef(uid), {
      editsPending: true, editsAt: FieldValue.serverTimestamp(), submissionVersion: next,
      rejectionReason: FieldValue.delete(), rejectedPhotos: FieldValue.delete(),
    }, { merge: true });
  });
  return { ok: true };
});

export const submitDocument = onCall(async (req) => {
  const uid = uidOf(req);
  const type = stringArg(req.data?.type, 'type');
  if (!R.DOC_TYPES.includes(type)) throw new HttpsError('invalid-argument', 'Unknown document type.');
  const paths = req.data?.paths;
  if (!Array.isArray(paths) || paths.length === 0 || paths.length > 2) {
    throw new HttpsError('invalid-argument', 'Upload one or two files.');
  }
  const prefix = `verification/${uid}/${type}/`;
  if (!paths.every((p) => typeof p === 'string' && p.startsWith(prefix) && !p.includes('..'))) {
    throw new HttpsError('permission-denied', 'That file does not belong to you.');
  }
  const ref = db.doc(`accounts/${uid}/documents/${type}`);
  if (!R.canUploadDocument((await ref.get()).data()?.status)) {
    throw new HttpsError('failed-precondition', 'This document is already approved.');
  }
  await Promise.all(paths.map((p: string) => checkUpload(p, R.DOCUMENT_TYPES)));
  await ref.set({
    status: 'pending', paths, submittedAt: FieldValue.serverTimestamp(), rejectionReason: FieldValue.delete(),
  }, { merge: true });
  return { status: 'pending' };
});
