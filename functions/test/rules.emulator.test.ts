import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, deleteDoc, getDoc, serverTimestamp, setDoc, updateDoc, addDoc, collection } from 'firebase/firestore';
import { deleteObject, getBytes, listAll, ref, uploadBytes } from 'firebase/storage';

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
    await setDoc(doc(db, 'matches/a_b'), { users: ['a', 'b'], status: 'active', readAt: {}, unread: { a: 2, b: 3 } });
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

test('SEC-13: blocked and closed conversations cannot be read or written', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'matches/a_c/messages/m1'), { sender: 'c', text: 'x', sentAt: serverTimestamp() });
    await setDoc(doc(c.firestore(), 'matches/a_b/messages/m1'), { sender: 'b', text: 'x', sentAt: serverTimestamp() });
  });
  await assertFails(getDoc(doc(member('a'), 'matches/a_c/messages/m1')));
  await assertSucceeds(getDoc(doc(member('a'), 'matches/a_b/messages/m1')));
  await assertFails(addDoc(collection(member('a'), 'matches/a_c/messages'), { sender: 'a', text: 'hi', sentAt: serverTimestamp() }));
});

test('SEC-13: a member who lost approval cannot message', async () => {
  const held = member('a', false);
  await assertFails(addDoc(collection(held, 'matches/a_b/messages'), { sender: 'a', text: 'hi', sentAt: serverTimestamp() }));
  await assertFails(getDoc(doc(held, 'matches/a_b/messages/m1')));
});

test('a member clears only their own unread count, and only to zero', async () => {
  await assertSucceeds(updateDoc(doc(member('a'), 'matches/a_b'), { 'unread.a': 0, 'readAt.a': serverTimestamp() }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { 'unread.b': 0 }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { 'unread.a': 5 }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { status: 'closed' }));
});

test('a member moves only their own read marker', async () => {
  await assertSucceeds(updateDoc(doc(member('a'), 'matches/a_b'), { 'readAt.a': serverTimestamp() }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { 'readAt.b': serverTimestamp() }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { status: 'active', 'unread.a': 5 }));
});

test('a member moves only their own journey step, to a known step', async () => {
  await assertSucceeds(updateDoc(doc(member('a'), 'matches/a_b'), { 'journey.a': 'questions' }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { 'journey.b': 'questions' }));
  await assertFails(updateDoc(doc(member('a'), 'matches/a_b'), { 'journey.a': 'married' }));
  await assertFails(updateDoc(doc(member('z'), 'matches/a_b'), { 'journey.z': 'questions' }));
});

test('answers stay hidden until you give yours', async () => {
  const a = member('a');
  const b = member('b');
  await assertSucceeds(setDoc(doc(a, 'matches/a_b/answers/a'), { answers: { q1: 'Yes' } }));
  await assertFails(getDoc(doc(b, 'matches/a_b/answers/a')));
  await assertSucceeds(setDoc(doc(b, 'matches/a_b/answers/b'), { answers: { q1: 'No' } }));
  await assertSucceeds(getDoc(doc(b, 'matches/a_b/answers/a')));
  await assertFails(setDoc(doc(a, 'matches/a_b/answers/b'), { answers: {} }));
  await assertFails(getDoc(doc(member('z'), 'matches/a_b/answers/a')));
  await assertFails(setDoc(doc(a, 'matches/a_c/answers/a'), { answers: {} }));
});

test('family summaries reach only the member and their guardians', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'family/a'), { guardians: ['parent', 'limited'], names: { parent: 'Abu' } });
    await setDoc(doc(c.firestore(), 'family/a/shortlist/b'), { firstName: 'B' });
    await setDoc(doc(c.firestore(), 'family/a/memberships/parent'), { permissions: ['view_shortlist'] });
    await setDoc(doc(c.firestore(), 'family/a/memberships/limited'), { permissions: ['view_profile'] });
    await setDoc(doc(c.firestore(), 'family/a/invitations/i'), { status: 'pending' });
    await setDoc(doc(c.firestore(), 'family/a/history/h'), { action: 'joined' });
    await setDoc(doc(c.firestore(), 'familyLinks/parent/circles/a'), { member: 'a' });
  });
  await assertSucceeds(getDoc(doc(member('a'), 'family/a/shortlist/b')));
  await assertSucceeds(getDoc(doc(member('parent', false), 'family/a/shortlist/b')));
  await assertFails(getDoc(doc(member('limited', false), 'family/a/shortlist/b')));
  await assertSucceeds(getDoc(doc(member('parent', false), 'family/a/memberships/parent')));
  await assertFails(getDoc(doc(member('limited', false), 'family/a/memberships/parent')));
  await assertFails(getDoc(doc(member('parent', false), 'family/a/invitations/i')));
  await assertFails(getDoc(doc(member('parent', false), 'family/a/history/h')));
  await assertSucceeds(getDoc(doc(member('a'), 'family/a/history/h')));
  await assertSucceeds(getDoc(doc(member('parent', false), 'familyLinks/parent/circles/a')));
  await assertFails(setDoc(doc(member('parent', false), 'family/a/memberships/parent'), { permissions: ['view_proposals'] }));
  await assertFails(getDoc(doc(member('z'), 'family/a/shortlist/b')));
  await assertFails(setDoc(doc(member('parent', false), 'family/a'), { guardians: ['z'] }));
  await assertFails(updateDoc(doc(member('parent', false), 'family/a/shortlist/b'), { firstName: 'X' }));
  await assertFails(getDoc(doc(member('parent', false), 'matches/a_b')));
  await assertFails(getDoc(doc(member('parent', false), 'matches/a_b/messages/m')));
  await assertFails(getDoc(doc(member('parent', false), 'accounts/a')));
  await assertFails(getDoc(doc(member('parent', false), 'accounts/a/documents/name-proof')));

  // A revoked guardian loses everything on the next request.
  await env.withSecurityRulesDisabled((c) => deleteDoc(doc(c.firestore(), 'family/a/memberships/parent')));
  await assertFails(getDoc(doc(member('parent', false), 'family/a/shortlist/b')));
  await assertFails(getDoc(doc(member('parent', false), 'family/a')));
});

