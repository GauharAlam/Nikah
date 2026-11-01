import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp, Transaction } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getDownloadURL, getStorage } from 'firebase-admin/storage';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret } from 'firebase-functions/params';
import { google } from 'googleapis';
import * as R from './rules';

initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 20 });
const db = getFirestore();

// ─── Shared helpers ───────────────────────────────────────────────────────────

function uidOf(req: CallableRequest): string {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  return req.auth.uid;
}

/** Only members whose profile passed review may act on other members. */
function approvedUid(req: CallableRequest): string {
  const uid = uidOf(req);
  if (req.auth?.token.approved !== true) {
    throw new HttpsError('permission-denied', 'Your profile has not been approved yet.');
  }
  return uid;
}

function reviewerUid(req: CallableRequest): string {
  const uid = uidOf(req);
  if (req.auth?.token.reviewer !== true) throw new HttpsError('permission-denied', 'Reviewers only.');
  return uid;
}

function stringArg(value: unknown, name: string, max = 128): string {
  if (typeof value !== 'string' || value.length === 0 || value.length > max) {
    throw new HttpsError('invalid-argument', `${name} is invalid.`);
  }
  return value;
}

/** Ids become document paths, so a slash must never reach one. */
const idArg = (value: unknown, name: string): string => {
  const id = stringArg(value, name);
  if (id.includes('/')) throw new HttpsError('invalid-argument', `${name} is invalid.`);
  return id;
};

async function limits(): Promise<R.Limits> {
  const snap = await db.doc('config/app').get();
  return { ...R.DEFAULT_LIMITS, ...(snap.data()?.limits ?? {}) };
}

const accountRef = (uid: string) => db.doc(`accounts/${uid}`);
const blockRef = (uid: string, other: string) => db.doc(`accounts/${uid}/blocks/${other}`);

async function isPremium(uid: string): Promise<boolean> {
  const until = (await accountRef(uid).get()).data()?.premiumUntil as Timestamp | undefined;
  return until !== undefined && until.toMillis() > Date.now();
}

async function blockedEitherWay(a: string, b: string, tx?: Transaction): Promise<boolean> {
  const refs = [blockRef(a, b), blockRef(b, a)];
  const snaps = tx ? await Promise.all(refs.map((r) => tx.get(r))) : await Promise.all(refs.map((r) => r.get()));
  return snaps.some((s) => s.exists);
}

function notify(
  tx: Transaction | FirebaseFirestore.WriteBatch, uid: string, type: string, title: string, body: string, deepLink: string,
): void {
  const ref = accountRef(uid).collection('notifications').doc();
  (tx as FirebaseFirestore.WriteBatch).set(ref, {
    type, title, body, deepLink, read: false, createdAt: FieldValue.serverTimestamp(),
  });
}

function openMatch(tx: Transaction, a: string, b: string): void {
  tx.set(db.doc(`matches/${R.pairId(a, b)}`), {
    users: [a, b].sort(), status: 'active', createdAt: FieldValue.serverTimestamp(),
    readAt: {}, unread: { [a]: 0, [b]: 0 },
  });
  notify(tx, a, 'match', 'New match', 'Interest is mutual. Chat is now open.', `/chat/${b}`);
  notify(tx, b, 'match', 'New match', 'Interest is mutual. Chat is now open.', `/chat/${a}`);
}

// ─── Profile submission and review ────────────────────────────────────────────

export const submitProfile = onCall(async (req) => {
  const uid = uidOf(req);
  const draft = (await db.doc(`drafts/${uid}`).get()).data() as R.Draft | undefined;
  if (!draft) throw new HttpsError('failed-precondition', 'Complete your profile first.');
  const problems = R.draftProblems(draft, await limits(), new Date());
  if (problems.length > 0) throw new HttpsError('failed-precondition', problems[0], { problems });
  const lim = await limits();
  if (lim.requireIdProof) {
    const id = await db.doc(`accounts/${uid}/documents/name-proof`).get();
    if (!['pending', 'approved'].includes(id.data()?.status)) {
      throw new HttpsError('failed-precondition', 'Upload your ID before submitting.');
    }
  }
  await accountRef(uid).set({
    stage: 'submitted', submittedAt: FieldValue.serverTimestamp(), rejectionReason: FieldValue.delete(),
  }, { merge: true });
  return { stage: 'submitted' };
});

