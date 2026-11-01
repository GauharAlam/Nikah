import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as R from './rules';
import { accountRef, approvedUid, blockedEitherWay, db, idArg, isPremium, limits } from './shared';

function toPublicCard(
  id: string, d: Record<string, any>, now: Date, viewerMatched: boolean, viewer?: Record<string, any>,
) {
  const { dateOfBirth, live, approvedAt, gender, lastActiveAt, held, reportCount, partnerCaste, nearbyOptIn, ...rest } = d;
  const active = (lastActiveAt as Timestamp | undefined)?.toMillis();
  const age = R.ageOn(dateOfBirth, now);
  const score = viewer ? R.matchScore(
    { ...viewer, age: viewer.dateOfBirth ? R.ageOn(viewer.dateOfBirth, now) : undefined },
    { age, location: d.location, country: d.country, sect: d.sect, marriageReadiness: d.marriageReadiness,
      maritalStatus: d.maritalStatus, caste: d.showCaste === false ? undefined : d.caste },
  ) : undefined;
  return {
    ...R.redactCard(rest, viewerMatched), id, age, matchPercent: score,
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
  const premium = await isPremium(uid);
  const filters = R.allowedFilters((req.data?.filters ?? {}) as R.Filters, premium);
  const lim = await limits();
  const viewKey = R.windowKey(lim.freeProfileWindow, now);
  const pageSize = R.pageSize(req.data?.limit);
  if (pageSize === null) throw new HttpsError('invalid-argument', 'Page size is invalid.');
  const nearby = req.data?.mode === 'nearby';
  if (nearby && me.nearbyOptIn !== true) {
    throw new HttpsError('failed-precondition', 'Turn on nearby discovery in settings first.');
  }
  const myCity = R.cityOf(me.location);

  const [blocksOut, blocksIn, hidden, sent, received, matches, viewedSnap, accSnap] = await Promise.all([
    accountRef(uid).collection('blocks').get(),
    db.collectionGroup('blocks').where('target', '==', uid).get(),
    accountRef(uid).collection('hidden').get(),
    db.collection('proposals').where('from', '==', uid).select('to').limit(2000).get(),
    db.collection('proposals').where('to', '==', uid).select('from').limit(2000).get(),
    db.collection('matches').where('users', 'array-contains', uid).select('users').limit(2000).get(),
    accountRef(uid).collection('viewed').get(),
    accountRef(uid).get(),
  ]);
  const viewed = new Set(viewedSnap.docs.map((d) => d.id));
  let remaining = premium ? Number.POSITIVE_INFINITY : R.viewsLeft(
    lim.freeProfileLimit, R.countFor(accSnap.data()?.viewKey, accSnap.data()?.viewCount, viewKey),
  );
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

  const out: { id: string }[] = [];
  const fresh: string[] = [];
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
    if (nearby && (doc.data().nearbyOptIn !== true || R.cityOf(doc.data().location) !== myCity)) continue;
    const card = toPublicCard(doc.id, doc.data(), now, false, me);
    if (!R.matchesFilters(card as unknown as R.Card, filters)) continue;
    // A profile counts once. Ones already seen stay free to see again.
    if (!premium && !viewed.has(doc.id)) {
      if (remaining <= 0) continue;
      remaining--;
      fresh.push(doc.id);
    }
    out.push(card as { id: string });
    if (out.length === pageSize) break;
  }

  // Re-checked in a transaction, so parallel calls cannot pass the limit.
  let granted = new Set(fresh);
  let left: number | null = null;
  if (!premium) {
    left = await db.runTransaction(async (tx) => {
      const acc = (await tx.get(accountRef(uid))).data() ?? {};
      const used = R.countFor(acc.viewKey, acc.viewCount, viewKey);
      const allowed = fresh.slice(0, R.viewsLeft(lim.freeProfileLimit, used));
      granted = new Set(allowed);
      if (allowed.length > 0) {
        tx.set(accountRef(uid), { viewKey, viewCount: used + allowed.length }, { merge: true });
        allowed.forEach((id) => tx.set(accountRef(uid).collection('viewed').doc(id), { at: Timestamp.now() }));
      }
      return R.viewsLeft(lim.freeProfileLimit, used + allowed.length);
    });
  }
  return {
    profiles: out.filter((p) => viewed.has(p.id) || premium || granted.has(p.id)),
    cursor: left === 0 ? null : scanned.size === 60 || out.length === pageSize ? last : null,
    freeLeft: left, freeLimit: lim.freeProfileLimit, limitReached: left === 0,
  };
});

export const getProfiles = onCall(async (req) => {
  const uid = approvedUid(req);
  const ids: unknown = req.data?.ids;
  if (!Array.isArray(ids) || ids.length > 30) throw new HttpsError('invalid-argument', 'Too many profiles.');
  const now = new Date();
  const me = (await db.doc(`profiles/${uid}`).get()).data();
  const premium = await isPremium(uid);
  const results = await Promise.all(ids.map(async (raw) => {
    const id = idArg(raw, 'id');
    const [snap, blocked, match] = await Promise.all([
      db.doc(`profiles/${id}`).get(), blockedEitherWay(uid, id), db.doc(`matches/${R.pairId(uid, id)}`).get(),
    ]);
    const d = snap.data();
    const activeMatch = match.data()?.status === 'active';
    if (!d || !R.canViewProfile({
      live: d.live === true, activeMatch, blocked, oppositeGender: R.gendersCompatible(me?.gender, d.gender),
    })) return null;
    if (!premium && !activeMatch) {
      // Free members may open a profile they were shown or have a connection with.
      const links = await Promise.all([
        accountRef(uid).collection('viewed').doc(id).get(),
        db.doc(`proposals/${R.proposalId(uid, id)}`).get(),
        db.doc(`proposals/${R.proposalId(id, uid)}`).get(),
        db.doc(`contactRequests/${R.proposalId(uid, id)}`).get(),
        db.doc(`contactRequests/${R.proposalId(id, uid)}`).get(),
      ]);
      if (!links.some((l) => l.exists)) return null;
    }
    return toPublicCard(id, d, now, activeMatch, me);
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
