import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as R from './rules';
import { accountRef, approvedUid, blockedEitherWay, db, idArg, limits, notify, openMatch } from './shared';

export const requestContact = onCall(async (req) => {
  const uid = approvedUid(req);
  const to = idArg(req.data?.to, 'to');
  const lim = await limits();
  const month = R.monthKey(new Date());
  return db.runTransaction(async (tx) => {
    if (await blockedEitherWay(uid, to, tx)) throw new HttpsError('not-found', 'This profile is unavailable.');
    const ref = db.doc(`contactRequests/${R.proposalId(uid, to)}`);
    const [existing, acc, self, target] = await Promise.all([
      tx.get(ref), tx.get(accountRef(uid)), tx.get(db.doc(`profiles/${uid}`)), tx.get(db.doc(`profiles/${to}`)),
    ]);
    if (target.data()?.live !== true || !R.gendersCompatible(self.data()?.gender, target.data()?.gender)) {
      throw new HttpsError('not-found', 'This profile is unavailable.');
    }
    if (existing.data()?.status === 'pending') return { status: 'pending' }; // No second charge.
    const a = acc.data() ?? {};
    const spent = R.countFor(a.creditMonth, a.creditsSpent, month);
    const allowance = lim.monthlyContactCredits + (a.purchasedCredits ?? 0);
    if (spent >= allowance) throw new HttpsError('resource-exhausted', 'No contact credits left.');
    tx.set(accountRef(uid), { creditMonth: month, creditsSpent: spent + 1 }, { merge: true });
    tx.set(ref, { from: uid, to, status: 'pending', month, createdAt: FieldValue.serverTimestamp() });
    notify(tx, to, 'contact', 'Contact request', 'Someone asked to share contact details.', '/home/proposals');
    return { status: 'pending' };
  });
});

export const respondContact = onCall(async (req) => {
  const uid = approvedUid(req);
  const from = idArg(req.data?.from, 'from');
  const accept = req.data?.accept === true;
  const ref = db.doc(`contactRequests/${R.proposalId(from, uid)}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.data()?.status !== 'pending') throw new HttpsError('failed-precondition', 'This request was already answered.');
    const matchRef = db.doc(`matches/${R.pairId(from, uid)}`);
    const [a, b, match] = await Promise.all([tx.get(accountRef(from)), tx.get(accountRef(uid)), tx.get(matchRef)]);
    tx.update(ref, { status: accept ? 'accepted' : 'declined', respondedAt: FieldValue.serverTimestamp() });
    if (!accept) {
      // Members pay only for a yes.
      tx.set(accountRef(from), {
        creditsSpent: R.creditsAfterRefund(snap.data()?.month, a.data()?.creditsSpent, a.data()?.creditMonth),
      }, { merge: true });
      return;
    }
    tx.set(db.doc(`contactShares/${R.pairId(from, uid)}`), {
      users: [from, uid].sort(), phones: { [from]: a.data()?.phone ?? '', [uid]: b.data()?.phone ?? '' },
      createdAt: FieldValue.serverTimestamp(),
    });
    if (!match.exists) openMatch(tx, from, uid);
    notify(tx, from, 'contact', 'Contact shared', 'Your request was accepted.', `/match/${uid}`);
  });
  return { ok: true };
});

export const expireContactRequests = onSchedule('every 24 hours', async () => {
  const lim = await limits();
  const cutoff = Timestamp.fromMillis(Date.now() - lim.contactExpiryDays * 86400000);
  const due = await db.collection('contactRequests').where('status', '==', 'pending')
    .where('createdAt', '<', cutoff).limit(200).get();
  await Promise.all(due.docs.map((doc) => db.runTransaction(async (tx) => {
    const account = accountRef(doc.data().from);
    const acc = (await tx.get(account)).data();
    tx.update(doc.ref, { status: 'expired' });
    tx.set(account, {
      creditsSpent: R.creditsAfterRefund(doc.data().month, acc?.creditsSpent, acc?.creditMonth),
    }, { merge: true });
  })));
});
