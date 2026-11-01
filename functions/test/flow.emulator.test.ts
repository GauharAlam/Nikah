// Drives the deployed callables on the Functions emulator as real signed-in users.
import { before, test } from 'node:test';
import assert from 'node:assert/strict';
import { getApps, initializeApp as adminApp } from 'firebase-admin/app';
import { getAuth as adminAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { deleteApp, initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithCustomToken } from 'firebase/auth';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';

const projectId = 'demo-nikah';
let n = 0;

async function user(uid: string, claims: object) {
  await adminAuth().createUser({ uid }).catch(() => undefined);
  await adminAuth().setCustomUserClaims(uid, claims);
  const token = await adminAuth().createCustomToken(uid);
  const app = initializeApp({ apiKey: 'x', projectId, appId: 'x' }, `u${n++}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  await signInWithCustomToken(auth, token);
  const fns = getFunctions(app, 'asia-south1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  return (name: string, data: unknown = {}) => httpsCallable(fns, name)(data).then((r) => r.data as any);
}

const profile = (id: string, gender: string, extra: object = {}) => ({
  id, name: id, gender, live: true, dateOfBirth: Date.UTC(1998, 0, 1), caste: 'Syed', maritalStatus: 'Never married',
  university: 'AMU', education: 'MBA', profession: 'Doctor', location: 'Delhi', approvedAt: Timestamp.now(), ...extra,
});

const code_ = (p: Promise<unknown>) =>
  p.then(() => 'ok', (e) => e.code as string);
const code = (p: Promise<unknown>) => p.then(() => 'ok', (e) => e.code as string);
let db: FirebaseFirestore.Firestore;

before(async () => {
  process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
  if (getApps().length === 0) adminApp({ projectId });
  db = getFirestore();
  await Promise.all([...'mfgh'].map((id, i) => db.doc(`profiles/${id}`).set(profile(id, i === 0 ? 'male' : 'female'))));
  await db.doc('profiles/k').set(profile('k', 'male'));
});

test('a draft member cannot act on anyone', async () => {
  const draft = await user('draft', {});
  assert.equal(await code(draft('sendProposal', { to: 'f' })), 'functions/permission-denied');
  assert.equal(await code(draft('fetchIntroductions')), 'functions/permission-denied');
});

test('a member cannot approve a profile', async () => {
  const m = await user('m', { approved: true });
  assert.equal(await code(m('reviewProfile', { uid: 'm', approve: true })), 'functions/permission-denied');
  assert.equal(await code(m('reviewDocument', { uid: 'm', type: 'name-proof', approve: true })), 'functions/permission-denied');
});

test('discovery only returns the opposite gender and hides private fields', async () => {
  const m = await user('m', { approved: true });
  const { profiles } = await m('fetchIntroductions');
  assert.ok(profiles.length >= 1);
  assert.ok(profiles.every((p: any) => p.id !== 'm' && p.id !== 'k'), 'male members see only women');
  assert.ok(profiles.every((p: any) => p.dateOfBirth === undefined && p.age >= 18));
});

test('propose, accept, match: one side alone never creates a match', async () => {
  const m = await user('m', { approved: true });
  const f = await user('f', { approved: true });
  assert.equal((await m('sendProposal', { to: 'f' })).status, 'pending');
  const pair = ['f', 'm'].sort().join('_');
  assert.equal((await db.doc(`matches/${pair}`).get()).exists, false);

  assert.equal(await code(m('respondProposal', { from: 'f', accept: true })), 'functions/not-found');
  await f('respondProposal', { from: 'm', accept: true });
  assert.equal((await db.doc(`matches/${pair}`).get()).data()?.status, 'active');
  assert.equal(await code(f('respondProposal', { from: 'm', accept: false })), 'functions/failed-precondition');
});

test('crossing proposals match, and a retry does not spend a slot', async () => {
  const m = await user('m', { approved: true });
  const g = await user('g', { approved: true });
  await g('sendProposal', { to: 'm' });
  const before = (await db.doc('accounts/m').get()).data()?.proposalCount;
  assert.equal((await m('sendProposal', { to: 'g' })).status, 'accepted');
  await m('sendProposal', { to: 'g' });
  assert.equal((await db.doc('accounts/m').get()).data()?.proposalCount, before + 1);
});

test('the daily proposal limit holds on the server', async () => {
  const k = await user('k', { approved: true });
  await db.doc('accounts/k').set({ proposalDay: new Date().toISOString().slice(0, 10), proposalCount: 5 });
  assert.equal(await code(k('sendProposal', { to: 'h' })), 'functions/resource-exhausted');
});

test('blocking stops proposals both ways and closes the match', async () => {
  const m = await user('m', { approved: true });
  const f = await user('f', { approved: true });
  await f('blockProfile', { target: 'm' });
  assert.equal(await code(m('sendProposal', { to: 'f' })), 'functions/not-found');
  const pair = ['f', 'm'].sort().join('_');
  assert.equal((await db.doc(`matches/${pair}`).get()).data()?.status, 'blocked');
  const ids = (await m('getProfiles', { ids: ['f'] })).profiles;
  assert.equal(ids.length, 0);
});

test('contact needs the recipient, and a repeat request is not charged twice', async () => {
  const k = await user('k', { approved: true });
  const h = await user('h', { approved: true });
  await db.doc('accounts/h').set({ phone: '+911111111111' });
  await db.doc('accounts/k').set({ phone: '+912222222222' });
  await k('requestContact', { to: 'h' });
  await k('requestContact', { to: 'h' });
  assert.equal((await db.doc('accounts/k').get()).data()?.creditsSpent, 1);
  const pair = ['h', 'k'].sort().join('_');
  assert.equal((await db.doc(`contactShares/${pair}`).get()).exists, false);
  await h('respondContact', { from: 'k', accept: true });
  assert.equal((await db.doc(`contactShares/${pair}`).get()).data()?.phones.h, '+911111111111');
});

test('same-gender proposals and contact requests are refused', async () => {
  const m = await user('m', { approved: true });
  assert.equal(await code(m('sendProposal', { to: 'k' })), 'functions/not-found');
  assert.equal(await code(m('requestContact', { to: 'k' })), 'functions/not-found');
  assert.equal((await db.doc('proposals/m_k').get()).exists, false);
});

test('a declined contact request gives the credit back', async () => {
  const k = await user('k', { approved: true });
  const g = await user('g', { approved: true });
  const month = new Date().toISOString().slice(0, 7);
  await db.doc('accounts/k').set({ creditMonth: month, creditsSpent: 4 }, { merge: true });
  await k('requestContact', { to: 'g' });
  assert.equal((await db.doc('accounts/k').get()).data()?.creditsSpent, 5);
  await g('respondContact', { from: 'k', accept: false });
  assert.equal((await db.doc('accounts/k').get()).data()?.creditsSpent, 4);
});

test('private photos stay hidden from a viewer who is not matched', async () => {
  await db.doc('profiles/p1').set(profile('p1', 'female', { photos: ['https://x/p.jpg'], photoPrivacy: 'matches', showCaste: false }));
  const k = await user('k', { approved: true });
  await db.doc('accounts/k/viewed/p1').set({ at: Timestamp.now() });
  const [card] = (await k('getProfiles', { ids: ['p1'] })).profiles;
  assert.deepEqual(card.photos, []);
  assert.equal(card.photosHidden, true);
  assert.equal(card.caste, '');
});

test('three different reporters hold a profile; one reporter repeating does not', async () => {
  await db.doc('profiles/bad').set(profile('bad', 'female'));
  const r1 = await user('r1', {});
  await r1('reportProfile', { target: 'bad', reason: 'Asked for money' });
  await r1('reportProfile', { target: 'bad', reason: 'Asked for money' });
  await r1('reportProfile', { target: 'bad', reason: 'Fake profile' });
  assert.equal((await db.doc('profiles/bad').get()).data()?.live, true);
  const r2 = await user('r2', {});
  const r3 = await user('r3', {});
  await r2('reportProfile', { target: 'bad', reason: 'Fake profile' });
  await r3('reportProfile', { target: 'bad', reason: 'Fake profile' });
  const held = (await db.doc('profiles/bad').get()).data();
  assert.equal(held?.live, false);
  assert.equal(held?.held, true);
});

test('submission needs an ID document', async () => {
  const u = await user('sub', {});
  await db.doc('drafts/sub').set({
    fullName: 'S', gender: 'female', maritalStatus: 'Never married', marriageReadiness: 'Just exploring',
    homeCity: 'Delhi', height: `5'4"`, phone: '+911', almaMaters: ['AMU'], qualification: 'MBA',
    qualificationGraduate: true, profession: 'Doctor', dateOfBirth: Date.UTC(1998, 0, 1), photos: ['p'],
    intentConfirmed: true, dataConsent: true,
  });
  assert.equal(await code(u('submitProfile')), 'functions/failed-precondition');
  await db.doc('accounts/sub/documents/name-proof').set({ status: 'pending' });
  assert.equal((await u('submitProfile')).stage, 'submitted');
});