function cardFrom(uid: string, d: Record<string, any>, photoUrls: string[]) {
  const location = [d.homeCity, d.homeState].filter(Boolean).join(', ');
  const universities: string[] = d.almaMaters ?? [];
  return {
    id: uid, name: d.fullName, gender: d.gender, dateOfBirth: d.dateOfBirth, photos: photoUrls,
    profession: d.profession, employer: d.company ?? '', education: d.qualification,
    university: universities.join(', '), location, country: d.homeCountry ?? '', caste: d.caste,
    maritalStatus: d.maritalStatus, marriageReadiness: d.marriageReadiness, height: d.height,
    aboutMe: d.aboutMe ?? '', selfManaged: d.managedBy !== 'family', verified: false, live: true,
    sect: d.sect ?? '', prayer: d.prayer ?? '', practices: d.practices ?? [], children: d.children ?? '',
    photoPrivacy: d.photoPrivacy === 'matches' ? 'matches' : 'everyone',
    showCaste: d.showCaste !== false, allowFamilyShare: d.allowFamilyShare !== false,
    approvedAt: FieldValue.serverTimestamp(), lastActiveAt: FieldValue.serverTimestamp(),
  };
}

export const listReviewQueue = onCall(async (req) => {
  reviewerUid(req);
  const queued = await db.collection('accounts').where('stage', '==', 'submitted')
    .orderBy('submittedAt').limit(50).get();
  const held = await db.collection('profiles').where('held', '==', true).limit(50).get();
  const drafts = await Promise.all(queued.docs.map((d) => db.doc(`drafts/${d.id}`).get()));
  const docs = await Promise.all(queued.docs.map((d) => d.ref.collection('documents').get()));
  return {
    items: queued.docs.map((d, i) => ({
      uid: d.id, draft: drafts[i].data() ?? {},
      documents: docs[i].docs.map((x) => ({ type: x.id, status: x.data().status, count: (x.data().paths ?? []).length })),
    })),
    held: held.docs.map((d) => ({ uid: d.id, name: d.data().name, reports: d.data().reportCount ?? 0 })),
  };
});

export const getDocumentUrl = onCall(async (req) => {
  reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  const type = idArg(req.data?.type, 'type');
  const snap = await db.doc(`accounts/${uid}/documents/${type}`).get();
  const paths: string[] = snap.data()?.paths ?? [];
  const urls = await Promise.all(paths.map(async (p) => {
    const [url] = await getStorage().bucket().file(p).getSignedUrl({
      action: 'read', expires: Date.now() + 5 * 60 * 1000,
    });
    return url;
  }));
  return { urls };
});

export const reviewProfile = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  const approve = req.data?.approve === true;
  const reason = approve ? '' : stringArg(req.data?.reason, 'reason', 300);
  const draft = (await db.doc(`drafts/${uid}`).get()).data();
  if (!draft) throw new HttpsError('not-found', 'Draft not found.');
  const paths: string[] = draft.photos ?? [];
  if (!paths.every((p) => p.startsWith(`photos/${uid}/`) && !p.includes('..'))) {
    throw new HttpsError('failed-precondition', 'Photos must belong to this member.');
  }
  const bucket = getStorage().bucket();
  const photoUrls = approve ? await Promise.all(paths.map((p) => getDownloadURL(bucket.file(p)))) : [];

  const batch = db.batch();
  if (approve) {
    batch.set(db.doc(`profiles/${uid}`), { ...cardFrom(uid, draft, photoUrls), held: FieldValue.delete() }, { merge: true });
    batch.set(accountRef(uid), {
      stage: 'approved', approvedAt: FieldValue.serverTimestamp(), reviewedBy: reviewer,
      phone: draft.phone ?? '',
    }, { merge: true });
    notify(batch, uid, 'review', 'Your profile is approved', 'Your profile is now live.', '/home/discovery');
  } else {
    batch.set(accountRef(uid), { stage: 'rejected', rejectionReason: reason, reviewedBy: reviewer }, { merge: true });
    if ((await db.doc(`profiles/${uid}`).get()).exists) batch.update(db.doc(`profiles/${uid}`), { live: false });
    notify(batch, uid, 'review', 'Your profile needs changes', reason, '/review/status');
  }
  await batch.commit();
  // The claim opens member-only rules, so it follows the committed decision.
  const user = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(uid, { ...(user.customClaims ?? {}), approved: approve });
  return { ok: true };
});

// ─── Verification documents ──────────────────────────────────────────────────

const DOC_TYPES = ['name-proof', 'education-proof', 'employment-proof'];

