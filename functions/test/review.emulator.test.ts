// Review integrity: what a reviewer saw is what gets published, and nobody reviews themselves.
import { before, test } from 'node:test';
import assert from 'node:assert/strict';
import { admin, code, user, validDraft } from './helpers';

let db: FirebaseFirestore.Firestore;

async function submitted(uid: string, draft: object = {}) {
  await db.doc(`drafts/${uid}`).set(validDraft({ photos: [], ...draft }));
  await db.doc(`accounts/${uid}/documents/name-proof`).set({ status: 'pending' });
  const u = await user(uid, {}, `+9199${String(Math.abs(hash(uid))).padEnd(8, '0').slice(0, 8)}`);
  await db.doc('config/app').set({ limits: { minPhotos: 0 } });
  const res = await u('submitProfile');
  return { u, version: res.version as number };
}

const hash = (s: string) => [...s].reduce((a, c) => (a * 31 + c.charCodeAt(0)) | 0, 7);

before(() => { db = admin().db; });

test('SEC-03: a reviewer cannot approve their own profile', async () => {
  const { version } = await submitted('selfrev');
  const r = await user('selfrev', { reviewer: true });
  assert.equal(await code(r('reviewProfile', { uid: 'selfrev', decision: 'approve', version })), 'functions/permission-denied');
  assert.equal((await db.doc('profiles/selfrev').get()).exists, false);
});

test('SEC-03: a reviewer cannot approve their own document', async () => {
  const r = await user('selfdoc', { reviewer: true });
  await db.doc('accounts/selfdoc/documents/name-proof').set({ status: 'pending', paths: [] });
  assert.equal(await code(r('reviewDocument', { uid: 'selfdoc', type: 'name-proof', decision: 'approve' })), 'functions/permission-denied');
});

test('SEC-03: nothing can be approved unless it is waiting', async () => {
  const r = await user('rev1', { reviewer: true });
  await db.doc('drafts/never').set(validDraft({ photos: [] }));
  await db.doc('accounts/never').set({ stage: 'draft' });
  assert.equal(await code(r('reviewProfile', { uid: 'never', decision: 'approve', version: 1 })), 'functions/failed-precondition');
  assert.equal((await db.doc('profiles/never').get()).exists, false);
});

test('SEC-03: an unknown document type is refused', async () => {
  const r = await user('rev1', { reviewer: true });
  assert.equal(await code(r('reviewDocument', { uid: 'someone', type: 'anything', decision: 'approve' })), 'functions/invalid-argument');
  assert.equal((await db.doc('accounts/someone/documents/anything').get()).exists, false);
});

test('SEC-04: edits made after submission never reach the published card', async () => {
  const { version } = await submitted('toctou', { fullName: 'Reviewed Name' });
  await db.doc('drafts/toctou').set({ fullName: 'Swapped Name' }, { merge: true });
  const r = await user('rev1', { reviewer: true });
  await r('reviewProfile', { uid: 'toctou', decision: 'approve', version });
  assert.equal((await db.doc('profiles/toctou').get()).data()?.name, 'Reviewed Name');
});

test('SEC-04: an under-18 date of birth set after submission is not published', async () => {
  const { version } = await submitted('minor');
  await db.doc('drafts/minor').set({ dateOfBirth: Date.now() - 15 * 365 * 86400000 }, { merge: true });
  const r = await user('rev1', { reviewer: true });
  await r('reviewProfile', { uid: 'minor', decision: 'approve', version });
  const age = (Date.now() - (await db.doc('profiles/minor').get()).data()?.dateOfBirth) / (365.25 * 86400000);
  assert.ok(age >= 18);
});

test('SEC-04: a decision on an older version is refused', async () => {
  const { u, version } = await submitted('stale');
  await db.doc('accounts/stale').set({ stage: 'draft' }, { merge: true });
  const second = (await u('submitProfile')).version;
  assert.equal(second, version + 1);
  const r = await user('rev1', { reviewer: true });
  assert.equal(await code(r('reviewProfile', { uid: 'stale', decision: 'approve', version })), 'functions/failed-precondition');
});

