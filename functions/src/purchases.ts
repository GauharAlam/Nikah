import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { onMessagePublished } from 'firebase-functions/v2/pubsub';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import * as R from './rules';
import { accountRef, audit, db, notify, reviewerUid, stringArg, uidOf } from './shared';
import { appleIssuerId, appleKeyId, applePrivateKey, verifyWithStore } from './stores';

const STORE_SECRETS = [appleKeyId, appleIssuerId, applePrivateKey];

async function storeConfig(): Promise<{ products: Record<string, R.Product>; packageName: string }> {
  const config = (await db.doc('config/app').get()).data();
  return {
    products: { ...R.DEFAULT_PRODUCTS, ...(config?.products ?? {}) },
    packageName: config?.appId ?? process.env.APP_ID ?? 'com.gauharalam.nikah',
  };
}

const purchaseRef = (platform: string, id: string) => db.doc(`purchases/${R.hashOf(`${platform}:${id}`)}`);

/** Grants a purchase once. A renewal is a new transaction with a new date. */
async function grant(uid: string, platform: string, token: string, product: R.Product, verified: R.VerifiedPurchase): Promise<void> {
  const ref = purchaseRef(platform, verified.transactionId);
  await db.runTransaction(async (tx) => {
    const seen = (await tx.get(ref)).data();
    if (seen && seen.uid !== uid) throw new HttpsError('permission-denied', 'This purchase belongs to another account.');
    if (seen) return;
    tx.set(ref, {
      uid, platform, productId: verified.productId, kind: product.kind, tokenHash: R.hashOf(token),
      state: 'active', expiresAt: verified.expiresAt ?? null, createdAt: FieldValue.serverTimestamp(),
    });
    if (product.kind === 'subscription') {
      tx.set(accountRef(uid), {
        premiumUntil: Timestamp.fromMillis(verified.expiresAt ?? 0), plan: verified.productId,
      }, { merge: true });
    } else {
      tx.set(db.collection('creditLedger').doc(), {
        uid, delta: product.credits, reason: 'purchase', purchase: ref.id, createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(accountRef(uid), { purchasedCredits: FieldValue.increment(product.credits ?? 0) }, { merge: true });
    }
    notify(tx, uid, 'subscription', 'Purchase confirmed', 'Thank you. Your purchase is active.', '/home/premium');
  });
}

/** Takes back exactly what one purchase granted. Safe to run twice. */
async function revoke(platform: string, verified: R.VerifiedPurchase): Promise<void> {
  const ref = purchaseRef(platform, verified.transactionId);
  await db.runTransaction(async (tx) => {
    const p = (await tx.get(ref)).data();
    if (!p || p.state === 'refunded') return;
    tx.update(ref, { state: 'refunded', refundedAt: FieldValue.serverTimestamp() });
    if (p.kind === 'subscription') {
      tx.set(accountRef(p.uid), { premiumUntil: Timestamp.now() }, { merge: true });
    } else {
      const { credits = 0 } = (await storeConfig()).products[p.productId] ?? {};
      tx.set(db.collection('creditLedger').doc(), {
        uid: p.uid, delta: -credits, reason: 'refund', purchase: ref.id, createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(accountRef(p.uid), { purchasedCredits: FieldValue.increment(-credits) }, { merge: true });
    }
    notify(tx, p.uid, 'subscription', 'Purchase refunded', 'A purchase was refunded by the store.', '/home/premium');
  });
}

async function lookUp(platform: string, token: string, productId: string) {
  const { products, packageName } = await storeConfig();
  const product = products[productId];
  if (!product) throw new HttpsError('invalid-argument', 'Unknown product.');
  const verified = await verifyWithStore({
    platform: platform === 'ios' ? 'ios' : 'android', token, productId,
    subscription: product.kind === 'subscription', packageName,
  });
  return { product, verified };
}

export const validatePurchase = onCall({ secrets: STORE_SECRETS }, async (req) => {
  const uid = uidOf(req);
  const productId = stringArg(req.data?.productId, 'productId');
  const platform = stringArg(req.data?.platform, 'platform');
  const token = stringArg(req.data?.token, 'token', 8000);
  const { product, verified } = await lookUp(platform, token, productId);
  const problem = R.purchaseProblem(productId, verified, Date.now());
  if (problem) throw new HttpsError('permission-denied', problem);
  await grant(uid, platform, token, product, verified!);
  return { ok: true };
});

/** Re-reads a purchase from the store. For support, and used by store webhooks. */
export const refreshPurchase = onCall({ secrets: STORE_SECRETS }, async (req) => {
  const reviewer = reviewerUid(req);
  const platform = stringArg(req.data?.platform, 'platform');
  const token = stringArg(req.data?.token, 'token', 8000);
  const productId = stringArg(req.data?.productId, 'productId');
  const { verified } = await lookUp(platform, token, productId);
  if (verified?.state === 'refunded') await revoke(platform, verified);
  const batch = db.batch();
  audit(batch, reviewer, 'purchase_refreshed', R.hashOf(token));
  await batch.commit();
  return { state: verified?.state ?? 'unknown' };
});

/** Google Play notifications arrive through the Pub/Sub topic set in Play Console. */
export const onPlayNotification = onMessagePublished({ topic: 'play-notifications', secrets: STORE_SECRETS }, async (event) => {
  const n = event.data.message.json as {
    subscriptionNotification?: { purchaseToken: string; subscriptionId: string };
    voidedPurchaseNotification?: { purchaseToken: string; orderId: string; productType: number };
  };
  if (n.voidedPurchaseNotification) {
    const { orderId } = n.voidedPurchaseNotification;
    await revoke('android', { transactionId: orderId, productId: '', state: 'refunded' });
    return;
  }
  const sub = n.subscriptionNotification;
  if (!sub) return;
  const { verified, product } = await lookUp('android', sub.purchaseToken, sub.subscriptionId);
  const owner = await db.collection('purchases').where('tokenHash', '==', R.hashOf(sub.purchaseToken)).limit(1).get();
  const uid = owner.docs[0]?.data().uid as string | undefined;
  if (uid && verified && !R.purchaseProblem(sub.subscriptionId, verified, Date.now())) {
    await grant(uid, 'android', sub.purchaseToken, product, verified);
  }
});

/**
 * App Store Server Notifications. The payload is only a hint: the transaction is
 * read back from Apple, so a forged request can change nothing.
 */
export const onAppStoreNotification = onRequest({ secrets: STORE_SECRETS }, async (req, res) => {
  try {
    const part = (jws: string) => JSON.parse(Buffer.from(jws.split('.')[1], 'base64url').toString());
    const signed: string | undefined = part(req.body.signedPayload).data?.signedTransactionInfo;
    if (signed) {
      const { transactionId, productId } = part(signed) as { transactionId: string; productId: string };
      const { verified } = await lookUp('ios', transactionId, productId);
      if (verified?.state === 'refunded') await revoke('ios', verified);
    }
    res.status(200).send('ok');
  } catch {
    res.status(400).send('bad request');
  }
});
