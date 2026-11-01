# Security and Privacy Audit

**Audited:** 2026-11-01, commit `a202624`. Each finding was read in the code at that commit.
Every finding below has been addressed since; `IMPLEMENTATION_PROGRESS.md` records each fix and
what was verified. This file is kept as the record of what was found.

## What already holds

- Accounts, profiles, proposals, matches, contact shares, reports and blocks cannot be
  written by a client, and the rules tests prove it.
- Profiles cannot be read directly, so discovery cannot be scraped from Firestore.
- Reviewer and approved status come from custom claims, set only by trusted code.
- Verification documents cannot be read through Storage by anyone; reviewers get
  five-minute signed URLs.
- Push payloads are generic, and names and message text never reach the lock screen.
- No secrets exist in git history or tracked files.

---

## Critical

### SEC-01 · Any approved member can read every photo — Critical
- **Existing:** `storage.rules` grants `read` on `photos/{uid}/{file}` to anyone with the
  `approved` claim. `read` includes `list`, so a member can enumerate a person's photos.
  This bypasses "show photos only after we match" and exposes photos no reviewer has
  checked. Published cards also hold permanent download-token URLs.
- **Expected:** photo visibility is enforced by the server for each viewer. A privacy
  toggle changes what can be fetched, not just what is displayed.
- **Files:** `firebase/storage.rules`, `functions/src/index.ts` (`reviewProfile`,
  `cardFrom`, `toPublicCard`), `lib/data/firebase_backend.dart`.
- **Solution:** photos are readable only by their owner. On approval the server copies each
  reviewed photo to `published/{uid}/{id}.jpg`, which no client can read. Cards carry photo
  ids, and the server issues short-lived signed URLs per viewer after checking visibility.
- **Acceptance:** an approved stranger cannot read or list another member's photos. A
  matches-only photo URL is issued only to a matched viewer.
- **Tests:** Storage rules tests for owner, stranger and approved stranger; flow test for
  signed URL issue and refusal.

### SEC-02 · Moderation can be bypassed by overwriting a photo — Critical
- **Existing:** `allow write` on `photos/{uid}/{file}` lets the owner replace the object at
  a path that was already approved. The reviewed path then serves unreviewed content.
- **Expected:** what was reviewed is what is published.
- **Files:** `firebase/storage.rules`, `functions/src/index.ts`.
- **Solution:** publishing copies bytes to the server-only `published/` prefix, and rules
  make `photos/` create-only (no update).
- **Acceptance:** overwriting an existing path fails; a later upload cannot change a
  published photo.
- **Tests:** Storage rules test; flow test comparing published bytes after an overwrite
  attempt.

### SEC-03 · A reviewer can approve themselves — Critical
- **Existing:** `reviewProfile` and `reviewDocument` check the reviewer claim but not
  `uid !== reviewer`. Neither checks that a submission exists, so a draft-stage account can
  be approved. `reviewDocument` accepts any `type`.
- **Expected:** nobody approves their own profile or document; decisions apply only to
  items actually waiting.
- **Files:** `functions/src/index.ts`.
- **Solution:** refuse self-review, require stage `submitted` or a pending edit, and check
  document type and state.
- **Acceptance:** each illegal decision fails with `permission-denied` or
  `failed-precondition`.
- **Tests:** flow tests for each case.

### SEC-04 · Approval publishes data the reviewer never saw — Critical
- **Existing:** `reviewProfile` reads the live draft, which the member can change at any
  time. A member can submit a valid draft, then change name, photos or date of birth
  before the reviewer taps Approve. Eligibility is not rechecked at approval, so an
  under-18 date of birth can be published.
- **Expected:** approval publishes exactly the reviewed snapshot.
- **Files:** `functions/src/index.ts`, `firebase/firestore.rules`.
- **Solution:** `submitProfile` and `submitEdits` validate and copy the draft to the
  server-only `submissions/{uid}` with a version. The queue shows that snapshot, and the
  reviewer's decision carries the version it saw.
- **Acceptance:** a draft edit after submission does not reach the published card, and a
  decision on a stale version fails.
- **Tests:** flow tests for both.

### SEC-05 · Blocking does not stop a contact exchange — Critical
- **Existing:** `blockProfile` closes proposals but not `contactRequests`. `respondContact`
  has no block check. After A blocks B, A's pending request can still be accepted, which
  shares both phone numbers and opens a match.