test('SEC-06: submitting needs a verified phone, and only that number is stored', async () => {
  await db.doc('drafts/nophone').set(validDraft({ photos: [], phone: '+910000000000' }));
  await db.doc('accounts/nophone/documents/name-proof').set({ status: 'pending' });
  await db.doc('config/app').set({ limits: { minPhotos: 0 } });
  const u = await user('nophone', {});
  assert.equal(await code(u('submitProfile')), 'functions/failed-precondition');

  await db.doc('drafts/hasphone').set(validDraft({ photos: [], phone: '+910000000000' }));
  await db.doc('accounts/hasphone/documents/name-proof').set({ status: 'pending' });
  const v = await user('hasphone', {}, '+919876500001');
  const { version } = await v('submitProfile');
  const r = await user('rev1', { reviewer: true });
  await r('reviewProfile', { uid: 'hasphone', decision: 'approve', version });
  assert.equal((await db.doc('accounts/hasphone').get()).data()?.phone, '+919876500001');
});

test('a reviewer can ask for changes, naming the photos, and the member can resubmit', async () => {
  const { u, version } = await submitted('changes');
  const r = await user('rev1', { reviewer: true });
  await r('reviewProfile', { uid: 'changes', decision: 'changes', reason: 'Add a clearer photo', version, rejectedPhotos: ['photos/changes/1.jpg'] });
  const acc = (await db.doc('accounts/changes').get()).data();
  assert.equal(acc?.stage, 'changes_requested');
  assert.equal(acc?.rejectionReason, 'Add a clearer photo');
  assert.deepEqual(acc?.rejectedPhotos, ['photos/changes/1.jpg']);
  assert.equal((await u('submitProfile')).stage, 'submitted');
  assert.equal((await db.doc('submissions/changes').get()).exists, true);
});

test('an approved member cannot resubmit over their live profile', async () => {
  const { u, version } = await submitted('live');
  const r = await user('rev1', { reviewer: true });
  await r('reviewProfile', { uid: 'live', decision: 'approve', version });
  assert.equal(await code(u('submitProfile')), 'functions/failed-precondition');
  assert.equal((await db.doc('accounts/live').get()).data()?.stage, 'approved');
});

test('submitting records consent with the policy version', async () => {
  await submitted('consent');
  const c = (await db.doc('accounts/consent/consents/data_processing').get()).data();
  assert.equal(typeof c?.policyVersion, 'string');
  assert.ok(c?.acceptedAt);
  assert.ok(c?.purpose);
});

test('document decisions follow the six states and viewing marks it under review', async () => {
  const u = await user('docs', {});
  const { bucket } = admin();
  const path = 'verification/docs/name-proof/1.jpg';
  await bucket.file(path).save(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]), { contentType: 'image/jpeg' });
  assert.equal((await u('submitDocument', { type: 'name-proof', paths: [path] })).status, 'pending');
  const r = await user('rev1', { reviewer: true });
  await r('getDocumentUrl', { uid: 'docs', type: 'name-proof' });
  assert.equal((await db.doc('accounts/docs/documents/name-proof').get()).data()?.status, 'under_review');
  await r('reviewDocument', { uid: 'docs', type: 'name-proof', decision: 'resubmit', reason: 'Too dark' });
  assert.equal((await db.doc('accounts/docs/documents/name-proof').get()).data()?.status, 'resubmission_required');
  assert.equal(await code(r('reviewDocument', { uid: 'docs', type: 'name-proof', decision: 'approve' })), 'functions/failed-precondition');
});

test('SEC-15: a file whose bytes do not match its type is refused and removed', async () => {
  const u = await user('badfile', {});
  const { bucket } = admin();
  const path = 'verification/badfile/name-proof/1.jpg';
  await bucket.file(path).save(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"></svg>'), { contentType: 'image/jpeg' });
  assert.equal(await code(u('submitDocument', { type: 'name-proof', paths: [path] })), 'functions/invalid-argument');
  assert.equal((await bucket.file(path).exists())[0], false);
});