export const submitDocument = onCall(async (req) => {
  const uid = uidOf(req);
  const type = stringArg(req.data?.type, 'type');
  if (!DOC_TYPES.includes(type)) throw new HttpsError('invalid-argument', 'Unknown document type.');
  const paths = req.data?.paths;
  if (!Array.isArray(paths) || paths.length === 0 || paths.length > 2) {
    throw new HttpsError('invalid-argument', 'Upload one or two files.');
  }
  const prefix = `verification/${uid}/${type}/`;
  if (!paths.every((p) => typeof p === 'string' && p.startsWith(prefix) && !p.includes('..'))) {
    throw new HttpsError('permission-denied', 'That file does not belong to you.');
  }
  await db.doc(`accounts/${uid}/documents/${type}`).set({
    status: 'pending', paths, submittedAt: FieldValue.serverTimestamp(), rejectionReason: FieldValue.delete(),
  }, { merge: true });
  return { status: 'pending' };
});

export const reviewDocument = onCall(async (req) => {
  const reviewer = reviewerUid(req);
  const uid = idArg(req.data?.uid, 'uid');
  const type = idArg(req.data?.type, 'type');
  const approve = req.data?.approve === true;
  const reason = approve ? '' : stringArg(req.data?.reason, 'reason', 300);
  const ref = db.doc(`accounts/${uid}/documents/${type}`);

  const batch = db.batch();
  batch.set(ref, approve
    ? { status: 'approved', reviewedBy: reviewer }
    : { status: 'rejected', rejectionReason: reason, reviewedBy: reviewer }, { merge: true });
  notify(batch, uid, 'verification', approve ? 'Document approved' : 'Document needs attention',
    approve ? 'Your document passed review.' : reason, '/profile/verify');
  await batch.commit();

  const docs = await ref.parent.get();
  const approved = new Set(docs.docs.filter((d) => d.data().status === 'approved').map((d) => d.id));
  const verified = approved.has('name-proof') && approved.has('education-proof');
  const profile = db.doc(`profiles/${uid}`);
  if ((await profile.get()).exists) await profile.update({ verified, verifiedDocs: [...approved].sort() });
  return { ok: true };
});

// ─── Discovery ───────────────────────────────────────────────────────────────

function toPublicCard(id: string, d: Record<string, any>, now: Date, viewerMatched: boolean) {
  const { dateOfBirth, live, approvedAt, gender, lastActiveAt, held, reportCount, ...rest } = d;
  const active = (lastActiveAt as Timestamp | undefined)?.toMillis();
  return {
    ...R.redactCard(rest, viewerMatched), id, age: R.ageOn(dateOfBirth, now),
    activeDaysAgo: active === undefined ? null : Math.floor((now.getTime() - active) / 86400000),
    isNew: (approvedAt as Timestamp | undefined)?.toMillis() !== undefined &&
      now.getTime() - (approvedAt as Timestamp).toMillis() < 7 * 86400000,
  };
}

export const fetchIntroductions = onCall(async (req) => {
  const uid = approvedUid(req);
  const now = new Date();
  const me = (await db.doc(`profiles/${uid}`).get()).data();
  if (!me) throw new HttpsError('failed-precondition', 'Your profile is not live.');
  const filters = R.allowedFilters((req.data?.filters ?? {}) as R.Filters, await isPremium(uid));
  const lim = await limits();
  const pageSize = Math.min(Number(req.data?.limit ?? 10), 20);

  const [blocksOut, blocksIn, hidden, sent, received, matches] = await Promise.all([
    accountRef(uid).collection('blocks').get(),
    db.collectionGroup('blocks').where('target', '==', uid).get(),
    accountRef(uid).collection('hidden').get(),
    db.collection('proposals').where('from', '==', uid).get(),
    db.collection('proposals').where('to', '==', uid).get(),
    db.collection('matches').where('users', 'array-contains', uid).get(),
  ]);
  const blocked = new Set([...blocksOut.docs.map((d) => d.id), ...blocksIn.docs.map((d) => d.ref.parent.parent!.id)]);
  const proposed = new Set([...sent.docs.map((d) => d.data().to), ...received.docs.map((d) => d.data().from)]);
  const matched = new Set(matches.docs.flatMap((d) => d.data().users as string[]));
  const hiddenUntil = new Map(hidden.docs.map((d) => [d.id, (d.data().until as Timestamp).toMillis()]));

  // Scans a bounded window, so one member can never page the whole collection.
  let query = db.collection('profiles')
    .where('gender', '==', me.gender === 'male' ? 'female' : 'male')
    .where('live', '==', true).orderBy('approvedAt', 'desc').limit(60);
  const cursor = req.data?.cursor;
  if (typeof cursor === 'number') query = query.startAfter(Timestamp.fromMillis(cursor));

  const out: unknown[] = [];
  let last: number | null = null;
  const scanned = await query.get();
  for (const doc of scanned.docs) {
    last = (doc.data().approvedAt as Timestamp).toMillis();
    if (doc.id === uid) continue;
    const visible = R.visibleInDiscovery({
      blocked: blocked.has(doc.id), hasProposal: proposed.has(doc.id), matched: matched.has(doc.id),
      hiddenUntil: hiddenUntil.get(doc.id),
      lastActiveAt: (doc.data().lastActiveAt as Timestamp | undefined)?.toMillis(), staleDays: lim.staleDays,
    }, now.getTime());
    if (!visible) continue;
    const card = toPublicCard(doc.id, doc.data(), now, false);
    if (!R.matchesFilters(card as unknown as R.Card, filters)) continue;
    out.push(card);
    if (out.length === pageSize) break;
  }
  return { profiles: out, cursor: scanned.size === 60 || out.length === pageSize ? last : null };
});

