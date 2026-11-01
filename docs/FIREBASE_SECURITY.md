# Firebase Security

The rules are `firebase/firestore.rules` and `firebase/storage.rules`. Both deny by default.
Rules are the security boundary; route guards exist only for navigation.

## Data classes

| Class | Examples | Who can reach it | How |
|---|---|---|---|
| Public profile | First name, age, education, city, profession, verified flag | Approved members allowed by `canViewProfile` | `fetchIntroductions`, `getProfiles` |
| Matched-user | Full name, employer, family details | Active matches | `redactCard` |
| Private personal | Draft, date of birth, verified phone, settings | Owner | Rules |
| Family-only | Shortlist summaries, memberships | Owner, and guardians by permission | Rules, callables |
| Verification documents | ID, degree files | Reviewers only | Five-minute signed URLs, each one logged |
| Administrative | Audit log, reports, review notes | Console or reviewer callables | No client rule |

Profiles cannot be read directly, so nothing can be scraped from Firestore. Every card leaves
the server through `toPublicCard`, and a test lists the fields that must not appear.

## Photos

| Path | Reader | Writer |
|---|---|---|
| `photos/{uid}/*` | Owner | Owner: create and delete only, never replace |
| `published/{uid}/*` | Nobody directly | Server only |

Approval copies reviewed bytes to `published/`. Each viewer then receives one-hour signed links
only for photos they may see. Turning on "photos after match" stops new links at once; a link
already issued works until it expires, at most an hour later.

**Deployment requirement:** the Functions service account needs the Service Account Token
Creator role, or signed URLs fail. This path cannot run on the emulator.

## Roles

`reviewer` and `approved` are custom claims set only by trusted code. Reviewer access comes from
`functions/scripts/grant-reviewer.ts`, run from a trusted machine. Nothing in the client can set
a claim. Reviewers cannot act on their own profile or documents.

## Test matrix

| Actor | Covered by |
|---|---|
| Anonymous | `rules.emulator.test.ts`: nobody can read while signed out |
| Normal and unapproved user | `flow`, `rules`: cannot act on anyone, or grant themselves anything |
| Approved user | `flow`, `connections`: discovery, proposals, contact |
| Profile owner | `rules`, `account`: own draft, export, pause |
| Invited guardian | `family`, `rules`: only granted permissions |
| Revoked guardian | `family`, `rules`: loses access on the next request |
| Unrelated user | `rules`: accounts, drafts, matches, shares and photos closed |
| Reviewer | `review`: decides, but never on themselves |
| Unauthorised admin impersonation | `flow`: a member cannot approve anything |
| Blocked user | `connections`, `flow`: proposals, contact and messages stop both ways |
| Matched and non-matched user | `rules`, `connections`: messages and full details |

## Retention

These are engineering defaults, and need legal review (blocker X-4).

| Data | On account deletion |
|---|---|
| Profile, draft, submission, account, consents, notifications, devices | Deleted |
| Photos and verification files | Deleted |
| Proposals, contact requests, shares | Deleted |
| Conversations | Deleted for both sides. Neither person can open a conversation after a match ends |
| Family circle, memberships, history, invitations, shared summaries | Deleted |
| Blocks and hidden records pointing at the member | Deleted |
| Reports made by the member | Reporter removed; report stays for safety review |
| Reports about the member | Kept for safety review |
| Purchases and credit ledger | Kept for payment law, with the uid replaced by a hash |
| Audit log | Kept, with ids only |
| `deletionRequests/{uid}` | Status and timestamps only |

## Deletion job

`requestAccountDeletion` needs a sign-in within ten minutes. It records the request, removes
claims and revokes refresh tokens at once, then runs named steps, recording each. Every step is
safe to repeat. A failure is resumed by the hourly `retryDeletions`, or by a reviewer through
`resumeDeletion`, starting from the first unfinished step.
