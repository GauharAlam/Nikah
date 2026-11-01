import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { moveProposal } from './proposals';
import * as R from './rules';
import {
  accountRef, approvedUid, audit, blockedEitherWay, db, idArg, isPremium, newUniqueCode, notify, rateLimit, stringArg, uidOf,
} from './shared';

// A family member sees only what the owner grants, one permission at a time.
// See docs/FAMILY_ACCESS_MODEL.md. Nothing here reaches chats, documents, contact
// details or the account itself.

const familyRef = (member: string) => db.doc(`family/${member}`);
const membershipRef = (member: string, guardian: string) => familyRef(member).collection('memberships').doc(guardian);
const linkRef = (guardian: string, member: string) => db.doc(`familyLinks/${guardian}/circles/${member}`);
const inviteIndex = (code: string) => db.doc(`familyInviteIndex/${R.hashOf(code)}`);

function history(writer: FirebaseFirestore.Transaction | FirebaseFirestore.WriteBatch, member: string, actor: string, action: string, detail = ''): void {
  (writer as FirebaseFirestore.WriteBatch).set(familyRef(member).collection('history').doc(), {
    actor, action, detail, at: FieldValue.serverTimestamp(),
  });
}

function phoneArg(value: unknown): string {
  const phone = stringArg(value, 'phone', 20);
  if (!/^\+[1-9]\d{6,14}$/.test(phone)) throw new HttpsError('invalid-argument', 'Enter a valid phone number.');
  return phone;
}

function permissionsArg(value: unknown): string[] {
  const list = value === undefined ? R.DEFAULT_FAMILY_PERMISSIONS : value;
  if (!R.validPermissions(list)) throw new HttpsError('invalid-argument', 'Unknown permission.');
  return [...new Set(list)];
}

function verifiedPhone(req: { auth?: { token: { phone_number?: string } } }): string {
  const phone = req.auth?.token.phone_number;
  if (!phone) throw new HttpsError('failed-precondition', 'Verify your phone number first.');
  return phone;
}

/** The member's grant to this guardian, or a refusal. Checked on every call. */
async function requirePermission(member: string, guardian: string, permission: string): Promise<void> {
  const granted = (await membershipRef(member, guardian).get()).data()?.permissions as string[] | undefined;
  if (!granted?.includes(permission)) throw new HttpsError('permission-denied', 'Not allowed.');
}

export const createFamilyInvite = onCall(async (req) => {
  const uid = approvedUid(req);
  const name = stringArg(req.data?.name, 'name', 40);
  const relationship = stringArg(req.data?.relationship, 'relationship', 20);
  if (!R.FAMILY_RELATIONSHIPS.includes(relationship)) throw new HttpsError('invalid-argument', 'Unknown relationship.');
  const phoneHash = R.hashOf(phoneArg(req.data?.phone));
  const permissions = permissionsArg(req.data?.permissions);
  await rateLimit(uid, 'family_invite', 10, 86400000);

  const ref = familyRef(uid).collection('invitations').doc();
  const expiresAt = Timestamp.fromMillis(Date.now() + R.FAMILY_INVITE_DAYS * 86400000);
  const code = await newUniqueCode((c) => inviteIndex(c), () => ({ member: uid, invitation: ref.id }));
  const batch = db.batch();
  batch.set(ref, {
    name, relationship, phoneHash, permissions, status: 'pending', expiresAt, resends: 0,
    codeHash: R.hashOf(code), createdAt: FieldValue.serverTimestamp(),
  });
  history(batch, uid, uid, 'invited', relationship);
  await batch.commit();
  return { code, id: ref.id };
});

async function openInvite(tx: FirebaseFirestore.Transaction, code: string, phone: string) {
  const index = inviteIndex(code);
  const entry = (await tx.get(index)).data();
  const unavailable = new HttpsError('not-found', 'That code is not valid or has expired.');
  if (!entry) throw unavailable;
  const ref = familyRef(entry.member).collection('invitations').doc(entry.invitation);
  const invite = (await tx.get(ref)).data();
  // The same answer for a wrong phone, so a code cannot be probed.
  if (!invite || invite.status !== 'pending' || invite.phoneHash !== R.hashOf(phone) ||
      (invite.expiresAt as Timestamp).toMillis() < Date.now()) throw unavailable;
  return { index, ref, invite, member: entry.member as string };
}

