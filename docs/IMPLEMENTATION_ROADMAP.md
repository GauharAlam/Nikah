# Implementation Roadmap

Supersedes `IMPLEMENTATION_PLAN.md`, which predates the Firebase work. Findings are in
`ARCHITECTURE_AUDIT.md`, `PRODUCT_FLOW_AUDIT.md` and `SECURITY_PRIVACY_AUDIT.md`. Results of
each phase are in `IMPLEMENTATION_PROGRESS.md`.

**Rule for every phase:** analyzer clean, all tests pass, progress updated, then commit and
push to `feature/trust-and-nikah-journey`.

| Phase | Scope | Findings |
|---|---|---|
| 0 | Baseline | done |
| 1 | Audit, architecture, schema | this document set |
| 2 | Architecture refactor | ARC-01, 02, 03, 04, 06, 08, 09, 10 |
| 3 | Authentication and onboarding, review | SEC-03, 04, 06, 14, 15, 17, 18; FLOW-01 to 06, 16 |
| 4 | Discovery, proposals, matches, chat | SEC-05, 10, 13, 20, 21, 25; ARC-05, 07; FLOW-07 to 11 |
| 5 | Family and privacy, deletion | SEC-01, 02, 08, 11, 22, 24; FLOW-12, 13, 19 |
| 6 | Trust and safety | SEC-09, 12, 16, 26; FLOW-14, 17 |
| 7 | Notifications and premium | SEC-07, 19; FLOW-18 |
| 8 | QA | journeys 1 to 8, integration tests on Android, FLOW-15 |
| 9 | Release | SEC-23, ARC-11, signing, privacy disclosures, deployment guide |

SEC-01 and SEC-02 sit in Phase 5 with photos and privacy, as the brief orders it. Their
Storage rule change ships earlier, in Phase 3, because uploads are rebuilt there.

## External blockers

Nothing here can be finished from this machine. Each has the correct code path and is
documented, but stays unverified until the item arrives.

| Id | Needed | Blocks |
|---|---|---|
| X-1 | Firebase project and config files | real SMS, real push, signed URLs on real Storage, any production run |
| X-3 | Google Play account with products | real purchases, notifications |
| X-4 | Legal review of terms, privacy policy and retention periods | release |
| X-5 | Final store listing identity | store release |
| X-6 | Real institution dataset and product decisions on quotas | launch content |

## Key decisions

| # | Decision | Why |
|---|---|---|
| D-1 | Keep Firebase and Provider | The brief's default, and nothing in the audit justifies a migration |
| D-2 | The local simulation moves to a debug-only `DemoAppStore` | One production code path, and the user has no Firebase project yet, so a preview is still needed |
| D-3 | Wali portal, chaperone chat and meeting scheduler stay, gated to demo builds | The user's earlier decision (D2 in `docs/history/PROGRESS_TO_2026-11-01.md`) keeps them as a superset. They stay out of production through `AppConfig.guardianFeatures`. Family Circle is the real feature and grows into the family hub |
| D-4 | Contact acceptance may open a match | Both people have acted, so it is not one-sided. Consent is recorded, and blocks apply |
| D-5 | Photos stay server-mediated by signed URL | The only way to enforce per-viewer privacy on Storage |
| D-6 | `AppStore` stays as a thin facade during migration | 35 files depend on it; moving them all at once adds risk with no user benefit |
| D-7 | App id becomes `com.gauharalam.nikah` | Removes the reference brand from the id while no store listing exists. Reversible until first publish (X-5) |

## Out of scope for now

- iOS. The first release is Android only. iOS code stays in the repo, uncompiled, and Apple
  billing is switched off on the server.
- Payment rails other than Apple and Google.
- Automated image moderation. Human review stands, and a hook is left at photo publish.
- Web and desktop builds. The platform folders stay, but only Android and iOS are targets.
