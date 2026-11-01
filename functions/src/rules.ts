// Decision logic with no Firebase dependency, so every rule is unit-testable.

export type ProposalStatus = 'pending' | 'accepted' | 'declined' | 'withdrawn' | 'expired';

export interface Limits {
  proposalsPerDay: number;
  decisionsPerDay: number;
  pendingLimit: number;
  monthlyContactCredits: number;
  hideDays: number;
  proposalExpiryDays: number;
  minPhotos: number;
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
  need(d.caste, 'Caste');
  need(d.height, 'Height');
  need(d.phone, 'Contact number');
  need(d.qualification, 'Education');
  need(d.profession, 'Profession');
  if (!d.almaMaters || d.almaMaters.length === 0) out.push('Alma mater is required');
  if (typeof d.dateOfBirth !== 'number') out.push('Date of birth is required');
  else if (ageOn(d.dateOfBirth, now) < 18) out.push('You must be at least 18');
  if (d.qualificationGraduate === false) out.push('This community is for graduates and degree students');
  if ((d.photos?.length ?? 0) < limits.minPhotos) out.push('Add at least one photo');
  return out;
}

export interface Filters {
  minAge?: number; maxAge?: number; maritalStatus?: string; caste?: string; almaMater?: string;
  education?: string; profession?: string; location?: string;
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
  education: string; profession: string; location: string;
}

export function matchesFilters(c: Card, f: Filters): boolean {
  const on = (v?: string) => v !== undefined && v !== '' && v !== ANY;
  if (f.minAge !== undefined && c.age < f.minAge) return false;
  if (f.maxAge !== undefined && c.age > f.maxAge) return false;
  if (on(f.maritalStatus) && c.maritalStatus !== f.maritalStatus) return false;
  if (on(f.caste) && c.caste !== f.caste) return false;
  if (on(f.almaMater) && !c.university.includes(f.almaMater!)) return false;
  if (on(f.education) && c.education !== f.education) return false;
  if (on(f.profession) && c.profession !== f.profession) return false;
  if (on(f.location) && !c.location.toLowerCase().includes(f.location!.toLowerCase())) return false;
  return true;
}

export interface Hidden { blocked: boolean; hiddenUntil?: number; hasProposal: boolean; matched: boolean }

export function visibleInDiscovery(h: Hidden, nowMillis: number): boolean {
  if (h.blocked || h.hasProposal || h.matched) return false;
  return !(h.hiddenUntil !== undefined && h.hiddenUntil > nowMillis);
}

export const REPORT_REASON_MAX = 200;
