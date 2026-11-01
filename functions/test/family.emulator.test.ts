// Journey 4 and every denial: a guardian gets exactly what the owner granted, for as long as they grant it.
import { before, test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { admin, code, profile, user, validDraft } from './helpers';

let db: FirebaseFirestore.Firestore;
const phone = (n: number) => `+9197765${String(n).padStart(5, '0')}`;

async function owner(uid: string) {
  await db.doc(`profiles/${uid}`).set(profile(uid, 'male'));
  return user(uid, { approved: true });
}

before(() => { db = admin().db; });

test('Journey 4: invite, accept, use, revoke, lose access', async () => {
  const m = await owner('fo1');
  const parent = await user('fg1', {}, phone(1));
  await db.doc('profiles/fc1').set(profile('fc1', 'female'));
  await db.doc('accounts/fo1/viewed/fc1').set({ target: 'fc1', at: Timestamp.now() });

  const { code: invite } = await m('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(1), permissions: ['view_shortlist', 'view_profile'] });
  await parent('joinFamily', { code: invite });
  await m('shareWithFamily', { profile: 'fc1' });

  assert.equal((await parent('familyOverview', { member: 'fo1' })).profile.name, 'fo1');
  await parent('giveFamilyOpinion', { member: 'fo1', profile: 'fc1', opinion: 'good' });

  await m('removeGuardian', { guardian: 'fg1' });
  assert.equal(await code(parent('familyOverview', { member: 'fo1' })), 'functions/permission-denied');
  assert.equal(await code(parent('giveFamilyOpinion', { member: 'fo1', profile: 'fc1', opinion: 'no' })), 'functions/permission-denied');
  assert.equal((await db.doc('accounts/fg1').get()).data()?.familyOf, undefined);
  const log = await db.collection('family/fo1/history').get();
  assert.deepEqual(log.docs.map((d) => d.data().action).sort(), ['invited', 'joined', 'removed']);
});

test('an invitation works only for the phone it was sent to', async () => {
  const m = await owner('fo2');
  const wrong = await user('fg2', {}, phone(2));
  const none = await user('fg2b', {});
  const { code: invite } = await m('createFamilyInvite', { name: 'Ami', relationship: 'mother', phone: phone(99) });
  assert.equal(await code(wrong('joinFamily', { code: invite })), 'functions/not-found');
  assert.equal(await code(none('joinFamily', { code: invite })), 'functions/failed-precondition');
  assert.equal((await db.doc('family/fo2').get()).exists, false);
});

test('codes are hashed at rest, and phone numbers are not stored', async () => {
  const m = await owner('fo3');
  const { code: invite, id } = await m('createFamilyInvite', { name: 'Ami', relationship: 'mother', phone: phone(3) });
  const doc = (await db.doc(`family/fo3/invitations/${id}`).get()).data();
  assert.ok(!JSON.stringify(doc).includes(phone(3)));
  assert.ok(!JSON.stringify(doc).includes(invite));
});

test('a guardian only gets the permissions granted, and the owner can change them', async () => {
  const m = await owner('fo4');
  const parent = await user('fg4', {}, phone(4));
  const { code: invite } = await m('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(4) });
  await parent('joinFamily', { code: invite });
  const first = await parent('familyOverview', { member: 'fo4' });
  assert.equal(first.profile, undefined);
  assert.equal(first.proposals, undefined);
  await m('updateGuardianPermissions', { guardian: 'fg4', permissions: ['view_proposals'] });
  assert.ok((await parent('familyOverview', { member: 'fo4' })).proposals);
  assert.equal(await code(m('updateGuardianPermissions', { guardian: 'fg4', permissions: ['read_chats'] })), 'functions/invalid-argument');
});

test('a guardian answers a proposal only with manage_proposals, and the owner is told', async () => {
  const m = await owner('fo5');
  await db.doc('profiles/fc5').set(profile('fc5', 'female'));
  const suitor = await user('fc5', { approved: true });
  const parent = await user('fg5', {}, phone(5));
  const { code: invite } = await m('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(5), permissions: ['view_proposals'] });
  await parent('joinFamily', { code: invite });
  await suitor('sendProposal', { to: 'fo5' });
  assert.equal(await code(parent('familyRespondProposal', { member: 'fo5', from: 'fc5', accept: true })), 'functions/permission-denied');
  await m('updateGuardianPermissions', { guardian: 'fg5', permissions: ['manage_proposals'] });
  await parent('familyRespondProposal', { member: 'fo5', from: 'fc5', accept: true });
  assert.equal((await db.doc('matches/fc5_fo5').get()).data()?.status, 'active');
  const note = await db.collection('accounts/fo5/notifications').where('type', '==', 'family').get();
  assert.ok(note.docs.some((d) => d.data().body.includes('answered a proposal')));
});

test('a guardian never becomes the owner, or an actor on the account', async () => {
  const m = await owner('fo6');
  const parent = await user('fg6', {}, phone(6));
  const { code: invite } = await m('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(6), permissions: ['view_shortlist', 'view_profile', 'view_proposals', 'manage_proposals'] });
  await parent('joinFamily', { code: invite });
  assert.equal(await code(parent('sendProposal', { to: 'fc5' })), 'functions/permission-denied');
  assert.equal(await code(parent('updateGuardianPermissions', { guardian: 'fg6', permissions: [] })), 'functions/not-found');
  assert.equal(await code(parent('removeGuardian', { guardian: 'someoneelse', member: 'fo6' })), 'functions/permission-denied');
});

test('invitations can be refused, cancelled and resent within a limit', async () => {
  const m = await owner('fo7');
  const parent = await user('fg7', {}, phone(7));
  const first = await m('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(7) });
  await parent('rejectFamilyInvite', { code: first.code });
  assert.equal((await db.doc(`family/fo7/invitations/${first.id}`).get()).data()?.status, 'rejected');

  const second = await m('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(7) });
  await m('cancelFamilyInvite', { id: second.id });
  assert.equal(await code(parent('joinFamily', { code: second.code })), 'functions/not-found');

  const third = await m('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(7) });
  let latest = third.code;
  for (let i = 0; i < 3; i++) latest = (await m('resendFamilyInvite', { id: third.id })).code;
  assert.equal(await code(m('resendFamilyInvite', { id: third.id })), 'functions/resource-exhausted');
  assert.equal(await code(parent('joinFamily', { code: third.code })), 'functions/not-found');
  await parent('joinFamily', { code: latest });
});

test('guessing family codes hits a limit', async () => {
  const guesser = await user('fg8', {}, phone(8));
  for (let i = 0; i < 5; i++) await code(guesser('joinFamily', { code: 'AAAAAA' }));
  assert.equal(await code(guesser('joinFamily', { code: 'AAAAAA' })), 'functions/resource-exhausted');
});

test('leaving one circle keeps the other', async () => {
  const a = await owner('fo9');
  const b = await owner('fo10');
  const parent = await user('fg9', {}, phone(9));
  await parent('joinFamily', { code: (await a('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(9) })).code });
  await parent('joinFamily', { code: (await b('createFamilyInvite', { name: 'Abu', relationship: 'father', phone: phone(9) })).code });
  await parent('removeGuardian', { guardian: 'fg9', member: 'fo10' });
  assert.equal((await db.doc('accounts/fg9').get()).data()?.familyOf, 'fo9');
});

async function familyManaged(uid: string, subjectPhone: string) {
  await db.doc('config/app').set({ limits: { minPhotos: 0, requireIdProof: false } });
  await db.doc(`drafts/${uid}`).set(validDraft({ photos: [], managedBy: 'family', candidateConsent: true, subjectPhone }));
  const u = await user(uid, {}, phone(Math.floor(Math.random() * 90000) + 1000));
  return { u, ...(await u('submitProfile')) };
}

test('a family-made profile cannot go live until the person confirms from their own phone', async () => {
  const { subjectCode, version } = await familyManaged('fm1', phone(11));
  const r = await user('frev', { reviewer: true });
  assert.equal(await code(r('reviewProfile', { uid: 'fm1', decision: 'approve', version })), 'functions/failed-precondition');
  const other = await user('fs1x', {}, phone(12));
  assert.equal(await code(other('confirmSubject', { code: subjectCode, agree: true })), 'functions/not-found');
  const subject = await user('fs1', {}, phone(11));
  await subject('confirmSubject', { code: subjectCode, agree: true });
  await r('reviewProfile', { uid: 'fm1', decision: 'approve', version });
  assert.equal((await db.doc('profiles/fm1').get()).data()?.live, true);
  assert.ok((await db.doc('accounts/fm1/consents/subject_confirmed').get()).exists);

  await subject('withdrawSubject');
  assert.equal((await db.doc('profiles/fm1').get()).data()?.live, false);
  assert.equal((await db.doc('accounts/fm1').get()).data()?.stage, 'changes_requested');
  await db.doc('config/app').delete();
});

test('the person can refuse a profile made for them', async () => {
  const { subjectCode } = await familyManaged('fm2', phone(13));
  const subject = await user('fs2', {}, phone(13));
  await subject('confirmSubject', { code: subjectCode, agree: false });
  assert.equal((await db.doc('accounts/fm2').get()).data()?.stage, 'changes_requested');
  assert.equal((await db.doc('submissions/fm2').get()).exists, false);
  await db.doc('config/app').delete();
});
