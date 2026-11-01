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
  homeCity: 'Delhi', caste: 'Ansari', height: `5'10"`, almaMaters: ['AMU'],
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
  assert.ok(p({ managedBy: 'family', candidateConsent: true }).some((x) => x.includes('phone')));
  assert.deepEqual(p({ managedBy: 'family', candidateConsent: true, subjectPhone: '+919000000000' }), []);
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

test('only a man and a woman are compatible', () => {
  assert.equal(r.gendersCompatible('male', 'female'), true);
  assert.equal(r.gendersCompatible('female', 'male'), true);
  assert.equal(r.gendersCompatible('male', 'male'), false);
  assert.equal(r.gendersCompatible('female', 'female'), false);
  assert.equal(r.gendersCompatible(undefined, 'female'), false);
});

test('free views count by the chosen window', () => {
  assert.equal(r.windowKey('total', now), 'total');
  assert.equal(r.windowKey('day', now), '2026-11-01');
  assert.equal(r.windowKey('month', now), '2026-11');
  assert.equal(r.DEFAULT_LIMITS.freeProfileLimit, 15);
});

test('views left never goes below zero', () => {
  assert.equal(r.viewsLeft(15, 10), 5);
  assert.equal(r.viewsLeft(15, 15), 0);
  assert.equal(r.viewsLeft(15, 40), 0);
});

test('codes are readable and validated', () => {
  let i = 0;
  const code = r.makeCode(() => (i++ % 10) / 10);
  assert.equal(code.length, 6);
  assert.equal(/[01IO]/.test(code), false);
  assert.equal(r.normalizeCode(' abc234 '), 'ABC234');
  assert.equal(r.normalizeCode('short'), null);
  assert.equal(r.normalizeCode(7), null);
});

test('invite rewards stop at the cap', () => {
  assert.equal(r.inviteReward(0, r.DEFAULT_LIMITS), 2);
  assert.equal(r.inviteReward(9, r.DEFAULT_LIMITS), 1);
  assert.equal(r.inviteReward(10, r.DEFAULT_LIMITS), 0);
});

test('match score rises with shared details and stays bounded', () => {
  const me = { age: 28, location: 'Delhi', country: 'India', sect: 'Sunni', marriageReadiness: 'Ready within 1 year', maritalStatus: 'Never married', partnerCaste: 'Syed' };
  const same = { ...me, caste: 'Syed' };
  assert.equal(r.matchScore({}, {}), 50);
  assert.ok(r.matchScore(me, same) > r.matchScore(me, { age: 45, location: 'London' }));
  assert.ok(r.matchScore(me, same) <= 98);
  assert.ok(r.matchScore(me, { country: 'India' }) >= 58);
});

test('the real type of a file comes from its bytes', () => {
  const b = (...v: number[]) => new Uint8Array(v);
  assert.equal(r.sniffType(b(0xff, 0xd8, 0xff, 0xe0)), 'image/jpeg');
  assert.equal(r.sniffType(b(0x89, 0x50, 0x4e, 0x47)), 'image/png');
  assert.equal(r.sniffType(b(0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50)), 'image/webp');
  assert.equal(r.sniffType(b(0x25, 0x50, 0x44, 0x46)), 'application/pdf');
  assert.equal(r.sniffType(new TextEncoder().encode('<svg></svg>')), null);
  assert.equal(r.sniffType(b()), null);
});

test('stages and document states allow only the right moves', () => {
  assert.ok(r.canSubmit('draft') && r.canSubmit('rejected') && r.canSubmit('changes_requested'));
  assert.ok(!r.canSubmit('approved') && !r.canSubmit('submitted'));
  assert.ok(r.documentAwaitsReview('pending') && r.documentAwaitsReview('under_review'));
  assert.ok(!r.documentAwaitsReview('approved') && !r.documentAwaitsReview(undefined));
  assert.ok(!r.canUploadDocument('approved') && r.canUploadDocument('resubmission_required'));
});

