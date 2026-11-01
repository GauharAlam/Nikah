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
  minAge: number;
  firstMarriageOnly: boolean;
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
  minAge: 18,
  firstMarriageOnly: false,
};

/** Version of the terms and privacy policy a member accepts. Overridden by config/app. */
export const POLICY_VERSION = '2026-11-01';

export const CONSENTS: Record<string, string> = {
  data_processing: 'Use of profile details, photos and documents for review and matching',
  marriage_intent: 'Confirmation that this profile is for marriage and is accurate',
  family_authorised: 'Confirmation by a family member that the person agreed to this profile',
};

/** A profile can be sent for review from these stages. */
export const canSubmit = (stage: string): boolean =>
  ['draft', 'rejected', 'changes_requested'].includes(stage);

export type ReviewDecision = 'approve' | 'changes' | 'reject';
export const isReviewDecision = (v: unknown): v is ReviewDecision =>
  v === 'approve' || v === 'changes' || v === 'reject';

export const DOC_TYPES = ['name-proof', 'education-proof', 'employment-proof'];
export type DocDecision = 'approve' | 'reject' | 'resubmit';
export const DOC_OUTCOME: Record<DocDecision, string> = {
  approve: 'approved', reject: 'rejected', resubmit: 'resubmission_required',
};

/** Only a document waiting for a decision can receive one. */
export const documentAwaitsReview = (status: unknown): boolean =>
  status === 'pending' || status === 'under_review';

/** An approved document stays approved until a reviewer says otherwise. */
export const canUploadDocument = (status: unknown): boolean => status !== 'approved';

export const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
export const DOCUMENT_TYPES = [...PHOTO_TYPES, 'application/pdf'];
export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

/** The real type of a file from its first bytes. Client-declared types prove nothing. */
export function sniffType(b: Uint8Array): string | null {
  const at = (i: number, ...v: number[]) => v.every((x, j) => b[i + j] === x);
  if (at(0, 0xff, 0xd8, 0xff)) return 'image/jpeg';
  if (at(0, 0x89, 0x50, 0x4e, 0x47)) return 'image/png';
  if (at(0, 0x52, 0x49, 0x46, 0x46) && at(8, 0x57, 0x45, 0x42, 0x50)) return 'image/webp';
  if (at(0, 0x25, 0x50, 0x44, 0x46)) return 'application/pdf';
  return null;
}

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
  almaMaters?: string[]; qualification?: string; qualificationGraduate?: boolean;
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
  need(d.qualification, 'Education');
  need(d.profession, 'Profession');
  if (!d.almaMaters || d.almaMaters.length === 0) out.push('Alma mater is required');
  if (typeof d.dateOfBirth !== 'number') out.push('Date of birth is required');
  else if (ageOn(d.dateOfBirth, now) < Math.max(18, limits.minAge)) {
    out.push(`You must be at least ${Math.max(18, limits.minAge)}`);
  }
  if (limits.firstMarriageOnly && d.maritalStatus !== undefined && d.maritalStatus !== 'Never married') {
    out.push('This community is for first-time marriages');
  }
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
  country?: string; query?: string;
}
export const ANY = 'No preference';
export const PREMIUM_FILTERS: (keyof Filters)[] = ['education', 'profession', 'location', 'country'];

/** Premium-gated filters are dropped server-side for free members. */
export function allowedFilters(f: Filters, premium: boolean): Filters {
  if (premium) return f;
  const copy = { ...f };
  for (const key of PREMIUM_FILTERS) delete copy[key];
  return copy;
}

export interface Card {
  age: number; maritalStatus: string; caste: string; university: string;
  education: string; profession: string; location: string; sect?: string; country?: string;
}

/** The first part of a location, which is the coarsest thing nearby ever compares. */
export const cityOf = (location?: string): string => (location ?? '').split(',')[0].trim().toLowerCase();

export const DEFAULT_PAGE = 10;
export const MAX_PAGE = 20;

/** A page size, or null when the value is not one. */
export function pageSize(raw: unknown): number | null {
  if (raw === undefined || raw === null) return DEFAULT_PAGE;
  if (typeof raw !== 'number' || !Number.isInteger(raw) || raw < 1) return null;
  return Math.min(raw, MAX_PAGE);
}

/** The single rule for who may be served a stored card. */
export function canViewProfile(v: {
  live: boolean; activeMatch: boolean; blocked: boolean; oppositeGender: boolean;
}): boolean {
  if (v.blocked || !v.oppositeGender) return false;
  return v.live || v.activeMatch;
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
  if (on(f.country) && c.country !== f.country) return false;
  if (on(f.query)) {
    const text = [c.university, c.profession, c.education, c.location].join(' ').toLowerCase();
    if (!text.includes(f.query!.trim().toLowerCase())) return false;
  }
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
export function redactCard<T extends {
  photos?: string[]; caste?: string; photoPrivacy?: string; showCaste?: boolean; photoPaths?: string[];
  family?: Record<string, unknown>; name?: string; employer?: string;
}>(
  card: T, viewerMatched: boolean,
): T & { photosHidden: boolean } {
  const hide = card.photoPrivacy === 'matches' && !viewerMatched;
  const { photoPrivacy, showCaste, photoPaths, family, employer, ...rest } = card;
  return {
    ...(rest as T), photos: hide ? [] : card.photos ?? [], photosHidden: hide,
    caste: showCaste === false ? '' : card.caste ?? '',
    // Full name, employer and family details are for matched members only.
    name: viewerMatched ? card.name : String(card.name ?? '').split(' ')[0],
    ...(viewerMatched ? { family, employer: employer ?? '' } : {}),
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
