// Journey 7, photo delivery, and the member's own controls over their data.
import { before, test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { admin, code, profile, user } from './helpers';

let db: FirebaseFirestore.Firestore;
let bucket: ReturnType<typeof admin>['bucket'];
let auth: ReturnType<typeof admin>['auth'];
const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);

before(() => { ({ db, bucket, auth } = admin()); });

async function seedEverything(uid: string, other: string) {
  const u = await user(uid, { approved: true }, '+919000000001');
  await db.doc(`profiles/${uid}`).set(profile(uid, 'male'));
  await db.doc(`drafts/${uid}`).set({ fullName: 'Del' });
  await db.doc(`submissions/${uid}`).set({ version: 1 });
  await db.doc(`accounts/${uid}`).set({ stage: 'approved', phone: '+919000000001' });
  await db.doc(`accounts/${uid}/consents/data_processing`).set({ category: 'data_processing' });
  await db.doc(`accounts/${uid}/notifications/n`).set({ title: 't' });
  await db.doc(`accounts/${uid}/devices/token`).set({ platform: 'android' });
  await db.doc(`proposals/${uid}_${other}`).set({ from: uid, to: other, status: 'pending' });
  await db.doc(`proposals/${other}_${uid}x`).set({ from: other, to: uid, status: 'accepted' });
  await db.doc(`contactRequests/${uid}_${other}`).set({ from: uid, to: other, status: 'pending' });
  await db.doc(`contactShares/${other}_${uid}`).set({ users: [uid, other], phones: {} });
  await db.doc(`matches/${other}_${uid}`).set({ users: [uid, other], status: 'active' });
  await db.doc(`matches/${other}_${uid}/messages/m`).set({ sender: uid, text: 'x' });
  await db.doc(`accounts/${other}/blocks/${uid}`).set({ target: uid });
  await db.doc(`accounts/${other}/hidden/${uid}`).set({ target: uid });
  await db.doc(`accounts/${other}/viewed/${uid}`).set({ target: uid });
  await db.doc(`accounts/${other}/bookmarks/${uid}`).set({ profileId: uid });
  await db.doc(`accounts/${uid}/bookmarks/${other}`).set({ profileId: other });
  await db.doc(`family/${other}/shortlist/${uid}`).set({ profileId: uid, firstName: 'Del' });
  await db.doc(`family/${uid}`).set({ guardians: ['gx'], names: { gx: 'G' } });
  await db.doc(`family/${uid}/memberships/gx`).set({ permissions: ['view_shortlist'] });
  await db.doc(`familyLinks/gx/circles/${uid}`).set({ member: uid });
  await db.doc('accounts/gx').set({ familyOf: uid });
  await db.doc(`inviteCodes/DEL${uid.slice(-3).toUpperCase()}`).set({ uid });
  await db.doc(`inviteClaims/${uid}`).set({ inviter: other });
  await db.doc(`reports/${uid}_${other}`).set({ reporter: uid, target: other, status: 'open' });
  await db.doc(`purchases/p${uid}`).set({ uid, productId: 'x' });
  for (const p of [`photos/${uid}/1.jpg`, `published/${uid}/1.jpg`, `verification/${uid}/name-proof/1.jpg`]) {
    await bucket.file(p).save(jpeg, { contentType: 'image/jpeg' });
  }
  return u;
}

async function assertGone(uid: string, other: string) {
  for (const path of [
    `profiles/${uid}`, `drafts/${uid}`, `submissions/${uid}`, `accounts/${uid}`, `accounts/${uid}/consents/data_processing`,
    `accounts/${uid}/notifications/n`, `accounts/${uid}/devices/token`, `proposals/${uid}_${other}`,
    `proposals/${other}_${uid}x`, `contactRequests/${uid}_${other}`, `contactShares/${other}_${uid}`,
    `matches/${other}_${uid}`, `matches/${other}_${uid}/messages/m`, `accounts/${other}/blocks/${uid}`,
    `accounts/${other}/hidden/${uid}`, `accounts/${other}/viewed/${uid}`, `accounts/${other}/bookmarks/${uid}`,
    `accounts/${uid}/bookmarks/${other}`, `family/${other}/shortlist/${uid}`,
    `family/${uid}`, `family/${uid}/memberships/gx`, `familyLinks/gx/circles/${uid}`, `inviteClaims/${uid}`,
  ]) assert.equal((await db.doc(path).get()).exists, false, `${path} should be gone`);
  assert.equal((await db.doc('accounts/gx').get()).data()?.familyOf, undefined);
  assert.equal((await db.collection('inviteCodes').where('uid', '==', uid).get()).size, 0);
  for (const prefix of ['photos', 'published', 'verification']) {
    assert.equal((await bucket.getFiles({ prefix: `${prefix}/${uid}/` }))[0].length, 0, `${prefix} files`);
  }
  await assert.rejects(auth.getUser(uid));
}

