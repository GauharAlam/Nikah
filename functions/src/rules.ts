// Decision logic with no Firebase dependency, so every rule is unit-testable.

export type ProposalStatus = 'pending' | 'accepted' | 'declined' | 'withdrawn' | 'expired';

export type ViewWindow = 'total' | 'month' | 'day';

export interface Limits {
  proposalsPerDay: number;
  decisionsPerDay: number;
  pendingLimit: number;
  monthlyContactCredits: number;
  hideDays: number;
  proposalExpiryDays: number;
  minPhotos: number;
  requireIdProof: boolean;
  graduatesOnly: boolean;
  staleDays: number;
  reportHoldThreshold: number;
  contactExpiryDays: number;
  freeProfileLimit: number;
  freeProfileWindow: ViewWindow;
  inviteRewardCredits: number;
  inviteRewardCap: number;
}

// 5 (0/5 PROPOSALS SENT), 10 decisions and 15 waiting are observed in the
// reference app. Credits, hide days and expiry are assumptions; override them
// in config/app.
export const DEFAULT_LIMITS: Limits = {
  proposalsPerDay: 5,
  decisionsPerDay: 10,
  pendingLimit: 15,
  monthlyContactCredits: 30,
  hideDays: 7,
  proposalExpiryDays: 30,
  minPhotos: 1,
  requireIdProof: true,
  graduatesOnly: true,
  staleDays: 45,
  reportHoldThreshold: 3,
  contactExpiryDays: 14,
  freeProfileLimit: 15,
  freeProfileWindow: 'total',
  inviteRewardCredits: 2,
  inviteRewardCap: 10,
};

const TRANSITIONS: Record<ProposalStatus, ProposalStatus[]> = {
  pending: ['accepted', 'declined', 'withdrawn', 'expired'],
  accepted: [],
  declined: [],
  withdrawn: [],
  expired: [],
};

export function canTransition(from: ProposalStatus, to: ProposalStatus): boolean {
  return TRANSITIONS[from].includes(to);
}

/** Only the recipient answers; only the sender withdraws. */
export function actorAllowed(
  actor: string, proposal: { from: string; to: string }, to: ProposalStatus,
): boolean {
  if (to === 'accepted' || to === 'declined') return actor === proposal.to;
  if (to === 'withdrawn') return actor === proposal.from;
  return false;
}

/** Proposals and contact requests only run between a man and a woman. */
export function gendersCompatible(a: unknown, b: unknown): boolean {
  return (a === 'male' && b === 'female') || (a === 'female' && b === 'male');
}

/** Codes avoid look-alike characters, so they survive being read aloud. */
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function makeCode(random: () => number, length = 6): string {
  let out = '';
  for (let i = 0; i < length; i++) out += CODE_ALPHABET[Math.floor(random() * CODE_ALPHABET.length)];
  return out;
}

export function normalizeCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const code = raw.trim().toUpperCase();
  return /^[A-Z0-9]{6}$/.test(code) ? code : null;
}

/** Credits an inviter earns, stopping at the lifetime cap. */
export function inviteReward(earnedSoFar: number | undefined, limits: Limits): number {
  return Math.min(limits.inviteRewardCredits, Math.max(0, limits.inviteRewardCap - (earnedSoFar ?? 0)));
}

export const FAMILY_OPINIONS = ['good', 'discuss', 'no'];

export interface ScoreInput {
  age?: number; country?: string; location?: string; sect?: string; caste?: string;
  marriageReadiness?: string; maritalStatus?: string; partnerCaste?: string;
}

/**
 * A simple, explainable score from shared details. It says how much two
 * profiles have in common, nothing more.
 */
export function matchScore(me: ScoreInput, them: ScoreInput): number {
  let score = 50;
  const city = (s?: string) => (s ?? '').split(',')[0].trim().toLowerCase();
  if (city(me.location) !== '' && city(me.location) === city(them.location)) score += 15;
  else if (me.country && me.country === them.country) score += 8;
  if (me.sect && me.sect === them.sect) score += 10;
  if (me.marriageReadiness && me.marriageReadiness === them.marriageReadiness) score += 10;
  if (me.maritalStatus && me.maritalStatus === them.maritalStatus) score += 5;
  if (me.age !== undefined && them.age !== undefined && Math.abs(me.age - them.age) <= 5) score += 5;
  if (me.partnerCaste && them.caste && me.partnerCaste === them.caste) score += 5;
  return Math.min(score, 98);
}

export const pairId = (a: string, b: string): string => [a, b].sort().join('_');
export const proposalId = (from: string, to: string): string => `${from}_${to}`;

export function dayKey(now: Date): string {
  return now.toISOString().slice(0, 10);
}

export function monthKey(now: Date): string {
  return now.toISOString().slice(0, 7);
}

/** Counter value for [key], treating a stale key as zero. */
export function countFor(storedKey: string | undefined, count: number | undefined, key: string): number {
  return storedKey === key ? count ?? 0 : 0;
}

/** The counting period a free profile view belongs to. */
export function windowKey(window: ViewWindow, now: Date): string {
  if (window === 'day') return dayKey(now);
  if (window === 'month') return monthKey(now);
  return 'total';
}

export function viewsLeft(limit: number, used: number): number {
  return Math.max(0, limit - used);
}

export function ageOn(dobMillis: number, now: Date): number {
  const dob = new Date(dobMillis);
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const before = now.getUTCMonth() < dob.getUTCMonth() ||
    (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate());
  if (before) age--;
  return age;
}