test('free members stop at the limit, repeats are free, and premium is unlimited', async () => {
  await db.doc('config/app').set({ limits: { freeProfileLimit: 2 } });
  for (const id of ['v1', 'v2', 'v3', 'v4']) await db.doc(`profiles/${id}`).set(profile(id, 'female'));
  await db.doc('profiles/viewer').set(profile('viewer', 'male'));
  const free = await user('viewer', { approved: true });

  const first = await free('fetchIntroductions');
  assert.equal(first.profiles.length, 2);
  assert.equal(first.freeLeft, 0);
  assert.equal(first.limitReached, true);
  const shown = first.profiles.map((p: any) => p.id).sort();

  const again = await free('fetchIntroductions');
  assert.deepEqual(again.profiles.map((p: any) => p.id).sort(), shown, 'a repeat shows nothing new');
  assert.equal((await db.doc('accounts/viewer').get()).data()?.viewCount, 2);

  const hiddenId = ['v1', 'v2', 'v3', 'v4'].find((id) => !shown.includes(id));
  assert.equal((await free('getProfiles', { ids: [hiddenId] })).profiles.length, 0);
  assert.equal((await free('getProfiles', { ids: [shown[0]] })).profiles.length, 1);

  await db.doc('accounts/viewer').set({ premiumUntil: Timestamp.fromMillis(Date.now() + 86400000) }, { merge: true });
  const paid = await free('fetchIntroductions');
  assert.ok(paid.profiles.length > 2);
  assert.equal(paid.limitReached, false);
  assert.equal((await free('getProfiles', { ids: [hiddenId] })).profiles.length, 1);
  await db.doc('config/app').delete();
});

