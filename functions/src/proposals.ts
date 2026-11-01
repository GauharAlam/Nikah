import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { expiredProposalIds } from './expiry';
import * as R from './rules';
import { accountRef, approvedUid, blockedEitherWay, db, idArg, isPremium, limits, notify, openMatch } from './shared';

export const sendProposal = onCall(async (req) => {
  const uid = approvedUid(req);
  const to = idArg(req.data?.to, 'to');
  if (to === uid) throw new HttpsError('invalid-argument', 'You cannot propose to yourself.');
  const lim = await limits();
  const key = R.dayKey(new Date());
  const premium = await isPremium(uid);

  return db.runTransaction(async (tx) => {
    if (await blockedEitherWay(uid, to, tx)) throw new HttpsError('not-found', 'This profile is unavailable.');
    const [target, self] = await Promise.all([tx.get(db.doc(`profiles/${to}`)), tx.get(db.doc(`profiles/${uid}`))]);
    if (target.data()?.live !== true || !R.gendersCompatible(self.data()?.gender, target.data()?.gender)) {
      throw new HttpsError('not-found', 'This profile is unavailable.');
    }

    const ref = db.doc(`proposals/${R.proposalId(uid, to)}`);
    const reverseRef = db.doc(`proposals/${R.proposalId(to, uid)}`);
    const [mine, reverse, acc, pendingSnap] = await Promise.all([
      tx.get(ref), tx.get(reverseRef), tx.get(accountRef(uid)),
      tx.get(db.collection('proposals').where('from', '==', uid).where('status', '==', 'pending').limit(lim.pendingLimit + 1)),
    ]);
    const status = mine.data()?.status;
    // Idempotent retry; a declined proposal stays declined.
    if (status === 'pending' || status === 'accepted' || status === 'declined') return { status };

    const account = acc.data() ?? {};
    const used = R.countFor(account.proposalDay, account.proposalCount, key);
    if (!premium && used >= lim.proposalsPerDay) throw new HttpsError('resource-exhausted', 'Daily proposal limit reached.');
    if (!premium && pendingSnap.size >= lim.pendingLimit) throw new HttpsError('resource-exhausted', 'Too many profiles waiting.');

    tx.set(accountRef(uid), { proposalDay: key, proposalCount: used + 1 }, { merge: true });
    const now = FieldValue.serverTimestamp();
    if (reverse.data()?.status === 'pending') {
      // Both sides have now said yes.
      tx.update(reverseRef, { status: 'accepted', respondedAt: now });
      tx.set(ref, { from: uid, to, status: 'accepted', createdAt: now, respondedAt: now });
      openMatch(tx, uid, to);
      return { status: 'accepted' };
    }
    tx.set(ref, {
      from: uid, to, status: 'pending', createdAt: now,
      expiresAt: Timestamp.fromMillis(Date.now() + lim.proposalExpiryDays * 86400000),
    });
    notify(tx, to, 'proposal', 'New proposal', 'Someone sent you a proposal.', '/home/proposals');
    return { status: 'pending' };
  });
});

async function moveProposal(ref: FirebaseFirestore.DocumentReference, actor: string, next: R.ProposalStatus): Promise<void> {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const p = snap.data() as { from: string; to: string; status: R.ProposalStatus } | undefined;
    if (!p) throw new HttpsError('not-found', 'Proposal not found.');
    if (!R.actorAllowed(actor, p, next)) throw new HttpsError('permission-denied', 'Not allowed.');
    if (!R.canTransition(p.status, next)) throw new HttpsError('failed-precondition', 'This proposal was already answered.');
    if (next === 'accepted' && await blockedEitherWay(p.from, p.to, tx)) {
      throw new HttpsError('not-found', 'This profile is unavailable.');
    }
    tx.update(ref, { status: next, respondedAt: FieldValue.serverTimestamp() });
    if (next === 'accepted') openMatch(tx, p.from, p.to);
    if (next === 'declined') notify(tx, p.from, 'proposal', 'Proposal update', 'One of your proposals was answered.', '/home/proposals');
  });
}

export const respondProposal = onCall(async (req) => {
  const uid = approvedUid(req);
  const from = idArg(req.data?.from, 'from');
  await moveProposal(db.doc(`proposals/${R.proposalId(from, uid)}`), uid, req.data?.accept === true ? 'accepted' : 'declined');
  return { ok: true };
});

export const withdrawProposal = onCall(async (req) => {
  const uid = approvedUid(req);
  const to = idArg(req.data?.to, 'to');
  await moveProposal(db.doc(`proposals/${R.proposalId(uid, to)}`), uid, 'withdrawn');
  return { ok: true };
});

export const expireProposals = onSchedule('every 24 hours', async () => {
  // Drains the backlog page by page, so a busy day never leaves proposals behind.
  for (;;) {
    const due = await db.collection('proposals').where('status', '==', 'pending')
      .where('expiresAt', '<', Timestamp.now()).limit(200).get();
    await expiredProposalIds(db, due.docs.map((d) => d.ref));
    if (due.size < 200) return;
  }
});