test('purchases and the credit ledger are readable by their owner and written by nobody', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'purchases/p'), { uid: 'a', productId: 'x' });
    await setDoc(doc(c.firestore(), 'creditLedger/l'), { uid: 'a', delta: 5 });
  });
  await assertSucceeds(getDoc(doc(member('a'), 'purchases/p')));
  await assertFails(getDoc(doc(member('b'), 'purchases/p')));
  await assertFails(setDoc(doc(member('a'), 'purchases/q'), { uid: 'a' }));
  await assertSucceeds(getDoc(doc(member('a'), 'creditLedger/l')));
  await assertFails(setDoc(doc(member('a'), 'creditLedger/m'), { uid: 'a', delta: 99 }));
});

test('notification settings accept known categories, and devices are server-written', async () => {
  await assertSucceeds(setDoc(doc(member('a'), 'accounts/a/settings/notifications'), { messages: false }));
  await assertFails(setDoc(doc(member('a'), 'accounts/a/settings/notifications'), { billing: false }));
  await assertFails(setDoc(doc(member('b'), 'accounts/a/settings/notifications'), { messages: false }));
  await assertFails(setDoc(doc(member('a'), 'accounts/a/devices/t'), { token: 't' }));
});

test('a member reads their own deletion status and nobody else can', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'deletionRequests/a'), { status: 'pending' }));
  await assertSucceeds(getDoc(doc(member('a'), 'deletionRequests/a')));
  await assertFails(getDoc(doc(member('b'), 'deletionRequests/a')));
  await assertFails(setDoc(doc(member('a'), 'deletionRequests/a'), { status: 'done' }));
  await assertFails(getDoc(doc(member('a'), 'auditLogs/x')));
  await assertFails(getDoc(doc(member('a'), 'rateLimits/x')));
  await assertFails(getDoc(doc(member('a'), 'familyInviteIndex/x')));
  await assertFails(getDoc(doc(member('a'), 'subjectConfirmations/x')));
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

test('photos: only the owner writes and reads their originals', async () => {
  await assertSucceeds(uploadBytes(ref(store('a'), 'photos/a/1.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(store('z'), 'photos/a/2.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(store('a'), 'photos/a/3.exe'), image, { contentType: 'application/octet-stream' }));
  await assertSucceeds(getBytes(ref(store('a'), 'photos/a/1.jpg')));
});

test('SEC-01: an approved stranger cannot read or list another member\'s photos', async () => {
  await assertSucceeds(uploadBytes(ref(store('a'), 'photos/a/2.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(getBytes(ref(store('b'), 'photos/a/2.jpg')));
  await assertFails(listAll(ref(store('b'), 'photos/a')));
  await assertFails(getBytes(ref(store('b', false), 'photos/a/2.jpg')));
});

test('SEC-02: a photo cannot be replaced after upload', async () => {
  await assertSucceeds(uploadBytes(ref(store('a'), 'photos/a/4.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(store('a'), 'photos/a/4.jpg'), image, { contentType: 'image/jpeg' }));
  await assertSucceeds(deleteObject(ref(store('a'), 'photos/a/4.jpg')));
});

test('SEC-15: SVG uploads are refused', async () => {
  await assertFails(uploadBytes(ref(store('a'), 'photos/a/5.svg'), image, { contentType: 'image/svg+xml' }));
  await assertFails(uploadBytes(ref(store('a'), 'verification/a/name-proof/5.svg'), image, { contentType: 'image/svg+xml' }));
});

test('SEC-14: drafts accept only known fields of a sensible size', async () => {
  await assertFails(setDoc(doc(member('a'), 'drafts/a'), { fullName: 'A', invented: true }));
  await assertFails(setDoc(doc(member('a'), 'drafts/a'), { fullName: 'x'.repeat(200) }));
  await assertFails(setDoc(doc(member('a'), 'drafts/a'), { photos: Array(20).fill('p') }));
});

test('submissions and published photos are closed to clients', async () => {
  await assertFails(getDoc(doc(member('a'), 'submissions/a')));
  await assertFails(setDoc(doc(member('a'), 'submissions/a'), { version: 9 }));
  await assertFails(getBytes(ref(store('a'), 'published/a/1.jpg')));
  await assertFails(uploadBytes(ref(store('a'), 'published/a/1.jpg'), image, { contentType: 'image/jpeg' }));
});

test('verification documents cannot be read back by anyone', async () => {
  await assertSucceeds(uploadBytes(ref(store('a'), 'verification/a/name-proof/1.jpg'), image, { contentType: 'image/jpeg' }));
  await assertFails(getBytes(ref(store('a'), 'verification/a/name-proof/1.jpg')));
  await assertFails(getBytes(ref(store('b'), 'verification/a/name-proof/1.jpg')));
  await assertFails(uploadBytes(ref(store('b'), 'verification/a/name-proof/2.jpg'), image, { contentType: 'image/jpeg' }));
});