export const getProfiles = onCall(async (req) => {
  const uid = approvedUid(req);
  const ids: unknown = req.data?.ids;
  if (!Array.isArray(ids) || ids.length > 30) throw new HttpsError('invalid-argument', 'Too many profiles.');
  const now = new Date();
  const me = (await db.doc(`profiles/${uid}`).get()).data();
  const results = await Promise.all(ids.map(async (raw) => {
    const id = idArg(raw, 'id');
    const [snap, blocked, match] = await Promise.all([
      db.doc(`profiles/${id}`).get(), blockedEitherWay(uid, id), db.doc(`matches/${R.pairId(uid, id)}`).get(),
    ]);
    const d = snap.data();
    if (!d || blocked || d.gender === me?.gender) return null;
    return toPublicCard(id, d, now, match.data()?.status === 'active');
  }));
  return { profiles: results.filter(Boolean) };
});

/** Marks a profile "Don't show" and spends one daily decision. */
export const hideProfile = onCall(async (req) => {
  const uid = approvedUid(req);
  const target = idArg(req.data?.target, 'target');
  const lim = await limits();
  const key = R.dayKey(new Date());
  await db.runTransaction(async (tx) => {
    const acc = (await tx.get(accountRef(uid))).data() ?? {};
    const used = R.countFor(acc.decisionDay, acc.decisionCount, key);
    if (used >= lim.decisionsPerDay) throw new HttpsError('resource-exhausted', 'Daily decision limit reached.');
    tx.set(accountRef(uid), { decisionDay: key, decisionCount: used + 1 }, { merge: true });
    tx.set(accountRef(uid).collection('hidden').doc(target), {
      until: Timestamp.fromMillis(Date.now() + lim.hideDays * 86400000),
    });
  });
  return { ok: true };
});

// ─── Proposals ───────────────────────────────────────────────────────────────

