import { getAuth } from 'firebase-admin/auth';
import { getStorage } from 'firebase-admin/storage';
import { onCall } from 'firebase-functions/v2/https';
import { accountRef, db, uidOf } from './shared';

export const deleteAccount = onCall(async (req) => {
  const uid = uidOf(req);
  await db.doc(`profiles/${uid}`).delete();
  const relations = await Promise.all([
    db.collection('proposals').where('from', '==', uid).get(),
    db.collection('proposals').where('to', '==', uid).get(),
    db.collection('contactRequests').where('from', '==', uid).get(),
    db.collection('contactRequests').where('to', '==', uid).get(),
    db.collection('contactShares').where('users', 'array-contains', uid).get(),
  ]);
  await Promise.all(relations.flatMap((s) => s.docs.map((d) => d.ref.delete())));
  const matches = await db.collection('matches').where('users', 'array-contains', uid).get();
  await Promise.all(matches.docs.map((m) => db.recursiveDelete(m.ref)));
  await db.recursiveDelete(accountRef(uid));
  await db.doc(`drafts/${uid}`).delete();
  const bucket = getStorage().bucket();
  await Promise.all([bucket.deleteFiles({ prefix: `photos/${uid}/` }), bucket.deleteFiles({ prefix: `verification/${uid}/` })]);
  await getAuth().deleteUser(uid);
  return { ok: true };
});
