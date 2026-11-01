import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp, Transaction } from 'firebase-admin/firestore';
import { getDownloadURL, getStorage } from 'firebase-admin/storage';
import { setGlobalOptions } from 'firebase-functions/v2';
import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { randomInt, randomUUID } from 'node:crypto';
import * as R from './rules';

initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 20 });
export const db = getFirestore();
// A missing optional field must not fail a whole write.
db.settings({ ignoreUndefinedProperties: true });

export function uidOf(req: CallableRequest): string {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  return req.auth.uid;
}

/** Only members whose profile passed review may act on other members. */
export function approvedUid(req: CallableRequest): string {
  const uid = uidOf(req);
  if (req.auth?.token.approved !== true) {
    throw new HttpsError('permission-denied', 'Your profile has not been approved yet.');
  }
  return uid;
}

export function reviewerUid(req: CallableRequest): string {
  const uid = uidOf(req);
  if (req.auth?.token.reviewer !== true) throw new HttpsError('permission-denied', 'Reviewers only.');
  return uid;
}

export function stringArg(value: unknown, name: string, max = 128): string {
  if (typeof value !== 'string' || value.length === 0 || value.length > max) {
    throw new HttpsError('invalid-argument', `${name} is invalid.`);
  }
  return value;
}

/** Ids become document paths, so a slash must never reach one. */
export const idArg = (value: unknown, name: string): string => {
  const id = stringArg(value, name);
  if (id.includes('/')) throw new HttpsError('invalid-argument', `${name} is invalid.`);
  return id;
};

export async function limits(): Promise<R.Limits> {
  const snap = await db.doc('config/app').get();
  return { ...R.DEFAULT_LIMITS, ...(snap.data()?.limits ?? {}) };
}

export const accountRef = (uid: string) => db.doc(`accounts/${uid}`);
export const blockRef = (uid: string, other: string) => db.doc(`accounts/${uid}/blocks/${other}`);

export async function isPremium(uid: string): Promise<boolean> {
  const until = (await accountRef(uid).get()).data()?.premiumUntil as Timestamp | undefined;
  return until !== undefined && until.toMillis() > Date.now();
}

export async function blockedEitherWay(a: string, b: string, tx?: Transaction): Promise<boolean> {
  const refs = [blockRef(a, b), blockRef(b, a)];
  const snaps = tx ? await Promise.all(refs.map((r) => tx.get(r))) : await Promise.all(refs.map((r) => r.get()));
  return snaps.some((s) => s.exists);
}

export function notify(
  tx: Transaction | FirebaseFirestore.WriteBatch, uid: string, type: string, title: string, body: string, deepLink: string,
): void {
  const ref = accountRef(uid).collection('notifications').doc();
  (tx as FirebaseFirestore.WriteBatch).set(ref, {
    type, title, body, deepLink, read: false, createdAt: FieldValue.serverTimestamp(),
  });
}

export function openMatch(tx: Transaction, a: string, b: string): void {
  tx.set(db.doc(`matches/${R.pairId(a, b)}`), {
    users: [a, b].sort(), status: 'active', createdAt: FieldValue.serverTimestamp(),
    readAt: {}, unread: { [a]: 0, [b]: 0 },
  });
  notify(tx, a, 'match', 'New match', 'Interest is mutual. Chat is now open.', `/chat/${b}`);
  notify(tx, b, 'match', 'New match', 'Interest is mutual. Chat is now open.', `/chat/${a}`);
}

export async function newCode(collection: string, data: Record<string, unknown>): Promise<string> {
  for (let i = 0; i < 6; i++) {
    const code = R.makeCode(() => randomInt(0, 1_000_000) / 1_000_000);
    try {
      await db.doc(`${collection}/${code}`).create(data);
      return code;
    } catch {
      // Taken. Try another.
    }
  }
  throw new HttpsError('unavailable', 'Please try again.');
}

export async function closeMatch(a: string, b: string, status: string): Promise<void> {
  const ref = db.doc(`matches/${R.pairId(a, b)}`);
  if ((await ref.get()).exists) await ref.update({ status });
  await db.doc(`contactShares/${R.pairId(a, b)}`).delete();
}

/** Append-only record of a privileged action. Ids and action names only. */
export function audit(
  writer: Transaction | FirebaseFirestore.WriteBatch, actor: string, action: string, target: string, detail: string = '',
): void {
  (writer as FirebaseFirestore.WriteBatch).set(db.collection('auditLogs').doc(), {
    actor, action, target, detail, at: FieldValue.serverTimestamp(),
  });
}

/** A long-lived link carrying its own token. Only for already-published copies. */
export async function tokenUrl(path: string): Promise<string> {
  const file = getStorage().bucket().file(path);
  const token = randomUUID();
  await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  return host
    ? `http://${host}/v0/b/${file.bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`
    : getDownloadURL(file);
}

/** A short-lived read link. The emulator cannot sign, so it uses a token URL. */
export async function readUrl(path: string, minutes: number): Promise<string> {
  const file = getStorage().bucket().file(path);
  if (process.env.FUNCTIONS_EMULATOR === 'true') return tokenUrl(path);
  const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + minutes * 60000 });
  return url;
}

/** Checks a member's upload by its real bytes and size. Bad files are deleted. */
export async function checkUpload(path: string, allowed: string[]): Promise<void> {
  const file = getStorage().bucket().file(path);
  const [exists] = await file.exists();
  if (!exists) throw new HttpsError('invalid-argument', 'That file did not finish uploading.');
  const [meta] = await file.getMetadata();
  const [head] = await file.download({ start: 0, end: 11 });
  const type = R.sniffType(head);
  if (Number(meta.size) > R.MAX_UPLOAD_BYTES || type === null || !allowed.includes(type)) {
    await file.delete().catch(() => undefined);
    throw new HttpsError('invalid-argument', 'That file type is not supported.');
  }
}
