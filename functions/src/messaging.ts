import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import { accountRef, db, limits, stringArg, uidOf } from './shared';

export const onMessageCreated = onDocumentCreated('matches/{pair}/messages/{id}', async (event) => {
  const message = event.data?.data();
  if (!message) return;
  const ref = db.doc(`matches/${event.params.pair}`);
  const match = (await ref.get()).data();
  if (!match) return;
  const other = (match.users as string[]).find((u) => u !== message.sender);
  if (!other) return;
  await ref.update({
    lastMessage: String(message.text).slice(0, 80), lastMessageAt: message.sentAt, lastSender: message.sender,
    [`unread.${other}`]: FieldValue.increment(1),
  });
  await sendPush(other, 'message', 'New message', 'You have a new message.', `/chat/${message.sender}`);
  await watchVolume(message.sender);
});

/** Unusual volume goes to a reviewer. Nothing happens to the member automatically. */
async function watchVolume(uid: string): Promise<void> {
  const lim = await limits();
  const key = R.dayKey(new Date());
  const ref = accountRef(uid);
  const count = await db.runTransaction(async (tx) => {
    const acc = (await tx.get(ref)).data() ?? {};
    const next = R.countFor(acc.messageDay, acc.messageCount, key) + 1;
    tx.set(ref, { messageDay: key, messageCount: next }, { merge: true });
    return next;
  });
  if (count === lim.suspiciousMessagesPerDay + 1) {
    await db.doc(`reports/system_${uid}`).set({
      reporter: 'system', target: uid, reason: 'High message volume', details: '', context: 'conversation',
      status: 'open', createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
}

/** A phone belongs to whoever is signed in on it, so pushes never reach a previous account. */
export const registerDevice = onCall(async (req) => {
  const uid = uidOf(req);
  const token = stringArg(req.data?.token, 'token', 512);
  if (token.includes('/')) throw new HttpsError('invalid-argument', 'token is invalid.');
  const others = await db.collectionGroup('devices').where('token', '==', token).get();
  await Promise.all(others.docs.filter((d) => d.ref.parent.parent?.id !== uid).map((d) => d.ref.delete()));
  await accountRef(uid).collection('devices').doc(token).set({
    token, platform: stringArg(req.data?.platform, 'platform', 16), updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

export const onNotificationCreated = onDocumentCreated('accounts/{uid}/notifications/{id}', async (event) => {
  const n = event.data?.data();
  if (n) await sendPush(event.params.uid, n.type, n.title, 'Open the app to see more.', n.deepLink);
});

/** Payloads stay generic: names and message text never reach the lock screen. */
async function sendPush(uid: string, type: string, title: string, body: string, deepLink: string): Promise<void> {
  const [prefs, devices] = await Promise.all([
    accountRef(uid).collection('settings').doc('notifications').get(), accountRef(uid).collection('devices').get(),
  ]);
  // Turning a category off stops the push. The in-app record stays.
  if (devices.empty || !R.wantsPush(prefs.data(), type)) return;
  const tokens = devices.docs.map((d) => d.id);
  const result = await getMessaging().sendEachForMulticast({ tokens, notification: { title, body }, data: { deepLink } });
  await Promise.all(result.responses.map((r, i) => {
    const code = r.error?.code;
    const dead = code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token';
    return dead ? devices.docs[i].ref.delete() : null;
  }));
}
