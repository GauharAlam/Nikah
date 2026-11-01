import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import { accountRef, approvedUid, blockedEitherWay, db, idArg, isPremium, newCode, stringArg, uidOf } from './shared';

// A guardian sees only what the member shares: short summaries with no photo
// or contact. They never reach conversations, documents or the account.

export const createFamilyInvite = onCall(async (req) => {
  const uid = approvedUid(req);
  const code = await newCode('familyInvites', {
    member: uid, expiresAt: Timestamp.fromMillis(Date.now() + 7 * 86400000),
  });
  return { code };
});

export const joinFamily = onCall(async (req) => {
  const uid = uidOf(req);
  const code = R.normalizeCode(req.data?.code);
  const name = stringArg(req.data?.name, 'name', 40);
  if (!code) throw new HttpsError('invalid-argument', 'That code is not valid.');
  const ref = db.doc(`familyInvites/${code}`);
  const member = await db.runTransaction(async (tx) => {
    const invite = (await tx.get(ref)).data();
    if (!invite || (invite.expiresAt as Timestamp).toMillis() < Date.now()) {
      throw new HttpsError('not-found', 'That code is not valid or has expired.');
    }
    if (invite.member === uid) throw new HttpsError('invalid-argument', 'You cannot join your own family circle.');
    tx.delete(ref); // Single use, so a forwarded code cannot admit anyone else.
    tx.set(db.doc(`family/${invite.member}`), {
      guardians: FieldValue.arrayUnion(uid), names: { [uid]: name },
    }, { merge: true });
    tx.set(accountRef(uid), { familyOf: invite.member }, { merge: true });
    return invite.member as string;
  });
  return { member };
});

export const removeGuardian = onCall(async (req) => {
  const uid = uidOf(req);
  const guardian = idArg(req.data?.guardian, 'guardian');
  const member = (req.data?.member as string | undefined) ?? uid;
  if (uid !== member && uid !== guardian) throw new HttpsError('permission-denied', 'Not allowed.');
  await db.doc(`family/${idArg(member, 'member')}`).update({
    guardians: FieldValue.arrayRemove(guardian), [`names.${guardian}`]: FieldValue.delete(),
  });
  await accountRef(guardian).set({ familyOf: FieldValue.delete() }, { merge: true });
  return { ok: true };
});

export const shareWithFamily = onCall(async (req) => {
  const uid = approvedUid(req);
  const id = idArg(req.data?.profile, 'profile');
  const [snap, blocked, viewed] = await Promise.all([
    db.doc(`profiles/${id}`).get(), blockedEitherWay(uid, id),
    accountRef(uid).collection('viewed').doc(id).get(),
  ]);
  const d = snap.data();
  if (!d || blocked || !viewed.exists && !(await isPremium(uid))) throw new HttpsError('not-found', 'This profile is unavailable.');
  if (d.allowFamilyShare === false) throw new HttpsError('permission-denied', 'This member has turned off sharing.');
  await db.doc(`family/${uid}/shortlist/${id}`).set({
    firstName: String(d.name).split(' ')[0], age: R.ageOn(d.dateOfBirth, new Date()), education: d.education ?? '',
    university: d.university ?? '', profession: d.profession ?? '', location: d.location ?? '',
    maritalStatus: d.maritalStatus ?? '', sharedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

export const giveFamilyOpinion = onCall(async (req) => {
  const uid = uidOf(req);
  const member = idArg(req.data?.member, 'member');
  const id = idArg(req.data?.profile, 'profile');
  const opinion = req.data?.opinion;
  if (!R.FAMILY_OPINIONS.includes(opinion)) throw new HttpsError('invalid-argument', 'Unknown opinion.');
  const family = (await db.doc(`family/${member}`).get()).data();
  if (!(family?.guardians as string[] | undefined)?.includes(uid)) throw new HttpsError('permission-denied', 'Not allowed.');
  await db.doc(`family/${member}/shortlist/${id}`).update({ [`opinions.${uid}`]: opinion });
  return { ok: true };
});