export const joinFamily = onCall(async (req) => {
  const uid = uidOf(req);
  const phone = verifiedPhone(req);
  const code = R.normalizeCode(req.data?.code);
  if (!code) throw new HttpsError('invalid-argument', 'That code is not valid.');
  await rateLimit(uid, 'family_join', 5, 3600000);
  const member = await db.runTransaction(async (tx) => {
    const { index, ref, invite, member } = await openInvite(tx, code, phone);
    if (member === uid) throw new HttpsError('invalid-argument', 'You cannot join your own family circle.');
    tx.delete(index); // Single use, so a forwarded code cannot admit anyone else.
    tx.update(ref, { status: 'accepted', respondedAt: FieldValue.serverTimestamp() });
    tx.set(membershipRef(member, uid), {
      name: invite.name, relationship: invite.relationship, permissions: invite.permissions,
      status: 'active', joinedAt: FieldValue.serverTimestamp(),
    });
    tx.set(familyRef(member), {
      guardians: FieldValue.arrayUnion(uid), names: { [uid]: invite.name },
    }, { merge: true });
    tx.set(linkRef(uid, member), { member, relationship: invite.relationship, joinedAt: FieldValue.serverTimestamp() });
    tx.set(accountRef(uid), { familyOf: member }, { merge: true });
    history(tx, member, uid, 'joined', invite.relationship);
    notify(tx, member, 'family', 'Family update', 'Someone accepted your family invitation.', '/family/circle');
    return member;
  });
  return { member };
});

export const rejectFamilyInvite = onCall(async (req) => {
  const uid = uidOf(req);
  const phone = verifiedPhone(req);
  const code = R.normalizeCode(req.data?.code);
  if (!code) throw new HttpsError('invalid-argument', 'That code is not valid.');
  await rateLimit(uid, 'family_join', 5, 3600000);
  await db.runTransaction(async (tx) => {
    const { index, ref, member } = await openInvite(tx, code, phone);
    tx.delete(index);
    tx.update(ref, { status: 'rejected', respondedAt: FieldValue.serverTimestamp() });
    history(tx, member, uid, 'rejected');
  });
  return { ok: true };
});

export const cancelFamilyInvite = onCall(async (req) => {
  const uid = uidOf(req);
  const ref = familyRef(uid).collection('invitations').doc(idArg(req.data?.id, 'id'));
  await db.runTransaction(async (tx) => {
    const invite = (await tx.get(ref)).data();
    if (invite?.status !== 'pending') throw new HttpsError('failed-precondition', 'This invitation is closed.');
    tx.delete(db.doc(`familyInviteIndex/${invite.codeHash}`));
    tx.update(ref, { status: 'cancelled' });
    history(tx, uid, uid, 'cancelled', invite.relationship);
  });
  return { ok: true };
});

export const resendFamilyInvite = onCall(async (req) => {
  const uid = uidOf(req);
  const ref = familyRef(uid).collection('invitations').doc(idArg(req.data?.id, 'id'));
  const invite = (await ref.get()).data();
  if (invite?.status !== 'pending') throw new HttpsError('failed-precondition', 'This invitation is closed.');
  if ((invite.resends ?? 0) >= R.FAMILY_INVITE_RESENDS) throw new HttpsError('resource-exhausted', 'Send a new invitation instead.');
  const code = await newUniqueCode((c) => inviteIndex(c), () => ({ member: uid, invitation: ref.id }));
  const batch = db.batch();
  batch.delete(db.doc(`familyInviteIndex/${invite.codeHash}`));
  batch.update(ref, {
    codeHash: R.hashOf(code), resends: FieldValue.increment(1),
    expiresAt: Timestamp.fromMillis(Date.now() + R.FAMILY_INVITE_DAYS * 86400000),
  });
  history(batch, uid, uid, 'resent', invite.relationship);
  await batch.commit();
  return { code };
});