test('eligibility is configurable but never below 18', () => {
  const d = { maritalStatus: 'Divorced', dateOfBirth: Date.UTC(2006, 0, 1) };
  const now = new Date(Date.UTC(2023, 0, 2));
  assert.ok(r.draftProblems(d, { ...r.DEFAULT_LIMITS, minAge: 16 }, now).some((p) => p.includes('at least 18')));
  assert.ok(r.draftProblems(d, { ...r.DEFAULT_LIMITS, firstMarriageOnly: true }, now).some((p) => p.includes('first-time')));
  assert.ok(!r.draftProblems(d, r.DEFAULT_LIMITS, now).some((p) => p.includes('first-time')));
});

test('one visibility rule decides who may be served a card', () => {
  const base = { live: true, activeMatch: false, blocked: false, oppositeGender: true };
  assert.ok(r.canViewProfile(base));
  assert.ok(!r.canViewProfile({ ...base, live: false }));
  assert.ok(r.canViewProfile({ ...base, live: false, activeMatch: true }));
  assert.ok(!r.canViewProfile({ ...base, blocked: true, activeMatch: true }));
  assert.ok(!r.canViewProfile({ ...base, oppositeGender: false }));
});

test('page sizes are bounded and junk is refused', () => {
  assert.equal(r.pageSize(undefined), r.DEFAULT_PAGE);
  assert.equal(r.pageSize(500), r.MAX_PAGE);
  assert.equal(r.pageSize(NaN), null);
  assert.equal(r.pageSize('5'), null);
  assert.equal(r.pageSize(0), null);
});

test('nearby compares cities, never anything finer', () => {
  assert.equal(r.cityOf('Delhi, Delhi'), 'delhi');
  assert.equal(r.cityOf(undefined), '');
});

test('family permissions name only features that exist', () => {
  assert.ok(r.validPermissions(['view_shortlist', 'manage_proposals']));
  assert.ok(!r.validPermissions(['read_chats']));
  assert.ok(!r.validPermissions('view_profile'));
  assert.ok(!r.FAMILY_PERMISSIONS.some((p) => /chat|message|document|contact/.test(p)));
});

test('deletion needs a recent sign-in', () => {
  const now = Date.now();
  assert.ok(r.recentlySignedIn(now - 60000, now));
  assert.ok(!r.recentlySignedIn(now - r.RECENT_SIGN_IN_MS - 1, now));
});

test('photos reach a viewer only as their privacy allows', () => {
  assert.deepEqual(r.visiblePhotos(['a'], 'everyone', false), ['a']);
  assert.deepEqual(r.visiblePhotos(['a'], 'matches', false), []);
  assert.deepEqual(r.visiblePhotos(['a'], 'matches', true), ['a']);
  assert.deepEqual(r.visiblePhotos(undefined, 'everyone', true), []);
});

test('a store record grants only what it says, while it is active', () => {
  const v = { transactionId: 't', productId: 'p', state: 'active' as const, expiresAt: 2000 };
  assert.equal(r.purchaseProblem('p', v, 1000), null);
  assert.ok(r.purchaseProblem('q', v, 1000)?.includes('different product'));
  assert.ok(r.purchaseProblem('p', v, 3000)?.includes('expired'));
  assert.ok(r.purchaseProblem('p', { ...v, state: 'pending' }, 1000)?.includes('not active'));
  assert.ok(r.purchaseProblem('p', { ...v, state: 'refunded' }, 1000)?.includes('not active'));
  assert.ok(r.purchaseProblem('p', null, 1000)?.includes('could not'));
});

test('push preferences never silence account notices', () => {
  assert.ok(r.wantsPush(undefined, 'message'));
  assert.ok(!r.wantsPush({ messages: false }, 'message'));
  assert.ok(r.wantsPush({ messages: false }, 'proposal'));
  assert.ok(r.wantsPush({ messages: false, proposals: false }, 'review'));
});
