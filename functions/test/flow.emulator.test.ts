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
  assert.ok(profiles.every((p: any) => p.id !== 'm' && p.id !== 'k'));
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

test.after(async () => { /* client apps close with the process */ void deleteApp; });
