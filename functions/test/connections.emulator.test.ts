// Blocks, visibility and contact: consent must hold on every path, not just the obvious one.
import { before, test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { admin, code, profile, user } from './helpers';

let db: FirebaseFirestore.Firestore;
const hour = 3600000;

async function pair(a: string, b: string) {
  await db.doc(`profiles/${a}`).set(profile(a, 'male'));
  await db.doc(`profiles/${b}`).set(profile(b, 'female'));
  await db.doc(`accounts/${a}`).set({ stage: 'approved', phone: '+911' });
  await db.doc(`accounts/${b}`).set({ stage: 'approved', phone: '+912' });
  return [await user(a, { approved: true }), await user(b, { approved: true })];
}

before(() => { db = admin().db; });

test('SEC-05: blocking the requester stops a pending contact request', async () => {
  const [a, b] = await pair('c1', 'c2');
  await a('requestContact', { to: 'c2' });
  const spent = (await db.doc('accounts/c1').get()).data()?.creditsSpent;
  await b('blockProfile', { target: 'c1' });
  assert.equal(await code(b('respondContact', { from: 'c1', accept: true })), 'functions/failed-precondition');
  assert.equal((await db.doc('contactShares/c1_c2').get()).exists, false);
  assert.equal((await db.doc('accounts/c1').get()).data()?.creditsSpent, spent - 1, 'the requester is refunded');
});

test('SEC-05: a block made by the requester also stops the exchange', async () => {
  const [a, b] = await pair('c3', 'c4');
  await a('requestContact', { to: 'c4' });
  await a('blockProfile', { target: 'c4' });
  assert.equal(await code(b('respondContact', { from: 'c3', accept: true })), 'functions/failed-precondition');
  assert.equal((await db.doc('contactShares/c3_c4').get()).exists, false);
  assert.equal((await db.doc('matches/c3_c4').get()).exists, false);
});

test('SEC-05: a block landing between request and answer is checked in the transaction', async () => {
  const [a, b] = await pair('c5', 'c6');
  await a('requestContact', { to: 'c6' });
  await db.doc('accounts/c6/blocks/c5').set({ target: 'c5' });
  assert.equal(await code(b('respondContact', { from: 'c5', accept: true })), 'functions/not-found');
  assert.equal((await db.doc('contactShares/c5_c6').get()).exists, false);
});

test('SEC-10: a held profile is not served to someone who merely viewed it', async () => {
  const [a] = await pair('v1', 'v2');
  await db.doc('accounts/v1/viewed/v2').set({ at: Timestamp.now() });
  assert.equal((await a('getProfiles', { ids: ['v2'] })).profiles.length, 1);
  await db.doc('profiles/v2').update({ live: false, held: true });
  assert.equal((await a('getProfiles', { ids: ['v2'] })).profiles.length, 0);
});

test('SEC-10: premium does not reach a profile that left discovery', async () => {
  const [a] = await pair('v3', 'v4');
  await db.doc('accounts/v3').set({ premiumUntil: Timestamp.fromMillis(Date.now() + hour) }, { merge: true });
  await db.doc('profiles/v4').update({ live: false });
  assert.equal((await a('getProfiles', { ids: ['v4'] })).profiles.length, 0);
});

test('SEC-10: an active match keeps a view of a member who was held', async () => {
  const [a] = await pair('v5', 'v6');
  await db.doc('matches/v5_v6').set({ users: ['v5', 'v6'], status: 'active' });
  await db.doc('profiles/v6').update({ live: false, held: true });
  assert.equal((await a('getProfiles', { ids: ['v6'] })).profiles.length, 1);
});

test('SEC-20: discovery cards hold public fields only', async () => {
  const [a] = await pair('d1', 'd2');
  await db.doc('profiles/d2').update({
    name: 'Sara Khan', employer: 'Apollo', photoPaths: ['published/d2/1.jpg'], reportCount: 2,
    family: { background: 'Private' }, partnerCaste: 'Syed',
  });
  const { profiles } = await a('fetchIntroductions');
  const card = profiles.find((p: any) => p.id === 'd2');
  assert.ok(card, 'the card is shown');
  assert.equal(card.name, 'Sara');
  for (const key of ['employer', 'photoPaths', 'reportCount', 'family', 'partnerCaste', 'dateOfBirth', 'phone', 'gender']) {
    assert.equal(card[key], undefined, `${key} must not leave the server`);
  }
});

test('SEC-20: a match sees the full name, employer and family details', async () => {
  const [a] = await pair('d3', 'd4');
  await db.doc('profiles/d4').update({ name: 'Sara Khan', employer: 'Apollo', family: { background: 'Teachers' } });
  await db.doc('matches/d3_d4').set({ users: ['d3', 'd4'], status: 'active' });
  const [card] = (await a('getProfiles', { ids: ['d4'] })).profiles;
  assert.equal(card.name, 'Sara Khan');
  assert.equal(card.employer, 'Apollo');
  assert.equal(card.family.background, 'Teachers');
});

test('SEC-21: expiry never overrides an answered proposal', async () => {
  await db.doc('proposals/e1_e2').set({ from: 'e1', to: 'e2', status: 'accepted', expiresAt: Timestamp.fromMillis(Date.now() - hour) });
  const { expiredProposalIds } = await import('../src/expiry');
  const moved = await expiredProposalIds(db, [db.doc('proposals/e1_e2')]);
  assert.deepEqual(moved, []);
  assert.equal((await db.doc('proposals/e1_e2').get()).data()?.status, 'accepted');
});

test('SEC-25: a declined contact request stays declined, with no second charge', async () => {
  const [a, b] = await pair('r1', 'r2');
  await a('requestContact', { to: 'r2' });
  await b('respondContact', { from: 'r1', accept: false });
  const spent = (await db.doc('accounts/r1').get()).data()?.creditsSpent;
  assert.equal(await code(a('requestContact', { to: 'r2' })), 'functions/failed-precondition');
  assert.equal((await db.doc('accounts/r1').get()).data()?.creditsSpent, spent);
});

test('search finds by text and country, and a bad page size is refused', async () => {
  const [a] = await pair('s1', 's2');
  await db.doc('profiles/s2').update({ university: 'Jamia Millia Islamia', country: 'India', location: 'Delhi' });
  const hit = await a('fetchIntroductions', { filters: { query: 'jamia' } });
  assert.ok(hit.profiles.some((p: any) => p.id === 's2'));
  const miss = await a('fetchIntroductions', { filters: { query: 'no such place' } });
  assert.ok(!miss.profiles.some((p: any) => p.id === 's2'));
  const other = await a('fetchIntroductions', { filters: { country: 'Canada' } });
  assert.ok(!other.profiles.some((p: any) => p.id === 's2'));
  assert.equal(await code(a('fetchIntroductions', { limit: 'lots' })), 'functions/invalid-argument');
});

test('nearby uses the shared city and respects a member who opted out', async () => {
  const [a] = await pair('n1', 'n2');
  await db.doc('profiles/n1').update({ location: 'Delhi, Delhi', nearbyOptIn: true });
  await db.doc('profiles/n2').update({ location: 'Delhi', nearbyOptIn: true });
  await db.doc('profiles/n3').set(profile('n3', 'female', { location: 'Delhi', nearbyOptIn: false }));
  await db.doc('profiles/n4').set(profile('n4', 'female', { location: 'Mumbai', nearbyOptIn: true }));
  const { profiles } = await a('fetchIntroductions', { mode: 'nearby' });
  const ids = profiles.map((p: any) => p.id);
  assert.ok(ids.includes('n2'));
  assert.ok(!ids.includes('n3'), 'opted out');
  assert.ok(!ids.includes('n4'), 'another city');
});

test('nearby needs the viewer to opt in too', async () => {
  const [a] = await pair('n5', 'n6');
  assert.equal(await code(a('fetchIntroductions', { mode: 'nearby' })), 'functions/failed-precondition');
});

test('a decline tells the sender without saying who else was involved', async () => {
  const [a, b] = await pair('p1', 'p2');
  await a('sendProposal', { to: 'p2' });
  await b('respondProposal', { from: 'p1', accept: false });
  const n = await db.collection('accounts/p1/notifications').where('type', '==', 'proposal').get();
  assert.ok(n.docs.some((d) => d.data().title === 'Proposal update'));
});