export const updateGuardianPermissions = onCall(async (req) => {
  const uid = uidOf(req);
  const guardian = idArg(req.data?.guardian, 'guardian');
  const permissions = permissionsArg(req.data?.permissions);
  await db.runTransaction(async (tx) => {
    const ref = membershipRef(uid, guardian);
    if (!(await tx.get(ref)).exists) throw new HttpsError('not-found', 'That person is not in your family circle.');
    tx.update(ref, { permissions });
    history(tx, uid, uid, 'permissions_changed', permissions.join(','));
    notify(tx, guardian, 'family', 'Family update', 'Your access was updated.', '/family/view');
  });
  return { ok: true };
});

/** Removes a guardian from one circle. Takes effect on their next request. */
export async function dropGuardian(member: string, guardian: string, actor: string): Promise<void> {
  const others = await db.collection(`familyLinks/${guardian}/circles`).limit(10).get();
  const next = others.docs.map((d) => d.id).find((id) => id !== member);
  const batch = db.batch();
  batch.delete(membershipRef(member, guardian));
  batch.delete(linkRef(guardian, member));
  batch.set(familyRef(member), { guardians: FieldValue.arrayRemove(guardian), names: { [guardian]: FieldValue.delete() } }, { merge: true });
  batch.set(accountRef(guardian), { familyOf: next ?? FieldValue.delete() }, { merge: true });
  history(batch, member, actor, 'removed');
  await batch.commit();
}

