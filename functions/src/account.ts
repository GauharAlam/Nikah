import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Query, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { dropGuardian } from './family';
import * as R from './rules';
import { accountRef, approvedUid, audit, db, reviewerUid, uidOf } from './shared';

/** Deletes everything a query matches, a page at a time. */
async function deleteAll(query: Query): Promise<void> {
  for (;;) {
    const page = await query.limit(200).get();
    const batch = db.batch();
    page.docs.forEach((d) => batch.delete(d.ref));
    if (page.size > 0) await batch.commit();
    if (page.size < 200) return;
  }
}

/** Each step is safe to repeat, so a failed job can simply run again. */
const STEPS: Record<string, (uid: string) => Promise<void>> = {
  hide: async (uid) => {
    if ((await db.doc(`profiles/${uid}`).get()).exists) await db.doc(`profiles/${uid}`).update({ live: false });
  },
  relations: async (uid) => {
    await Promise.all([
      deleteAll(db.collection('proposals').where('from', '==', uid)),
      deleteAll(db.collection('proposals').where('to', '==', uid)),
      deleteAll(db.collection('contactRequests').where('from', '==', uid)),
      deleteAll(db.collection('contactRequests').where('to', '==', uid)),
      deleteAll(db.collection('contactShares').where('users', 'array-contains', uid)),
    ]);
  },
  // Neither person can open a conversation once a match ends, so it goes with
  // the account. See the retention table in docs/FIREBASE_SECURITY.md.
  conversations: async (uid) => {
    const matches = await db.collection('matches').where('users', 'array-contains', uid).get();
    await Promise.all(matches.docs.map((m) => db.recursiveDelete(m.ref)));
  },
  family: async (uid) => {
    const circles = await db.collection(`familyLinks/${uid}/circles`).get();
    await Promise.all(circles.docs.map((c) => dropGuardian(c.id, uid, 'deleted')));
    const own = (await db.doc(`family/${uid}`).get()).data();
    const guardians: string[] = own?.guardians ?? [];
    await Promise.all(guardians.map((g) => dropGuardian(uid, g, 'deleted')));
    await db.recursiveDelete(db.doc(`family/${uid}`));
    await db.recursiveDelete(db.doc(`familyLinks/${uid}`));
    await deleteAll(db.collection('familyInviteIndex').where('member', '==', uid));
    await deleteAll(db.collection('subjectConfirmations').where('member', '==', uid));
    await db.doc(`familySubjects/${uid}`).delete();
    await deleteAll(db.collectionGroup('shortlist').where('profileId', '==', uid));
  },
  derived: async (uid) => {
    await Promise.all([
      deleteAll(db.collectionGroup('blocks').where('target', '==', uid)),
      deleteAll(db.collectionGroup('hidden').where('target', '==', uid)),
      deleteAll(db.collectionGroup('viewed').where('target', '==', uid)),
      deleteAll(db.collection('inviteCodes').where('uid', '==', uid)),
      db.doc(`inviteClaims/${uid}`).delete(),
    ]);
  },
  safety: async (uid) => {
    // A report about someone else stays for safety review, without the reporter.
    const made = await db.collection('reports').where('reporter', '==', uid).get();
    await Promise.all(made.docs.map((d) => d.ref.update({ reporter: FieldValue.delete() })));
  },
  payments: async (uid) => {
    // Kept for payment law, with the member's identity replaced by a hash.
    const hash = R.hashOf(uid);
    for (const name of ['purchases', 'creditLedger']) {
      const docs = await db.collection(name).where('uid', '==', uid).get();
      await Promise.all(docs.docs.map((d) => d.ref.update({ uid: hash })));
    }
  },
  profile: async (uid) => {
    await Promise.all([
      db.doc(`profiles/${uid}`).delete(), db.doc(`drafts/${uid}`).delete(), db.doc(`submissions/${uid}`).delete(),
    ]);
    await db.recursiveDelete(accountRef(uid));
  },
  files: async (uid) => {
    const bucket = getStorage().bucket();
    await Promise.all(['photos', 'published', 'verification'].map((p) => bucket.deleteFiles({ prefix: `${p}/${uid}/` })));
  },
  auth: async (uid) => {
    await getAuth().deleteUser(uid).catch((e) => {
      if (e.code !== 'auth/user-not-found') throw e;
    });
  },
};

