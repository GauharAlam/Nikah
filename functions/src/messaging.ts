import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as R from './rules';
import { accountRef, db, limits } from './shared';

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
  await sendPush(other, 'New message', 'You have a new message.', `/chat/${message.sender}`);
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

export const onNotificationCreated = onDocumentCreated('accounts/{uid}/notifications/{id}', async (event) => {
  const n = event.data?.data();
  if (n) await sendPush(event.params.uid, n.title, 'Open the app to see more.', n.deepLink);
});

/** Payloads stay generic: names and message text never reach the lock screen. */
async function sendPush(uid: string, title: string, body: string, deepLink: string): Promise<void> {
  const devices = await accountRef(uid).collection('devices').get();
  if (devices.empty) return;
  const tokens = devices.docs.map((d) => d.id);
  const result = await getMessaging().sendEachForMulticast({ tokens, notification: { title, body }, data: { deepLink } });
  await Promise.all(result.responses.map((r, i) => {
    const code = r.error?.code;
    const dead = code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token';
    return dead ? devices.docs[i].ref.delete() : null;
  }));
}
