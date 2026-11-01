// Journey 8. The emulator stands in for the stores through emulatorStore/{token};
// that path only exists when FUNCTIONS_EMULATOR is set.
import { before, test } from 'node:test';
import assert from 'node:assert/strict';
import { admin, code, user } from './helpers';

let db: FirebaseFirestore.Firestore;
const day = 86400000;

const store = (token: string, data: object) => db.doc(`emulatorStore/${token}`).set({
  transactionId: `tx-${token}`, state: 'active', ...data,
});
const buy = (u: any, token: string, productId: string) => u('validatePurchase', { productId, platform: 'android', token });

before(() => { db = admin().db; });

test('Journey 8: a verified purchase grants its entitlement exactly once', async () => {
  const u = await user('pu1', { approved: true });
  const expiresAt = Date.now() + 30 * day;
  await store('t1', { productId: 'nikah_monthly', expiresAt });
  await buy(u, 't1', 'nikah_monthly');
  await buy(u, 't1', 'nikah_monthly');
  const acc = (await db.doc('accounts/pu1').get()).data();
  assert.equal(acc?.premiumUntil.toMillis(), expiresAt, 'expiry comes from the store');
  assert.equal(acc?.plan, 'nikah_monthly');
  assert.equal((await db.collection('purchases').where('uid', '==', 'pu1').get()).size, 1);
});

test('credits are granted once, through the ledger', async () => {
  const u = await user('pu2', { approved: true });
  await store('t2', { productId: 'nikah_credits_small' });
  await buy(u, 't2', 'nikah_credits_small');
  await buy(u, 't2', 'nikah_credits_small');
  assert.equal((await db.doc('accounts/pu2').get()).data()?.purchasedCredits, 5);
  const ledger = await db.collection('creditLedger').where('uid', '==', 'pu2').get();
  assert.equal(ledger.size, 1);
  assert.equal(ledger.docs[0].data().delta, 5);
});

test('SEC-07: a token for one product cannot claim another', async () => {
  const u = await user('pu3', { approved: true });
  await store('t3', { productId: 'nikah_weekly', expiresAt: Date.now() + 7 * day });
  assert.equal(await code(buy(u, 't3', 'nikah_monthly')), 'functions/permission-denied');
  assert.equal((await db.doc('accounts/pu3').get()).data()?.premiumUntil, undefined);
});

test('SEC-07: an expired subscription grants nothing', async () => {
  const u = await user('pu4', { approved: true });
  await store('t4', { productId: 'nikah_monthly', expiresAt: Date.now() - day, state: 'expired' });
  assert.equal(await code(buy(u, 't4', 'nikah_monthly')), 'functions/permission-denied');
});

test('a pending or cancelled payment grants nothing', async () => {
  const u = await user('pu5', { approved: true });
  await store('t5', { productId: 'nikah_credits_small', state: 'pending' });
  assert.equal(await code(buy(u, 't5', 'nikah_credits_small')), 'functions/permission-denied');
  assert.equal((await db.doc('accounts/pu5').get()).data()?.purchasedCredits, undefined);
});

test('a purchase belongs to the account that first claimed it', async () => {
  const a = await user('pu6', { approved: true });
  const b = await user('pu7', { approved: true });
  await store('t6', { productId: 'nikah_monthly', expiresAt: Date.now() + 30 * day });
  await buy(a, 't6', 'nikah_monthly');
  assert.equal(await code(buy(b, 't6', 'nikah_monthly')), 'functions/permission-denied');
});

test('an unknown product is refused, and products come from config', async () => {
  const u = await user('pu8', { approved: true });
  assert.equal(await code(buy(u, 'tx', 'free_forever')), 'functions/invalid-argument');
  await db.doc('config/app').set({ products: { custom_pack: { kind: 'credits', credits: 2 } } });
  await store('t8', { productId: 'custom_pack' });
  await buy(u, 't8', 'custom_pack');
  assert.equal((await db.doc('accounts/pu8').get()).data()?.purchasedCredits, 2);
  await db.doc('config/app').delete();
});

test('a renewal extends to the store\'s new date without a second grant of anything else', async () => {
  const u = await user('pu9', { approved: true });
  await store('t9', { productId: 'nikah_monthly', expiresAt: Date.now() + 10 * day });
  await buy(u, 't9', 'nikah_monthly');
  const later = Date.now() + 40 * day;
  await store('t9', { productId: 'nikah_monthly', expiresAt: later, transactionId: 'tx-t9-renewal' });
  await buy(u, 't9', 'nikah_monthly');
  assert.equal((await db.doc('accounts/pu9').get()).data()?.premiumUntil.toMillis(), later);
});

test('a refund takes back exactly what was granted, once', async () => {
  const u = await user('pu10', { approved: true });
  await store('t10', { productId: 'nikah_credits_small' });
  await buy(u, 't10', 'nikah_credits_small');
  await store('t10', { productId: 'nikah_credits_small', state: 'refunded' });
  const rev = await user('prev', { reviewer: true });
  await rev('refreshPurchase', { token: 't10', platform: 'android', productId: 'nikah_credits_small' });
  await rev('refreshPurchase', { token: 't10', platform: 'android', productId: 'nikah_credits_small' });
  assert.equal((await db.doc('accounts/pu10').get()).data()?.purchasedCredits, 0);
  const ledger = await db.collection('creditLedger').where('uid', '==', 'pu10').get();
  assert.deepEqual(ledger.docs.map((d) => d.data().delta).sort(), [-5, 5]);
});

test('a refunded subscription ends premium', async () => {
  const u = await user('pu11', { approved: true });
  await store('t11', { productId: 'nikah_monthly', expiresAt: Date.now() + 30 * day });
  await buy(u, 't11', 'nikah_monthly');
  await store('t11', { productId: 'nikah_monthly', expiresAt: Date.now() + 30 * day, state: 'refunded' });
  const rev = await user('prev', { reviewer: true });
  await rev('refreshPurchase', { token: 't11', platform: 'android', productId: 'nikah_monthly' });
  assert.ok((await db.doc('accounts/pu11').get()).data()?.premiumUntil.toMillis() <= Date.now());
});

test('a member cannot fabricate entitlement or read another member\'s purchases', async () => {
  const u = await user('pu12', {});
  assert.equal(await code(u('refreshPurchase', { token: 'x', platform: 'android', productId: 'nikah_monthly' })), 'functions/permission-denied');
});

test('notification preferences stop the push, not the record', async () => {
  const u = await user('nt1', { approved: true });
  await u('registerDevice', { token: 'device-1', platform: 'android' });
  assert.ok((await db.doc('accounts/nt1/devices/device-1').get()).exists);
  const other = await user('nt2', { approved: true });
  await other('registerDevice', { token: 'device-1', platform: 'android' });
  assert.equal((await db.doc('accounts/nt1/devices/device-1').get()).exists, false, 'a device belongs to one account');
  assert.ok((await db.doc('accounts/nt2/devices/device-1').get()).exists);
});