- **Expected:** blocking stops contact in both directions.
- **Files:** `functions/src/index.ts`.
- **Solution:** close pending contact requests on block with a refund, and check blocks
  inside the `respondContact` transaction.
- **Acceptance:** after a block in either direction, `respondContact` fails and no share
  document exists.
- **Tests:** flow test for both directions.

### SEC-06 · Shared phone numbers are unverified — Critical
- **Existing:** `reviewProfile` copies `draft.phone`, which the client writes, into
  `accounts.phone`, and that is what a contact exchange reveals. A member can share
  someone else's number. Google accounts have no verified phone at all.
- **Expected:** the shared number is the one proved by SMS.
- **Files:** `functions/src/index.ts`, `lib/screens/onboarding/onboarding_screen.dart`,
  `lib/data/firebase_backend.dart`.
- **Solution:** `submitProfile` requires a verified phone on the token, stored from the
  token only. Google users link a phone through OTP before submitting.
- **Acceptance:** submission without a verified phone fails, and a draft phone never
  reaches a share.
- **Tests:** flow tests.

---

## High

### SEC-07 · Purchases can be forged or fail — High
- **Existing:** four defects. (1) `subscriptionsv2.get` is not bound to `productId`, so a
  weekly token claimed as monthly grants 30 days. (2) Apple validation ignores expiry, so
  an expired receipt grants a fresh period. (3) The receipt key is the first 200 characters
  of an encoded receipt, and Apple receipts share a long common prefix, so different
  purchases collide. (4) The client never sends `packageName`, so every Android validation
  fails with `invalid-argument`.
- **Expected:** a store-verified transaction grants its real entitlement once, and expires
  with the store's date.
- **Files:** `functions/src/index.ts`, `lib/services/purchase_service.dart`.
- **Solution:** key on the SHA-256 of the store transaction id, read the expiry from the
  store, bind product ids, take the package name from server config, add a credit ledger
  and RTDN and App Store notification handlers.
- **Acceptance:** Journey 8 grants exactly once; mismatched products and expired receipts
  are refused.
- **Tests:** unit tests with fake store verifiers; flow tests for idempotency.

### SEC-08 · Account deletion is incomplete and not retryable — High
- **Existing:** no recent sign-in check and no request record. Sequential deletes mean a
  failure midway leaves a half-deleted account. Family links, invite codes and claims,
  reports, blocks pointing at the member, shortlist cards in other families and
  denormalised data all remain. `recursiveDelete` removes the other member's conversation
  with no documented policy.
- **Expected:** an idempotent, paged, retryable job with a documented retention policy.
- **Files:** `functions/src/index.ts`, `lib/screens/settings_screen.dart`.
- **Solution:** `requestAccountDeletion` checks `auth_time`, records a request, revokes
  tokens and hides the profile at once; a worker processes each step in pages and can
  resume.
- **Acceptance:** Journey 7 leaves no personal data outside the documented retention list.
- **Tests:** flow test seeds every related record, asserts each is gone, and reruns after
  a simulated failure.

### SEC-09 · Reports can be abused and go nowhere — High
- **Existing:** any signed-in account can report, including unapproved ones, so three fresh
  phone numbers can hold any profile. Re-reporting resets a resolved report to `open`. The
  `held` list is returned by `listReviewQueue` but dropped by `FirebaseBackend`, and no
  function resolves a report or releases a hold.
- **Expected:** only approved members report; reports reach a reviewer who can close them.
- **Files:** `functions/src/index.ts`, `lib/data/firebase_backend.dart`,
  `lib/screens/review_queue_screen.dart`.
- **Solution:** require approval, make re-reports no-ops while one exists, add
  `listReports` and `resolveReport`, and record outcomes in the audit log.
- **Acceptance:** an unapproved account cannot affect a profile. A reviewer can dismiss a
  report and release the hold.
- **Tests:** flow tests.

### SEC-10 · Hidden profiles are still served — High
- **Existing:** `getProfiles` does not check `live`, so a held or rejected profile stays
  readable by anyone who has seen it, and any premium member can fetch any live profile by
  uid. Empty `me` skips the gender check.
- **Expected:** the same visibility decision everywhere.
- **Files:** `functions/src/index.ts`, `functions/src/rules.ts`.
- **Solution:** one `canViewProfile` rule used by all reads. Active matches keep a
  minimal view; everyone else needs `live`.
