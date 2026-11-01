import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, updateDoc, addDoc, collection } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let env: RulesTestEnvironment;
const member = (uid: string, approved = true) => env.authenticatedContext(uid, { approved }).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nikah',
    firestore: { rules: readFileSync('../firebase/firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: readFileSync('../firebase/storage.rules', 'utf8'), host: '127.0.0.1', port: 9199 },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'accounts/a'), { stage: 'approved', creditsSpent: 0 });
    await setDoc(doc(db, 'profiles/b'), { name: 'B', gender: 'female', live: true });
    await setDoc(doc(db, 'proposals/a_b'), { from: 'a', to: 'b', status: 'pending' });
    await setDoc(doc(db, 'contactShares/a_b'), { users: ['a', 'b'], phones: { a: '1', b: '2' } });
    await setDoc(doc(db, 'matches/a_b'), { users: ['a', 'b'], status: 'active', readAt: {}, unread: { a: 0, b: 0 } });
    await setDoc(doc(db, 'matches/a_c'), { users: ['a', 'c'], status: 'blocked', readAt: {}, unread: {} });
    await setDoc(doc(db, 'accounts/a/notifications/n1'), { title: 't', read: false });
    await setDoc(doc(db, 'reports/r1'), { reporter: 'a' });
  });
});

test('nobody can read data while signed out', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'accounts/a')));
  await assertFails(getDoc(doc(anon, 'proposals/a_b')));
  await assertFails(getDoc(doc(anon, 'config/app')));
});

test('a member cannot grant themselves anything', async () => {
  const db = member('a');
  await assertFails(setDoc(doc(db, 'accounts/a'), { stage: 'approved' }));
  await assertFails(updateDoc(doc(db, 'accounts/a'), { premiumUntil: 9e15 }));
  await assertFails(setDoc(doc(db, 'profiles/a'), { verified: true, live: true }));
  await assertFails(setDoc(doc(db, 'drafts/a'), { fullName: 'x', stage: 'approved' }));
  await assertFails(setDoc(doc(db, 'accounts/a/documents/name-proof'), { status: 'approved' }));
});

test('a member edits only their own draft', async () => {
  await assertSucceeds(setDoc(doc(member('a'), 'drafts/a'), { fullName: 'A' }));
  await assertFails(setDoc(doc(member('z'), 'drafts/a'), { fullName: 'Z' }));
  await assertFails(getDoc(doc(member('z'), 'drafts/a')));
});

test('accounts are private to their owner', async () => {
  await assertSucceeds(getDoc(doc(member('a'), 'accounts/a')));
  await assertFails(getDoc(doc(member('b'), 'accounts/a')));
});

test('published profiles cannot be read directly', async () => {
  await assertFails(getDoc(doc(member('a'), 'profiles/b')));
});

test('proposals are visible to the two people only and never client-written', async () => {
  await assertSucceeds(getDoc(doc(member('a'), 'proposals/a_b')));
  await assertSucceeds(getDoc(doc(member('b'), 'proposals/a_b')));
  await assertFails(getDoc(doc(member('z'), 'proposals/a_b')));
  await assertFails(updateDoc(doc(member('b'), 'proposals/a_b'), { status: 'accepted' }));
  await assertFails(setDoc(doc(member('a'), 'proposals/a_z'), { from: 'a', to: 'z', status: 'accepted' }));
});

test('matches cannot be created by a client', async () => {
  await assertFails(setDoc(doc(member('a'), 'matches/a_z'), { users: ['a', 'z'], status: 'active' }));
});

test('shared contacts are readable by the pair only', async () => {
  await assertSucceeds(getDoc(doc(member('a'), 'contactShares/a_b')));
  await assertFails(getDoc(doc(member('z'), 'contactShares/a_b')));
});

const message = (sender: string, text = 'Salam') => ({ sender, text, sentAt: serverTimestamp() });

test('only participants of an open match can message', async () => {
  await assertSucceeds(addDoc(collection(member('a'), 'matches/a_b/messages'), message('a')));
  await assertFails(addDoc(collection(member('z'), 'matches/a_b/messages'), message('z')));
  await assertFails(addDoc(collection(member('a'), 'matches/a_b/messages'), message('b')));
  await assertFails(addDoc(collection(member('a'), 'matches/a_c/messages'), message('a')));
  await assertFails(addDoc(collection(member('a'), 'matches/a_b/messages'), message('a', 'x'.repeat(2001))));
  await assertFails(getDoc(doc(member('z'), 'matches/a_b/messages/m')));
});

test('a member moves only their own read marker', async () => {
  await assertSucceeds(updateDoc(doc(member('a'), 'matches/a_b'), { 'readAt.a': serverTimestamp() }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { 'readAt.b': serverTimestamp() }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { status: 'active', 'unread.a': 5 }));
});

test('notifications: mark read only', async () => {
  await assertSucceeds(updateDoc(doc(member('a'), 'accounts/a/notifications/n1'), { read: true }));
  await assertFails(updateDoc(doc(member('a'), 'accounts/a/notifications/n1'), { title: 'x' }));
  await assertFails(updateDoc(doc(member('b'), 'accounts/a/notifications/n1'), { read: true }));
});

test('reports and unknown collections are closed', async () => {
  await assertFails(getDoc(doc(member('a'), 'reports/r1')));
  await assertFails(setDoc(doc(member('a'), 'anything/x'), { a: 1 }));
});

const image = new Uint8Array([1, 2, 3]);
const store = (uid: string, approved = true) => env.authenticatedContext(uid, { approved }).storage();

test('photos: owner writes images, approved members read', async () => {
  await assertSucceeds(uploadBytes(ref(store('a'), 'photos/a/1.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(store('z'), 'photos/a/2.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(store('a'), 'photos/a/3.exe'), image, { contentType: 'application/octet-stream' }));
  await assertSucceeds(getBytes(ref(store('b'), 'photos/a/1.jpg')));
  await assertFails(getBytes(ref(store('b', false), 'photos/a/1.jpg')));
});

test('verification documents cannot be read back by anyone', async () => {
  await assertSucceeds(uploadBytes(ref(store('a'), 'verification/a/name-proof/1.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(getBytes(ref(store('a'), 'verification/a/name-proof/1.jpg')));
  await assertFails(getBytes(ref(store('b'), 'verification/a/name-proof/1.jpg')));
  await assertFails(uploadBytes(ref(store('b'), 'verification/a/name-proof/2.jpg'), image, { contentType: 'image/jpeg' }));
});