export interface Draft {
  fullName?: string; gender?: string; maritalStatus?: string; marriageReadiness?: string;
  homeCity?: string; homeCountry?: string; dateOfBirth?: number; caste?: string; height?: string;
  phone?: string; almaMaters?: string[]; qualification?: string; qualificationGraduate?: boolean;
  profession?: string; photos?: string[];
  managedBy?: string; intentConfirmed?: boolean; dataConsent?: boolean; candidateConsent?: boolean;
}

/** Returns the problems that stop this draft being submitted. */
export function draftProblems(d: Draft, limits: Limits, now: Date): string[] {
  const out: string[] = [];
  const need = (v: unknown, name: string) => {
    if (v === undefined || v === null || v === '') out.push(`${name} is required`);
  };
  need(d.fullName, 'Full name');
  if (d.gender !== 'male' && d.gender !== 'female') out.push('Gender is required');
  need(d.maritalStatus, 'Marital status');
  need(d.marriageReadiness, 'Marriage readiness');
  need(d.homeCity, 'Home city');
  need(d.height, 'Height');
  need(d.phone, 'Contact number');
  need(d.qualification, 'Education');
  need(d.profession, 'Profession');
  if (!d.almaMaters || d.almaMaters.length === 0) out.push('Alma mater is required');
  if (typeof d.dateOfBirth !== 'number') out.push('Date of birth is required');
  else if (ageOn(d.dateOfBirth, now) < 18) out.push('You must be at least 18');
  if (limits.graduatesOnly && d.qualificationGraduate === false) {
    out.push('This community is for graduates and degree students');
  }
  if ((d.photos?.length ?? 0) < limits.minPhotos) out.push('Add at least one photo');
  if (d.intentConfirmed !== true) out.push('Confirm that you are here for marriage');
  if (d.dataConsent !== true) out.push('Agree to how your details are used');
  if (d.managedBy === 'family' && d.candidateConsent !== true) {
    out.push('Confirm that the person has agreed to this profile');
  }
  return out;
}

export interface Filters {
  minAge?: number; maxAge?: number; maritalStatus?: string; caste?: string; almaMater?: string;
  education?: string; profession?: string; location?: string; sect?: string;
}
export const ANY = 'No preference';
export const PREMIUM_FILTERS: (keyof Filters)[] = ['education', 'profession', 'location'];

/** Premium-gated filters are dropped server-side for free members. */
export function allowedFilters(f: Filters, premium: boolean): Filters {
  if (premium) return f;
  const copy = { ...f };
  for (const key of PREMIUM_FILTERS) delete copy[key];
  return copy;
}

export interface Card {
  age: number; maritalStatus: string; caste: string; university: string;
  education: string; profession: string; location: string; sect?: string;
}

export function matchesFilters(c: Card, f: Filters): boolean {
  const on = (v?: string) => v !== undefined && v !== '' && v !== ANY;
  if (f.minAge !== undefined && c.age < f.minAge) return false;
  if (f.maxAge !== undefined && c.age > f.maxAge) return false;
  if (on(f.maritalStatus) && c.maritalStatus !== f.maritalStatus) return false;
  if (on(f.caste) && c.caste !== f.caste) return false;
  if (on(f.almaMater) && !c.university.includes(f.almaMater!)) return false;
  if (on(f.education) && c.education !== f.education) return false;
  if (on(f.sect) && c.sect !== f.sect) return false;
  if (on(f.profession) && c.profession !== f.profession) return false;
  if (on(f.location) && !c.location.toLowerCase().includes(f.location!.toLowerCase())) return false;
  return true;
}

export interface Hidden {
  blocked: boolean; hiddenUntil?: number; hasProposal: boolean; matched: boolean;
  lastActiveAt?: number; staleDays?: number;
}

export function visibleInDiscovery(h: Hidden, nowMillis: number): boolean {
  if (h.blocked || h.hasProposal || h.matched) return false;
  if (h.lastActiveAt !== undefined && h.staleDays !== undefined &&
      nowMillis - h.lastActiveAt > h.staleDays * 86400000) return false;
  return !(h.hiddenUntil !== undefined && h.hiddenUntil > nowMillis);
}

export const REPORT_REASON_MAX = 200;

export type PhotoPrivacy = 'everyone' | 'matches';

/** What a viewer may see of a stored card. Applied before any card leaves the server. */
export function redactCard<T extends { photos?: string[]; caste?: string; photoPrivacy?: string; showCaste?: boolean }>(
  card: T, viewerMatched: boolean,
): T & { photosHidden: boolean } {
  const hide = card.photoPrivacy === 'matches' && !viewerMatched;
  const { photoPrivacy, showCaste, ...rest } = card;
  return {
    ...(rest as T), photos: hide ? [] : card.photos ?? [], photosHidden: hide,
    caste: showCaste === false ? '' : card.caste ?? '',
  };
}

/** Credits come back only in the month they were spent. */
export function creditsAfterRefund(storedMonth: string | undefined, spent: number | undefined, spentMonth: string | undefined): number {
  const current = spent ?? 0;
  if (storedMonth === undefined || storedMonth !== spentMonth) return current;
  return Math.max(0, current - 1);
}

export function shouldHold(distinctReporters: number, limits: Limits): boolean {
  return distinctReporters >= limits.reportHoldThreshold;
}

export const JOURNEY_STEPS = ['talking', 'questions', 'families', 'istikhara', 'decision'] as const;
export const isJourneyStep = (v: unknown): boolean => JOURNEY_STEPS.includes(v as (typeof JOURNEY_STEPS)[number]);
