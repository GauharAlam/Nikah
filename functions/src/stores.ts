import { createPrivateKey, createSign } from 'node:crypto';
import { defineSecret } from 'firebase-functions/params';
import { google } from 'googleapis';
import type { StoreState, VerifiedPurchase } from './rules';
import { db } from './shared';

// Talks to Apple and Google. Everything that decides what a purchase is worth
// lives in rules.ts, so it can be tested without a store.

export const appleKeyId = defineSecret('APPLE_KEY_ID');
export const appleIssuerId = defineSecret('APPLE_ISSUER_ID');
export const applePrivateKey = defineSecret('APPLE_PRIVATE_KEY');

function appleToken(bundleId: string): string {
  const b64 = (v: unknown) => Buffer.from(JSON.stringify(v)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: appleKeyId.value(), typ: 'JWT' });
  const body = b64({ iss: appleIssuerId.value(), iat: now, exp: now + 300, aud: 'appstoreconnect-v1', bid: bundleId });
  const signature = createSign('SHA256').update(`${head}.${body}`)
    .sign({ key: createPrivateKey(applePrivateKey.value()), dsaEncoding: 'ieee-p1363' }, 'base64url');
  return `${head}.${body}.${signature}`;
}

async function appleTransaction(transactionId: string, bundleId: string): Promise<VerifiedPurchase | null> {
  const headers = { Authorization: `Bearer ${appleToken(bundleId)}` };
  for (const host of ['api.storekit.itunes.apple.com', 'api.storekit-sandbox.itunes.apple.com']) {
    const res = await fetch(`https://${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, { headers });
    if (res.status === 404) continue;
    if (!res.ok) throw new Error(`Apple returned ${res.status}`);
    const { signedTransactionInfo } = (await res.json()) as { signedTransactionInfo: string };
    // Fetched from Apple over TLS, so the payload needs no second signature check.
    const t = JSON.parse(Buffer.from(signedTransactionInfo.split('.')[1], 'base64url').toString()) as {
      transactionId: string; productId: string; expiresDate?: number; revocationDate?: number;
    };
    const expired = t.expiresDate !== undefined && t.expiresDate < Date.now();
    const state: StoreState = t.revocationDate ? 'refunded' : expired ? 'expired' : 'active';
    return { transactionId: t.transactionId, productId: t.productId, expiresAt: t.expiresDate, state };
  }
  return null;
}

async function googleSubscription(packageName: string, token: string): Promise<VerifiedPurchase | null> {
  const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
  const api = google.androidpublisher({ version: 'v3', auth });
  const { data } = await api.purchases.subscriptionsv2.get({ packageName, token });
  const line = data.lineItems?.[0];
  if (!line?.productId || !data.latestOrderId) return null;
  const states: Record<string, StoreState> = {
    SUBSCRIPTION_STATE_ACTIVE: 'active', SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'active',
    SUBSCRIPTION_STATE_CANCELED: 'active', SUBSCRIPTION_STATE_PENDING: 'pending',
    SUBSCRIPTION_STATE_ON_HOLD: 'expired', SUBSCRIPTION_STATE_PAUSED: 'expired',
    SUBSCRIPTION_STATE_EXPIRED: 'expired',
  };
  return {
    transactionId: data.latestOrderId, productId: line.productId,
    expiresAt: line.expiryTime ? Date.parse(line.expiryTime) : undefined,
    state: states[data.subscriptionState ?? ''] ?? 'pending',
  };
}

async function googleProduct(packageName: string, productId: string, token: string): Promise<VerifiedPurchase | null> {
  const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
  const api = google.androidpublisher({ version: 'v3', auth });
  const { data } = await api.purchases.products.get({ packageName, productId, token });
  if (!data.orderId) return null;
  const state: StoreState = data.purchaseState === 0 ? 'active' : data.purchaseState === 2 ? 'pending' : 'refunded';
  return { transactionId: data.orderId, productId, state };
}

export interface StoreRequest {
  platform: 'android' | 'ios'; token: string; productId: string; subscription: boolean;
  packageName: string;
}

/** The store's own record of a purchase, or null if it knows of none. */
export async function verifyWithStore(r: StoreRequest): Promise<VerifiedPurchase | null> {
  // Only the local emulator takes this path. A deployed function never has this set.
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    return (await db.doc(`emulatorStore/${r.token}`).get()).data() as VerifiedPurchase | undefined ?? null;
  }
  if (r.platform === 'ios') return appleTransaction(r.token, r.packageName);
  return r.subscription ? googleSubscription(r.packageName, r.token) : googleProduct(r.packageName, r.productId, r.token);
}