test('Journey 7: deleting removes personal data everywhere, keeping only what law needs', async () => {
  const u = await seedEverything('del1', 'delo1');
  assert.equal((await u('requestAccountDeletion')).status, 'done');
  await assertGone('del1', 'delo1');

  const report = (await db.doc('reports/del1_delo1').get()).data();
  assert.equal(report?.reporter, undefined, 'the report stays for safety, without the reporter');
  assert.equal(report?.target, 'delo1');
  const purchase = (await db.doc('purchases/pdel1').get()).data();
  assert.ok(purchase, 'the payment record stays');
  assert.notEqual(purchase?.uid, 'del1');
  const record = (await db.doc('deletionRequests/del1').get()).data();
  assert.equal(record?.status, 'done');
  assert.ok(!JSON.stringify(record).includes('+91'));
});

test('a stuck deletion resumes where it stopped and finishes', async () => {
  await seedEverything('del2', 'delo2');
  await db.doc('deletionRequests/del2').set({ status: 'pending', done: ['hide', 'relations'], createdAt: Timestamp.now() });
  await db.doc('proposals/del2_delo2').delete();
  const r = await user('delrev', { reviewer: true });
  await r('resumeDeletion', { uid: 'del2' });
  assert.equal((await db.doc('profiles/del2').get()).exists, false);
  assert.equal((await db.doc('deletionRequests/del2').get()).data()?.status, 'done');
  await r('resumeDeletion', { uid: 'del2' });
});

test('resuming a deletion needs a reviewer', async () => {
  const m = await user('delm', { approved: true });
  assert.equal(await code(m('resumeDeletion', { uid: 'del2' })), 'functions/permission-denied');
});

test('SEC-01: photo links reach only permitted viewers, and privacy changes take effect', async () => {
  await bucket.file('published/ph1/1.jpg').save(jpeg, { contentType: 'image/jpeg' });
  await db.doc('profiles/ph1').set(profile('ph1', 'female', { photoPaths: ['published/ph1/1.jpg'], photoPrivacy: 'everyone' }));
  await db.doc('profiles/ph2').set(profile('ph2', 'male'));
  await db.doc('accounts/ph2/viewed/ph1').set({ target: 'ph1', at: Timestamp.now() });
  const viewer = await user('ph2', { approved: true });

  const [open] = (await viewer('getProfiles', { ids: ['ph1'] })).profiles;
  assert.equal(open.photos.length, 1);
  assert.ok(!JSON.stringify(open).includes('photoPaths'));

  const owner = await user('ph1', { approved: true });
  await owner('updatePrivacy', { photoPrivacy: 'matches' });
  const [closed] = (await viewer('getProfiles', { ids: ['ph1'] })).profiles;
  assert.deepEqual(closed.photos, []);
  assert.equal(closed.photosHidden, true);
});

test('pausing takes a profile out of discovery and back', async () => {
  await db.doc('profiles/pa1').set(profile('pa1', 'female'));
  await db.doc('profiles/pa2').set(profile('pa2', 'male'));
  const m = await user('pa1', { approved: true });
  const viewer = await user('pa2', { approved: true });
  await m('setAccountPaused', { paused: true });
  assert.ok(!(await viewer('fetchIntroductions')).profiles.some((p: any) => p.id === 'pa1'));
  await m('setAccountPaused', { paused: false });
  assert.equal((await db.doc('profiles/pa1').get()).data()?.live, true);
});

test('export holds the member\'s own data and nothing private of anyone else', async () => {
  const uid = 'ex1';
  await db.doc(`accounts/${uid}`).set({ stage: 'approved', reviewedBy: 'staff' });
  await db.doc(`drafts/${uid}`).set({ fullName: 'Ex' });
  await db.doc(`matches/ex0_${uid}`).set({ users: [uid, 'ex0'], status: 'active' });
  await db.doc(`matches/ex0_${uid}/messages/a`).set({ sender: uid, text: 'mine', sentAt: Timestamp.now() });
  await db.doc(`matches/ex0_${uid}/messages/b`).set({ sender: 'ex0', text: 'theirs', sentAt: Timestamp.now() });
  const u = await user(uid, { approved: true });
  const data = await u('exportMyData');
  assert.equal(data.draft.fullName, 'Ex');
  const text = JSON.stringify(data);
  assert.ok(text.includes('mine'));
  assert.ok(!text.includes('theirs'));
  assert.ok(!text.includes('staff'));
});

test('blocks can be listed and lifted without reopening anything', async () => {
  const a = await user('bl1', { approved: true });
  await db.doc('profiles/bl2').set(profile('bl2', 'female', { name: 'Sara Khan' }));
  await db.doc('matches/bl1_bl2').set({ users: ['bl1', 'bl2'], status: 'active' });
  await a('blockProfile', { target: 'bl2' });
  assert.deepEqual((await a('listBlocks')).blocks, [{ id: 'bl2', name: 'Sara' }]);
  await a('unblockProfile', { target: 'bl2' });
  assert.equal((await a('listBlocks')).blocks.length, 0);
  assert.equal((await db.doc('matches/bl1_bl2').get()).data()?.status, 'blocked');
});

test('a member can turn off contact requests', async () => {
  await db.doc('profiles/nc1').set(profile('nc1', 'male'));
  await db.doc('profiles/nc2').set(profile('nc2', 'female', { allowContactRequests: false }));
  const a = await user('nc1', { approved: true });
  assert.equal(await code(a('requestContact', { to: 'nc2' })), 'functions/failed-precondition');
});