export const sendProposal = onCall(async (req) => {
  const uid = approvedUid(req);
  const to = idArg(req.data?.to, 'to');
  if (to === uid) throw new HttpsError('invalid-argument', 'You cannot propose to yourself.');
  const lim = await limits();
  const key = R.dayKey(new Date());
  const premium = await isPremium(uid);

  return db.runTransaction(async (tx) => {
    if (await blockedEitherWay(uid, to, tx)) throw new HttpsError('not-found', 'This profile is unavailable.');
    const target = await tx.get(db.doc(`profiles/${to}`));
    if (!target.exists || target.data()?.live !== true) throw new HttpsError('not-found', 'This profile is unavailable.');

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
  const due = await db.collection('proposals').where('status', '==', 'pending')
    .where('expiresAt', '<', Timestamp.now()).limit(400).get();
  const batch = db.batch();
  due.docs.forEach((d) => batch.update(d.ref, { status: 'expired' }));
  await batch.commit();
});

// ─── Contact sharing ─────────────────────────────────────────────────────────

export const requestContact = onCall(async (req) => {
  const uid = approvedUid(req);
  const to = idArg(req.data?.to, 'to');
  const lim = await limits();
  const month = R.monthKey(new Date());
  return db.runTransaction(async (tx) => {
    if (await blockedEitherWay(uid, to, tx)) throw new HttpsError('not-found', 'This profile is unavailable.');
    const ref = db.doc(`contactRequests/${R.proposalId(uid, to)}`);
    const [existing, acc] = await Promise.all([tx.get(ref), tx.get(accountRef(uid))]);
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

// ─── Safety ──────────────────────────────────────────────────────────────────

async function closeMatch(a: string, b: string, status: string): Promise<void> {
  const ref = db.doc(`matches/${R.pairId(a, b)}`);
  if ((await ref.get()).exists) await ref.update({ status });
  await db.doc(`contactShares/${R.pairId(a, b)}`).delete();
}

export const updatePrivacy = onCall(async (req) => {
  const uid = approvedUid(req);
  const update: Record<string, unknown> = {};
  if (req.data?.photoPrivacy === 'everyone' || req.data?.photoPrivacy === 'matches') update.photoPrivacy = req.data.photoPrivacy;
  if (typeof req.data?.showCaste === 'boolean') update.showCaste = req.data.showCaste;
  if (typeof req.data?.allowFamilyShare === 'boolean') update.allowFamilyShare = req.data.allowFamilyShare;
  await Promise.all([db.doc(`profiles/${uid}`).update(update), db.doc(`drafts/${uid}`).set(update, { merge: true })]);
  return { ok: true };
});

/** Called when the app opens. Stale profiles leave discovery. */
export const touchActive = onCall(async (req) => {
  const uid = approvedUid(req);
  const profile = db.doc(`profiles/${uid}`);
  if ((await profile.get()).exists) await profile.update({ lastActiveAt: FieldValue.serverTimestamp() });
  return { ok: true };
});

export const unmatch = onCall(async (req) => {
  const uid = approvedUid(req);
  await closeMatch(uid, idArg(req.data?.other, 'other'), 'closed');
  return { ok: true };
});

export const blockProfile = onCall(async (req) => {
  const uid = uidOf(req);
  const target = idArg(req.data?.target, 'target');
  await blockRef(uid, target).set({ target, createdAt: FieldValue.serverTimestamp() });
  await closeMatch(uid, target, 'blocked');
  const pending = [R.proposalId(uid, target), R.proposalId(target, uid)];
  await Promise.all(pending.map((id) => db.runTransaction(async (tx) => {
    const ref = db.doc(`proposals/${id}`);
    if ((await tx.get(ref)).data()?.status === 'pending') tx.update(ref, { status: 'declined' });
  })));
  return { ok: true };
});

export const reportProfile = onCall(async (req) => {
  const uid = uidOf(req);
  const target = idArg(req.data?.target, 'target');
  // One document per reporter and target, so one member cannot trigger a hold alone.
  await db.doc(`reports/${R.proposalId(uid, target)}`).set({
    reporter: uid, target, reason: stringArg(req.data?.reason, 'reason', R.REPORT_REASON_MAX),
    status: 'open', createdAt: FieldValue.serverTimestamp(),
  });
  const reports = await db.collection('reports').where('target', '==', target).where('status', '==', 'open').count().get();
  const count = reports.data().count;
  const profile = db.doc(`profiles/${target}`);
  if ((await profile.get()).exists) {
    await profile.update(R.shouldHold(count, await limits())
      ? { live: false, held: true, reportCount: count }
      : { reportCount: count });
  }
  return { ok: true };
});

export const deleteAccount = onCall(async (req) => {
  const uid = uidOf(req);
  await db.doc(`profiles/${uid}`).delete();
  const relations = await Promise.all([
    db.collection('proposals').where('from', '==', uid).get(),
    db.collection('proposals').where('to', '==', uid).get(),
    db.collection('contactRequests').where('from', '==', uid).get(),
    db.collection('contactRequests').where('to', '==', uid).get(),
    db.collection('contactShares').where('users', 'array-contains', uid).get(),
  ]);
  await Promise.all(relations.flatMap((s) => s.docs.map((d) => d.ref.delete())));
  const matches = await db.collection('matches').where('users', 'array-contains', uid).get();
  await Promise.all(matches.docs.map((m) => db.recursiveDelete(m.ref)));
  await db.recursiveDelete(accountRef(uid));
  await db.doc(`drafts/${uid}`).delete();
  const bucket = getStorage().bucket();
  await Promise.all([bucket.deleteFiles({ prefix: `photos/${uid}/` }), bucket.deleteFiles({ prefix: `verification/${uid}/` })]);
  await getAuth().deleteUser(uid);
  return { ok: true };
});

// ─── Messaging and push ──────────────────────────────────────────────────────

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
});

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

// ─── Purchases ───────────────────────────────────────────────────────────────

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
