import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { google } from 'googleapis';
import { accountRef, db, stringArg, uidOf } from './shared';

const appleSecret = defineSecret('APPLE_SHARED_SECRET');
const PLAN_DAYS: Record<string, number> = { barkat_monthly: 30, barkat_weekly: 7 };
const CREDIT_PACKS: Record<string, number> = { barkat_credit_single: 1, barkat_credits_small: 5 };

async function validGoogle(packageName: string, productId: string, token: string, subscription: boolean): Promise<boolean> {
  const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/androidpublisher'] });
  const api = google.androidpublisher({ version: 'v3', auth });
  if (subscription) {
    const res = await api.purchases.subscriptionsv2.get({ packageName, token });
    return res.data.subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE';
  }
  const res = await api.purchases.products.get({ packageName, productId, token });
  return res.data.purchaseState === 0;
}

async function validApple(receipt: string, productId: string): Promise<boolean> {
  const call = async (url: string) => (await (await fetch(url, {
    method: 'POST', body: JSON.stringify({ 'receipt-data': receipt, password: appleSecret.value() }),
  })).json()) as { status: number; latest_receipt_info?: { product_id: string }[]; receipt?: { in_app?: { product_id: string }[] } };
  let res = await call('https://buy.itunes.apple.com/verifyReceipt');
  if (res.status === 21007) res = await call('https://sandbox.itunes.apple.com/verifyReceipt');
  if (res.status !== 0) return false;
  const items = [...(res.latest_receipt_info ?? []), ...(res.receipt?.in_app ?? [])];
  return items.some((i) => i.product_id === productId);
}

export const validatePurchase = onCall({ secrets: [appleSecret] }, async (req) => {
  const uid = uidOf(req);
  const productId = stringArg(req.data?.productId, 'productId');
  const platform = stringArg(req.data?.platform, 'platform');
  const token = stringArg(req.data?.token, 'token', 200000);
  const days = PLAN_DAYS[productId];
  const credits = CREDIT_PACKS[productId];
  if (days === undefined && credits === undefined) throw new HttpsError('invalid-argument', 'Unknown product.');

  const ok = platform === 'android'
    ? await validGoogle(stringArg(req.data?.packageName, 'packageName'), productId, token, days !== undefined)
    : await validApple(token, productId);
  if (!ok) throw new HttpsError('permission-denied', 'Purchase could not be verified.');

  // One store token grants one entitlement, however often the app retries.
  const receipt = db.doc(`receipts/${Buffer.from(token).toString('base64url').slice(0, 200)}`);
  await db.runTransaction(async (tx) => {
    const seen = await tx.get(receipt);
    if (seen.exists && seen.data()?.uid !== uid) throw new HttpsError('permission-denied', 'Purchase belongs to another account.');
    if (seen.exists) return;
    tx.set(receipt, { uid, productId, createdAt: FieldValue.serverTimestamp() });
    tx.set(accountRef(uid), days !== undefined
      ? { premiumUntil: Timestamp.fromMillis(Date.now() + days * 86400000), plan: productId }
      : { purchasedCredits: FieldValue.increment(credits) }, { merge: true });
  });
  return { ok: true };
});