test('a guardian joins once with a code, gives opinions, and can be removed', async () => {
  await db.doc('profiles/mem').set(profile('mem', 'male'));
  await db.doc('profiles/cand').set(profile('cand', 'female'));
  await db.doc('profiles/nosh').set(profile('nosh', 'female', { allowFamilyShare: false }));
  const m = await user('mem', { approved: true });
  const parent = await user('parent', {});
  const stranger = await user('stranger', {});
  await db.doc('accounts/mem/viewed/cand').set({ at: Timestamp.now() });
  await db.doc('accounts/mem/viewed/nosh').set({ at: Timestamp.now() });

  const { code } = await m('createFamilyInvite');
  assert.equal(await code_(m('joinFamily', { code, name: 'Me' })), 'functions/invalid-argument');
  await parent('joinFamily', { code, name: 'Abu' });
  assert.equal(await code_(stranger('joinFamily', { code, name: 'X' })), 'functions/not-found');

  await m('shareWithFamily', { profile: 'cand' });
  assert.equal(await code_(m('shareWithFamily', { profile: 'nosh' })), 'functions/permission-denied');
  assert.equal(await code_(m('shareWithFamily', { profile: 'h' })), 'functions/not-found');
  const summary = (await db.doc('family/mem/shortlist/cand').get()).data();
  assert.equal(summary?.photos, undefined);
  assert.equal(summary?.phone, undefined);

  await parent('giveFamilyOpinion', { member: 'mem', profile: 'cand', opinion: 'good' });
  assert.equal(await code_(stranger('giveFamilyOpinion', { member: 'mem', profile: 'cand', opinion: 'no' })), 'functions/permission-denied');
  assert.equal(await code_(parent('sendProposal', { to: 'cand' })), 'functions/permission-denied');

  await m('removeGuardian', { guardian: 'parent' });
  assert.equal(await code_(parent('giveFamilyOpinion', { member: 'mem', profile: 'cand', opinion: 'no' })), 'functions/permission-denied');
});

test('an invite earns credits once, only after approval, and not for yourself', async () => {
  const a = await user('inviter', { approved: true });
  const { code } = await a('getInviteCode');
  assert.equal((await a('getInviteCode')).code, code);
  await db.doc('drafts/inv1').set({ fullName: 'I', gender: 'male', dateOfBirth: Date.UTC(1998, 0, 1), photos: [], inviteCode: code });
  await db.doc('accounts/inv1').set({ stage: 'submitted' });
  await adminAuth().createUser({ uid: 'inv1' }).catch(() => undefined);
  assert.equal((await db.doc('accounts/inviter').get()).data()?.purchasedCredits, undefined);
  const rev = await user('rev', { reviewer: true });
  await rev('reviewProfile', { uid: 'inv1', approve: true });
  assert.equal((await db.doc('accounts/inviter').get()).data()?.purchasedCredits, 2);
  await rev('reviewProfile', { uid: 'inv1', approve: true });
  assert.equal((await db.doc('accounts/inviter').get()).data()?.purchasedCredits, 2);
});

test('approved edits wait for review, then publish', async () => {
  const e = await user('editor', { approved: true });
  await db.doc('accounts/editor').set({ stage: 'approved' });
  await db.doc('profiles/editor').set(profile('editor', 'male', { name: 'Old' }));
  await db.doc('drafts/editor').set({ fullName: 'New', gender: 'male', dateOfBirth: Date.UTC(1998, 0, 1), photos: [] });
  await e('submitEdits');
  assert.equal((await db.doc('profiles/editor').get()).data()?.name, 'Old');
  const rev = await user('rev', { reviewer: true });
  await rev('reviewProfile', { uid: 'editor', approve: true });
  assert.equal((await db.doc('profiles/editor').get()).data()?.name, 'New');
  assert.equal((await db.doc('accounts/editor').get()).data()?.editsPending, false);
});

test.after(async () => { /* client apps close with the process */ void deleteApp; });