export const removeGuardian = onCall(async (req) => {
  const uid = uidOf(req);
  const guardian = idArg(req.data?.guardian, 'guardian');
  const member = req.data?.member === undefined ? uid : idArg(req.data.member, 'member');
  if (uid !== member && uid !== guardian) throw new HttpsError('permission-denied', 'Not allowed.');
  await dropGuardian(member, guardian, uid);
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
  if (!d || d.live !== true || blocked || !viewed.exists && !(await isPremium(uid))) throw new HttpsError('not-found', 'This profile is unavailable.');
  if (d.allowFamilyShare === false) throw new HttpsError('permission-denied', 'This member has turned off sharing.');
  await familyRef(uid).collection('shortlist').doc(id).set({
    profileId: id, firstName: String(d.name).split(' ')[0], age: R.ageOn(d.dateOfBirth, new Date()), education: d.education ?? '',
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
  await requirePermission(member, uid, 'view_shortlist');
  await familyRef(member).collection('shortlist').doc(id).update({ [`opinions.${uid}`]: opinion });
  return { ok: true };
});

/** What this guardian may see of the member, decided per permission. */
export const familyOverview = onCall(async (req) => {
  const uid = uidOf(req);
  const member = idArg(req.data?.member, 'member');
  const granted = ((await membershipRef(member, uid).get()).data()?.permissions ?? null) as string[] | null;
  if (!granted) throw new HttpsError('permission-denied', 'Not allowed.');
  const out: Record<string, unknown> = { permissions: granted };
  if (granted.includes('view_profile')) {
    const p = (await db.doc(`profiles/${member}`).get()).data();
    out.profile = p ? {
      name: String(p.name).split(' ')[0], education: p.education ?? '', profession: p.profession ?? '',
      location: p.location ?? '', live: p.live === true,
    } : null;
  }
  if (granted.includes('view_proposals') || granted.includes('manage_proposals')) {
    const received = await db.collection('proposals').where('to', '==', member).where('status', '==', 'pending').limit(30).get();
    const profiles = await Promise.all(received.docs.map((d) => db.doc(`profiles/${d.data().from}`).get()));
    out.proposals = received.docs.map((d, i) => {
      const p = profiles[i].data();
      return {
        from: d.data().from, firstName: String(p?.name ?? '').split(' ')[0],
        education: p?.education ?? '', profession: p?.profession ?? '', location: p?.location ?? '',
      };
    });
  }
  return out;
});

/** A guardian answers a proposal for the member, only with that grant. */
export const familyRespondProposal = onCall(async (req) => {
  const uid = uidOf(req);
  const member = idArg(req.data?.member, 'member');
  const from = idArg(req.data?.from, 'from');
  await requirePermission(member, uid, 'manage_proposals');
  const accept = req.data?.accept === true;
  await moveProposal(db.doc(`proposals/${R.proposalId(from, member)}`), member, accept ? 'accepted' : 'declined');
  const batch = db.batch();
  history(batch, member, uid, accept ? 'proposal_accepted' : 'proposal_declined', from);
  audit(batch, uid, 'family_proposal_answer', member, from);
  notify(batch, member, 'family', 'Family update', 'A family member answered a proposal for you.', '/home/proposals');
  await batch.commit();
  return { ok: true };
});

// ─── The person a family-managed profile is about ────────────────────────────

/** Called by submitProfile. Returns the code the subject enters on their own phone. */
export async function issueSubjectCode(member: string, subjectPhone: string): Promise<string> {
  const code = await newUniqueCode((c) => db.doc(`subjectConfirmations/${R.hashOf(c)}`), () => ({
    member, phoneHash: R.hashOf(phoneArg(subjectPhone)), status: 'pending',
  }));
  return code;
}

export const confirmSubject = onCall(async (req) => {
  const uid = uidOf(req);
  const phone = verifiedPhone(req);
  const code = R.normalizeCode(req.data?.code);
  if (!code) throw new HttpsError('invalid-argument', 'That code is not valid.');
  await rateLimit(uid, 'family_join', 5, 3600000);
  const agree = req.data?.agree === true;
  const ref = db.doc(`subjectConfirmations/${R.hashOf(code)}`);
  await db.runTransaction(async (tx) => {
    const c = (await tx.get(ref)).data();
    if (!c || c.status !== 'pending' || c.phoneHash !== R.hashOf(phone)) {
      throw new HttpsError('not-found', 'That code is not valid or has expired.');
    }
    tx.update(ref, { status: agree ? 'confirmed' : 'refused', subject: uid });
    if (agree) {
      tx.set(accountRef(c.member), { subjectConfirmed: true, subjectUid: uid }, { merge: true });
      tx.set(db.doc(`familySubjects/${uid}`), { member: c.member });
      tx.set(accountRef(uid), { subjectOf: c.member }, { merge: true });
      tx.set(accountRef(c.member).collection('consents').doc('subject_confirmed'), {
        category: 'subject_confirmed', purpose: R.CONSENTS.subject_confirmed, policyVersion: R.POLICY_VERSION,
        acceptedAt: FieldValue.serverTimestamp(), revokedAt: null,
      });
    } else {
      tx.set(accountRef(c.member), { stage: 'changes_requested', rejectionReason: 'The person did not agree to this profile.' }, { merge: true });
      tx.delete(db.doc(`submissions/${c.member}`));
    }
    notify(tx, c.member, 'review', 'Your profile needs attention',
      agree ? 'The person confirmed this profile.' : 'The person did not agree to this profile.', '/review/status');
  });
  return { ok: true };
});

/** The subject takes the profile down. Never needs the operator's agreement. */
export const withdrawSubject = onCall(async (req) => {
  const uid = uidOf(req);
  const member = (await db.doc(`familySubjects/${uid}`).get()).data()?.member as string | undefined;
  if (!member) throw new HttpsError('permission-denied', 'Not allowed.');
  const batch = db.batch();
  batch.set(accountRef(member), {
    stage: 'changes_requested', subjectConfirmed: false, rejectionReason: 'The person withdrew their agreement.',
  }, { merge: true });
  batch.set(db.doc(`profiles/${member}`), { live: false }, { merge: true });
  batch.set(accountRef(member).collection('consents').doc('subject_confirmed'), { revokedAt: FieldValue.serverTimestamp() }, { merge: true });
  batch.delete(db.doc(`familySubjects/${uid}`));
  batch.set(accountRef(uid), { subjectOf: FieldValue.delete() }, { merge: true });
  notify(batch, member, 'review', 'Your profile was taken down', 'The person withdrew their agreement.', '/review/status');
  await batch.commit();
  const user = await getAuth().getUser(member);
  await getAuth().setCustomUserClaims(member, { ...(user.customClaims ?? {}), approved: false });
  return { ok: true };
});