- **Acceptance:** a held profile is unavailable to non-matches.
- **Tests:** logic and flow tests.

### SEC-11 · Family access has no permission model — High
- **Existing:** six-character code, no relationship, no permissions, no audit history, no
  phone check. `familyOf` holds a single value, so joining a second circle overwrites the
  first, and removal from one clears the other. `joinFamily` has no attempt limit.
- **Expected:** granular, revocable permissions enforced on every operation.
- **Files:** `functions/src/index.ts`, `firebase/firestore.rules`, `lib/screens/family_circle_screen.dart`.
- **Solution:** the model in `FAMILY_ACCESS_MODEL.md`: invitations bound to a phone number,
  memberships with explicit permissions, an append-only history, and attempt limits.
- **Acceptance:** Journey 4 passes; a revoked guardian loses access at once.
- **Tests:** the permission matrix, including every denial.

### SEC-12 · No audit trail for privileged actions — High
- **Existing:** `reviewedBy` is overwritten on each decision, and `getDocumentUrl`, which
  exposes identity documents, leaves no record.
- **Expected:** an append-only record of who did what and when.
- **Files:** `functions/src/index.ts`, `firebase/firestore.rules`.
- **Solution:** `auditLogs` written only by the server, for every review, document view and
  report decision. Holds ids and action types, never document contents.
- **Acceptance:** each privileged call writes exactly one entry, and no client can read
  or write them.
- **Tests:** flow and rules tests.

### SEC-13 · Conversations stay open after trust is withdrawn — High
- **Existing:** messages stay readable after a block or closure, and rules check only the
  match status, so a held or rejected member can keep messaging.
- **Expected:** reads and writes need an active match; a held member cannot message.
- **Files:** `firebase/firestore.rules`, `functions/src/index.ts`.
- **Solution:** messages require `status == 'active'` and the `approved` claim. Holding a
  profile revokes the claim and pauses its matches.
- **Acceptance:** rules tests prove blocked, closed and held members lose access.
- **Tests:** rules tests.

---

## Medium

### SEC-14 · Draft contents are barely validated — Medium
- **Existing:** rules use a deny-list and a key count. Field sizes and `photos` paths are
  unchecked until a reviewer sees them, and `devices` accepts anything.
- **Expected:** an allow-list of fields with sizes.
- **Files:** `firebase/firestore.rules`, `functions/src/rules.ts`.
- **Solution:** allow-list in rules; a full server validator at submission.
- **Acceptance:** unknown or oversized fields fail.
- **Tests:** rules tests.

### SEC-15 · Upload types are too broad — Medium
- **Existing:** `image/.*` allows SVG, and content type is declared by the client.
- **Expected:** only JPEG, PNG, WebP and PDF, checked by magic bytes on the server.
- **Files:** `firebase/storage.rules`, `functions/src/index.ts`.
- **Solution:** an explicit list in rules; `onObjectFinalized` validation deletes objects
  whose bytes do not match.
- **Acceptance:** SVG fails; a mislabelled file is removed.
- **Tests:** rules test; logic test of the sniffer.

### SEC-16 · No rate limiting on abusable endpoints — Medium
- **Existing:** `joinFamily`, `createFamilyInvite`, `sendMessage`, `submitProfile` and
  `reportProfile` have no limits. App Check is not enforced.
- **Expected:** per-account limits; App Check in production.
- **Files:** `functions/src/*`, `lib/main.dart`.
- **Solution:** a shared transactional limiter, and App Check enforcement behind a config
  flag.
- **Acceptance:** the limit returns `resource-exhausted`.
- **Tests:** flow test.

### SEC-17 · Consent is a set of client booleans — Medium
- **Existing:** `intentConfirmed`, `dataConsent` and `candidateConsent` are draft fields,
  with no policy version, timestamp or revocation. A family member ticks a box for the
  subject, and the subject never confirms.
- **Expected:** consent records as the brief defines, and subject consent for
  family-managed profiles.
- **Files:** `functions/src/*`, `firebase/firestore.rules`, onboarding.
- **Solution:** `accounts/{uid}/consents/{category}` written by the server; a subject
  confirmation step before a family-managed profile can go live.
- **Acceptance:** a family-managed profile cannot be approved without the subject's
  recorded confirmation.
- **Tests:** flow tests.

