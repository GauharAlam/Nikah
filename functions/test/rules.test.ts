import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as r from '../src/rules';

const all: r.ProposalStatus[] = ['pending', 'accepted', 'declined', 'withdrawn', 'expired'];
const now = new Date('2026-11-01T12:00:00Z');

test('only pending can move, and only to a terminal status', () => {
  for (const f of all) for (const t of all) {
    assert.equal(r.canTransition(f, t), f === 'pending' && t !== 'pending', `${f}->${t}`);
  }
});

test('only the recipient answers and only the sender withdraws', () => {
  const p = { from: 'a', to: 'b' };
  assert.equal(r.actorAllowed('b', p, 'accepted'), true);
  assert.equal(r.actorAllowed('a', p, 'accepted'), false);
  assert.equal(r.actorAllowed('b', p, 'declined'), true);
  assert.equal(r.actorAllowed('a', p, 'declined'), false);
  assert.equal(r.actorAllowed('a', p, 'withdrawn'), true);
  assert.equal(r.actorAllowed('b', p, 'withdrawn'), false);
  assert.equal(r.actorAllowed('a', p, 'expired'), false);
});

test('pair ids do not depend on order', () => {
  assert.equal(r.pairId('b', 'a'), r.pairId('a', 'b'));
});

test('a counter from another day counts as zero', () => {
  assert.equal(r.countFor('2026-10-31', 5, r.dayKey(now)), 0);
  assert.equal(r.countFor('2026-11-01', 3, r.dayKey(now)), 3);
  assert.equal(r.countFor(undefined, undefined, r.dayKey(now)), 0);
});

test('age is computed against the birthday', () => {
  assert.equal(r.ageOn(Date.UTC(2008, 10, 1), now), 18);
  assert.equal(r.ageOn(Date.UTC(2008, 10, 2), now), 17);
});

const good: r.Draft = {
  fullName: 'A', gender: 'male', maritalStatus: 'Never married', marriageReadiness: 'Ready within 1 year',
  homeCity: 'Delhi', caste: 'Ansari', height: `5'10"`, phone: '+919999999999', almaMaters: ['AMU'],
  qualification: 'B.Tech', qualificationGraduate: true, profession: 'Engineer',
  dateOfBirth: Date.UTC(1998, 0, 1), photos: ['p'], intentConfirmed: true, dataConsent: true,
};

test('a complete draft has no problems', () => {
  assert.deepEqual(r.draftProblems(good, r.DEFAULT_LIMITS, now), []);
});

test('under-18, non-graduate, photo-less and missing fields are refused', () => {
  const p = (d: Partial<r.Draft>) => r.draftProblems({ ...good, ...d }, r.DEFAULT_LIMITS, now);
  assert.ok(p({ dateOfBirth: Date.UTC(2010, 0, 1) }).some((x) => x.includes('18')));
  assert.ok(p({ qualificationGraduate: false }).some((x) => x.includes('graduates')));
  assert.ok(p({ photos: [] }).some((x) => x.includes('photo')));
  assert.ok(p({ almaMaters: [] }).some((x) => x.includes('Alma')));
  assert.ok(p({ gender: 'other' }).some((x) => x.includes('Gender')));
});

test('premium filters are stripped for free members', () => {
  const f: r.Filters = { minAge: 25, caste: 'Syed', education: 'MBA', profession: 'Doctor', location: 'Delhi' };
  assert.deepEqual(r.allowedFilters(f, false), { minAge: 25, caste: 'Syed' });
  assert.deepEqual(r.allowedFilters(f, true), f);
});

const card: r.Card = { age: 27, maritalStatus: 'Never married', caste: 'Syed', university: 'Aligarh Muslim University',
  education: 'MBA', profession: 'Doctor', location: 'Okhla, Delhi' };

test('filters combine', () => {
  assert.equal(r.matchesFilters(card, { minAge: 21, maxAge: 30, caste: 'Syed', location: 'delhi' }), true);
  assert.equal(r.matchesFilters(card, { minAge: 28 }), false);
  assert.equal(r.matchesFilters(card, { caste: 'Khan' }), false);
  assert.equal(r.matchesFilters(card, { caste: r.ANY, marital: undefined } as r.Filters), true);
});

test('blocked, matched, proposed and hidden profiles leave discovery', () => {
  const base = { blocked: false, hasProposal: false, matched: false };
  const t = now.getTime();
  assert.equal(r.visibleInDiscovery(base, t), true);
  assert.equal(r.visibleInDiscovery({ ...base, blocked: true }, t), false);
  assert.equal(r.visibleInDiscovery({ ...base, matched: true }, t), false);
  assert.equal(r.visibleInDiscovery({ ...base, hasProposal: true }, t), false);
  assert.equal(r.visibleInDiscovery({ ...base, hiddenUntil: t + 1 }, t), false);
  assert.equal(r.visibleInDiscovery({ ...base, hiddenUntil: t - 1 }, t), true);
});

test('intent and consent are required, and family profiles need the person\'s agreement', () => {
  const p = (d: Partial<r.Draft>) => r.draftProblems({ ...good, ...d }, r.DEFAULT_LIMITS, now);
  assert.ok(p({ intentConfirmed: false }).some((x) => x.includes('marriage')));
  assert.ok(p({ dataConsent: false }).some((x) => x.includes('Agree')));
  assert.ok(p({ managedBy: 'family' }).some((x) => x.includes('agreed')));
  assert.deepEqual(p({ managedBy: 'family', candidateConsent: true }), []);
});

test('caste is optional, and the graduate rule is a setting', () => {
  assert.deepEqual(r.draftProblems({ ...good, caste: undefined }, r.DEFAULT_LIMITS, now), []);
  const open = { ...r.DEFAULT_LIMITS, graduatesOnly: false };
  assert.deepEqual(r.draftProblems({ ...good, qualificationGraduate: false }, open, now), []);
});

test('private photos reach only a match, and hidden caste reaches nobody', () => {
  const c = { photos: ['a'], caste: 'Syed', photoPrivacy: 'matches', showCaste: false };
  assert.deepEqual(r.redactCard(c, false).photos, []);
  assert.equal(r.redactCard(c, false).photosHidden, true);
  assert.deepEqual(r.redactCard(c, true).photos, ['a']);
  assert.equal(r.redactCard(c, true).caste, '');
  assert.equal('photoPrivacy' in r.redactCard(c, true), false);
  assert.deepEqual(r.redactCard({ photos: ['a'], photoPrivacy: 'everyone' }, false).photos, ['a']);
});

test('a credit returns only in the month it was spent, and never below zero', () => {
  assert.equal(r.creditsAfterRefund('2026-11', 3, '2026-11'), 2);
  assert.equal(r.creditsAfterRefund('2026-10', 3, '2026-11'), 3);
  assert.equal(r.creditsAfterRefund('2026-11', 0, '2026-11'), 0);
  assert.equal(r.creditsAfterRefund(undefined, 2, '2026-11'), 2);
});

test('holds need enough different reporters', () => {
  assert.equal(r.shouldHold(2, r.DEFAULT_LIMITS), false);
  assert.equal(r.shouldHold(3, r.DEFAULT_LIMITS), true);
});

test('stale profiles leave discovery', () => {
  const base = { blocked: false, hasProposal: false, matched: false, staleDays: 45 };
  const t = now.getTime();
  assert.equal(r.visibleInDiscovery({ ...base, lastActiveAt: t - 46 * 86400000 }, t), false);
  assert.equal(r.visibleInDiscovery({ ...base, lastActiveAt: t - 44 * 86400000 }, t), true);
});