/** Runs the steps not yet done, recording each, so a retry resumes where it stopped. */
async function processDeletion(uid: string): Promise<void> {
  const ref = db.doc(`deletionRequests/${uid}`);
  const done: string[] = (await ref.get()).data()?.done ?? [];
  for (const step of Object.keys(STEPS)) {
    if (done.includes(step)) continue;
    await STEPS[step](uid);
    await ref.update({ done: FieldValue.arrayUnion(step), updatedAt: FieldValue.serverTimestamp() });
  }
  // Only the fact of completion stays.
  await ref.update({ status: 'done', completedAt: FieldValue.serverTimestamp() });
}

export const requestAccountDeletion = onCall(async (req) => {
  const uid = uidOf(req);
  const signedInAt = Number(req.auth?.token.auth_time ?? 0) * 1000;
  if (!R.recentlySignedIn(signedInAt, Date.now())) {
    throw new HttpsError('failed-precondition', 'Please verify it is you, then try again.', { reason: 'requires-recent-login' });
  }
  const ref = db.doc(`deletionRequests/${uid}`);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return; // A repeat tap changes nothing.
    tx.set(ref, { status: 'pending', done: [], createdAt: FieldValue.serverTimestamp() });
    tx.set(accountRef(uid), { stage: 'deleting' }, { merge: true });
  });
  // Stops activity at once, even if the rest of the job is delayed.
  await getAuth().setCustomUserClaims(uid, {});
  await getAuth().revokeRefreshTokens(uid);
  try {
    await processDeletion(uid);
  } catch {
    // The hourly job picks this up. The member has already been signed out.
  }
  return { status: (await ref.get()).data()?.status };
});

export const retryDeletions = onSchedule('every 1 hours', async () => {
  const stuck = await db.collection('deletionRequests').where('status', '==', 'pending').limit(50).get();
  for (const doc of stuck.docs) await processDeletion(doc.id).catch(() => undefined);
});

/** Reviewer tool for a job that needs attention now. */
export const resumeDeletion = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = String(req.data?.uid ?? '');
  if (!(await db.doc(`deletionRequests/${uid}`).get()).exists) throw new HttpsError('not-found', 'No such request.');
  await processDeletion(uid);
  const batch = db.batch();
  audit(batch, reviewer, 'deletion_resumed', R.hashOf(uid));
  await batch.commit();
  return { ok: true };
});

/** Takes the profile out of every list without losing anything. */
export const setAccountPaused = onCall(async (req) => {
  const uid = approvedUid(req);
  const paused = req.data?.paused === true;
  const batch = db.batch();
  batch.update(db.doc(`profiles/${uid}`), { live: !paused, paused, lastActiveAt: FieldValue.serverTimestamp() });
  batch.set(accountRef(uid), { paused }, { merge: true });
  await batch.commit();
  return { paused };
});

/** The member's own records, as a single document. Never another member's private data. */
export const exportMyData = onCall(async (req) => {
  const uid = uidOf(req);
  const [account, draft, profile, consents, documents, sent, received, matches] = await Promise.all([
    accountRef(uid).get(), db.doc(`drafts/${uid}`).get(), db.doc(`profiles/${uid}`).get(),
    accountRef(uid).collection('consents').get(), accountRef(uid).collection('documents').get(),
    db.collection('proposals').where('from', '==', uid).limit(1000).get(),
    db.collection('proposals').where('to', '==', uid).limit(1000).get(),
    db.collection('matches').where('users', 'array-contains', uid).limit(500).get(),
  ]);
  const messages = await Promise.all(matches.docs.map((m) => m.ref.collection('messages')
    .where('sender', '==', uid).orderBy('sentAt', 'desc').limit(1000).get()));
  const { reviewedBy, ...ownAccount } = account.data() ?? {};
  const plain = (v: unknown): unknown => JSON.parse(JSON.stringify(v, (_, x) => (x instanceof Timestamp ? x.toDate().toISOString() : x)));
  return plain({
    exportedAt: new Date().toISOString(), account: ownAccount, draft: draft.data() ?? null,
    profile: profile.data() ?? null,
    consents: consents.docs.map((d) => d.data()),
    documents: documents.docs.map((d) => ({ type: d.id, status: d.data().status })),
    proposals: [...sent.docs, ...received.docs].map((d) => ({
      direction: d.data().from === uid ? 'sent' : 'received', status: d.data().status,
    })),
    messages: messages.flatMap((q) => q.docs.map((d) => ({ text: d.data().text, sentAt: d.data().sentAt }))),
  });
});