### SEC-18 · Verification states and wording are too strong — Medium
- **Existing:** four states, and the badge says "Verified by the Barkat team" with no note
  about what it means.
- **Expected:** the six states in the brief, and wording that a badge means evidence was
  reviewed.
- **Files:** `lib/models/verification_doc.dart`, `functions/src/*`, screens.
- **Solution:** extend states; correct copy.
- **Acceptance:** no string implies a background check or a guarantee.
- **Tests:** widget test for each state.

### SEC-19 · Notification preferences do not exist — Medium
- **Existing:** every event pushes, and the demo-only toggles do nothing in production. A
  device token stays on the old account if sign-out fails.
- **Expected:** server-enforced preferences by category; tokens move with the account.
- **Files:** `functions/src/*`, `lib/data/firebase_backend.dart`.
- **Solution:** `accounts/{uid}/settings/notifications`, read by `sendPush`.
- **Acceptance:** a turned-off category sends no push; the in-app record stays.
- **Tests:** logic test.

### SEC-20 · Public card holds more than discovery needs — Medium
- **Existing:** full legal name and employer go to every viewer. There is no data
  classification.
- **Expected:** the six classes in the brief, with a DTO per viewing context.
- **Files:** `functions/src/index.ts`, `functions/src/rules.ts`.
- **Solution:** `toPublicCard` returns first name and removes employer unless matched;
  document classes in `FIREBASE_SECURITY.md`.
- **Acceptance:** discovery responses contain only public-class fields.
- **Tests:** flow test listing the exact allowed keys.

### SEC-21 · Expiry can overwrite an answered proposal — Medium
- **Existing:** `expireProposals` batches outside a transaction, so an accept between the
  query and the commit is overwritten, leaving an expired proposal with a live match. Only
  400 are handled per day.
- **Expected:** expiry never overrides an answer, and backlogs drain.
- **Files:** `functions/src/index.ts`.
- **Solution:** per-document transactions in a loop until a page comes back short.
- **Acceptance:** a racing accept stays accepted.
- **Tests:** flow test.

### SEC-22 · Device protections incomplete — Medium
- **Existing:** `FLAG_SECURE` is on for the whole app. The iOS handler has never compiled,
  and there is no app lock.
- **Expected:** screenshot protection on sensitive screens where supported, honest copy
  about limits, and an optional app lock.
- **Files:** `lib/services/privacy_shield.dart`, `ios/Runner/AppDelegate.swift`, settings.
- **Solution:** `local_auth` lock option; iOS remains unverified until Xcode exists.
- **Acceptance:** the setting survives restart; the lock appears on resume.
- **Tests:** unit test of lock state.

### SEC-23 · The product uses another company's brand — Medium
- **Existing:** "Barkat Nikah" in the app name, `com.barkat.nikah.*` ids, `barkat_*`
  product ids, and "Barkat Verified" strings. The brief says the product is Nikah and that
  Barkat's branding must not be copied.
- **Expected:** no reference app branding.
- **Files:** `lib/config/app_config.dart`, 17 screen and widget files, platform configs,
  `functions/src`.
- **Solution:** rename to Nikah and change ids while no store listing exists.
- **Acceptance:** a case-insensitive search finds no "barkat" in shipped code.
- **Tests:** a test that fails if the string returns.

### SEC-24 · No data export — Medium
- **Existing:** none.
- **Expected:** a member can export their data.
- **Files:** new.
- **Solution:** `exportMyData` callable returns a JSON document of the member's own records.
- **Acceptance:** includes the member's data and never another member's private fields.
- **Tests:** flow test.

### SEC-25 · Repeat contact requests after a decline — Medium
- **Existing:** `requestContact` overwrites a declined request, so a member can ask again
  after every refusal.
- **Expected:** a decline is respected.
- **Files:** `functions/src/index.ts`.
- **Solution:** a declined request stays declined, like a proposal.
- **Acceptance:** a repeat fails without a charge.
- **Tests:** flow test.

---

## Low

### SEC-26 · Input edge cases — Low
- **Existing:** `updatePrivacy` with no fields calls `update({})`, which surfaces as an
  internal error. A member can block or report themselves. `limit: NaN` bypasses the
  discovery page size.
- **Expected:** rejected as invalid input.
- **Files:** `functions/src/index.ts`.
- **Solution:** validate each.
- **Acceptance:** `invalid-argument`.
- **Tests:** flow tests.
