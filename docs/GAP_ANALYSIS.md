# Gap Analysis — Nikah_App vs Barkat

> **Corrected 2026-10-31.** The first version of this document was written without
> looking at Barkat's store screenshots. They were later downloaded and compared with
> the running app, and they contradict several findings here. See
> `REFERENCE_ANALYSIS.md` §0 for what changed. Where that section and this document
> disagree, §0 is correct.

**Date:** 2026-10-26
**Inputs:** `CODEBASE_AUDIT.md` (commit `00a9180`) · `REFERENCE_ANALYSIS.md`
**Classification:** Complete · Partial · Broken · Missing · Unverified
**Priority:** P0 blocks a core journey or is a security/integrity defect · P1 core product
gap · P2 quality/completeness · P3 polish

> **Status note (2026-10-27):** G-02 is **closed**. G-04 is **partial**: only proposals
> are typed; `_likes`, `_intros`, `_approved`, `_skipped`, `_contactRequestsOut`,
> `_sharedContacts` and `_unmatched` are still untyped sets. G-29 is partial. Two launch-crash bugs not in this analysis (C-1 chat persistence, C-2 string-set
> persistence) were found and fixed during Stage 6a — see `IMPLEMENTATION_PROGRESS.md`.

## Scoreboard

| Status | Count |
|---|---|
| Complete | 3 |
| Partial | 14 |
| Broken | 6 |
| Missing | 11 |
| Unverified | 6 (all visual — gated on screenshots) |
| **Invented** (present here, absent from reference) | 9 |

**No feature is classified Complete on the basis of its UI rendering.** The three
Completes are local-only features whose full specified behaviour is implemented and
test-covered.

---

# P0 — Blocking defects

## G-01 · Authentication
- **Current:** `lib/screens/signin_screen.dart:67-86`, `lib/providers/app_store.dart:81-110`
- **Status:** **Broken**
- **Reference [D]:** "Sign in" precedes onboarding. Support states it "will not ask for
  passwords or OTPs by email", implying OTP auth. Exact method **[U]**.
- **Gap:** `signIn()` accepts any input, loads `WardProfile.demoWard`, force-completes all
  onboarding steps, and grants `AuthStage.active`. No credential check, no OTP, no token,
  no session expiry, no server. It writes a log entry claiming *"Session opened with
  2-factor verification"* — a false security claim shown to the user.
- **Dependencies:** **Backend decision (Stage 0).** Cannot be genuinely fixed without an
  auth provider.
- **Solution:** Introduce `AuthRepository` with a real implementation behind it. Until a
  provider exists, ship an explicit, labelled `DemoAuthRepository` that is compiled only
  in debug/demo flavour and **cannot** be reached in a release build. Remove the false
  2FA log string immediately (no dependency).
- **Acceptance:** A release build cannot authenticate without a server round-trip.
  Invalid credentials are rejected. Token held in `flutter_secure_storage`, not
  `shared_preferences`. Session restores on relaunch; logout invalidates server-side.
  No UI string asserts a security property the build does not have.
- **Tests:** unit — valid/invalid/expired OTP, network failure, double-submit guard,
  token persistence/restore/clear; widget — loading, error, disabled-while-submitting.

## G-02 · Incoming proposals (Journey D)
- **Current:** `lib/providers/app_store.dart:304` (`_incomingRequests`), `lib/screens/proposals_screen.dart:35,337-356`
- **Status:** **Broken** — dead code
- **Reference [D]:** Accept an incoming proposal with a checkmark, or decline it.
- **Gap:** `_incomingRequests` is **never written to anywhere in the codebase** — only
  decoded, removed from, and cleared. `incomingContactRequests` always returns `[]`;
  `pendingRequestCount` is always `0`; the Accept/Decline UI is unreachable. Journey D
  cannot be completed on any device.
- **Dependencies:** G-04 (proposal state machine); backend for the real case.
- **Solution:** Model inbound proposals as first-class `Proposal` records with
  `direction` and `status`. Populate from the repository.
- **Acceptance:** With a seeded inbound proposal, the Received tab lists it; accept
  transitions to matched on both sides; decline transitions to declined and removes it;
  both survive relaunch.
- **Tests:** unit — accept/decline transitions, idempotency; widget — Received tab
  renders items, accept and decline each produce the correct resulting state.

## G-03 · Verification is client-approved
- **Current:** `lib/providers/app_store.dart` `submitVerificationDoc`, `approveVerificationDoc`, `submitOnboarding`, `isBarkatVerified`; `lib/screens/verification_screen.dart`, `lib/screens/photos_verification_screen.dart`
- **Status:** **Broken** (integrity defect)
- **Reference [D]:** Barkat's **team manually reviews every profile before it goes live**.
  Documents: government ID / degree or university ID / employment or business proof.
  Badge means "we checked submitted materials". Reports reviewed within 24 h.
- **Gap:** The client calls `approveVerificationDoc()` on itself; `submitOnboarding()`
  unconditionally sets `waliVerified: true`. The badge is self-granted. "Upload" flips an
  enum — there is no file picker, no file, no storage, no reviewer. This directly violates
  the project rule *"Never let a client mark its own profile as verified."*
- **Dependencies:** Backend + protected object storage (Stage 0).
- **Solution:** Client may only **submit**. Delete `approveVerificationDoc` from the
  client entirely. Status becomes server-owned and read-only: `notSubmitted → pending →
  approved | rejected(reason) → resubmitted`. Documents go to access-controlled storage
  with short-lived signed URLs, never logged.
- **Acceptance:** No client code path can set `approved`. Profile is not discoverable
  until the server marks it live. Rejection reason renders with a resubmit action.
  Document URLs appear in no log or crash report.
- **Tests:** unit — state machine rejects client-side approval, rejection→resubmit;
  widget — pending/approved/rejected/notSubmitted all render.

## G-04 · Proposal & match state are untyped boolean sets
- **Current:** nine `Set<String>` fields in `lib/providers/app_store.dart:201-310`
- **Status:** **Broken** (data-integrity defect)
- **Reference [D]:** "A match happens only when interest is mutual."
- **Gap:** No `Proposal`/`Match` entity, no `ProposalStatus` enum, no transition
  validation. Illegal states are reachable (a profile can be in `_approved` *and*
  `_skipped`). `acceptContact()` calls `approveIntro()`, so a **one-sided** contact
  request manufactures a mutual match — violating the one rule the reference states most
  plainly.
- **Dependencies:** none to model; backend to enforce.
- **Solution:** Add `Proposal {id, fromUserId, toUserId, status, createdAt, respondedAt}`
  with `ProposalStatus { sent, received, accepted, declined, withdrawn, expired }` and an
  explicit allowed-transition table. `Match` is created **only** by the server when two
  reciprocal accepted proposals exist.
- **Acceptance:** Transition table unit-tested exhaustively, including every illegal
  transition. No client path creates a `Match`.
- **Tests:** unit — full transition matrix; property test that no single-sided action
  yields a match.

## G-05 · Fabricated subscription state
- **Current:** `lib/screens/premium_screen.dart:118,156-162,219,233,241`
- **Status:** **Broken**
- **Reference [D]:** Real SKUs — Barkat Monthly ₹2,499, Premium Weekly ₹999, Credits Pack
  Small ₹499, Credit Single ₹99, Contact Reveal ₹99, Pending Limit Increase ₹99, Daily
  Intro Limit Increase ₹99, Unlock Profile ₹49, Unlock Single Profile Message ₹49.
  Free: View Profile, Send Proposals, Chats.
- **Gap:** Hardcoded `'Renews 12 Nov 2026 · billed monthly'` presents an active paid
  subscription to a user who never purchased — violating *"Never mark a payment
  successful solely because a button was tapped."* Quotas shown (5/day, 30/month) are
  **invented**; the reference publishes no such numbers. "Purchase history" is a snackbar.
- **Dependencies:** `in_app_purchase` + server receipt validation (Stage 10).
- **Solution:** Until IAP exists, render an honest **unsubscribed free-tier** state. Drive
  plan metadata and quota values from server config, never constants. Entitlements come
  from server-validated receipts only.
- **Acceptance:** No build claims a subscription the user does not hold. No price or
  renewal date is hardcoded in Dart. Quotas read from config.
- **Tests:** unit — entitlement display for free/active/expired/grace; widget — paywall
  renders free state with no fabricated renewal.

## G-06 · Release builds have no INTERNET permission
- **Current:** `android/app/src/main/AndroidManifest.xml` (zero `uses-permission`); INTERNET only in `src/debug/`, `src/profile/`
- **Status:** **Broken** (release blocker)
- **Gap:** All profile imagery is remote. A release APK shows no images, and every future
  API call fails. No camera/photo-library permissions on Android or in
  `ios/Runner/Info.plist` — required before photo upload (G-12) can work.
- **Dependencies:** none. **Fix in Stage 1.**
- **Solution:** Add `INTERNET` to the main manifest; add camera/photo permissions with
  `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` when G-12 lands.
- **Acceptance:** `flutter build apk --release` installs and renders remote images.
- **Tests:** manual release-build verification on a device (must be *performed*, not assumed).

---

# P1 — Core product gaps

## G-07 · Messages missing from bottom navigation
- **Current:** `ChatTabScreen` routed at `/home/chat` **outside** `StatefulShellRoute`; `lib/app_router.dart`, `lib/screens/home_shell.dart`
- **Status:** **Partial**
- **Reference [D]:** "Find chats under **Messages** in the bottom navigation."
- **Gap:** No nav entry; tab state is lost on every visit; unread badge invisible from the
  shell. Instead, **Premium occupies a tab** — nothing in the reference supports a premium
  bottom tab.
- **Solution:** Add a `StatefulShellBranch` for Messages. Move Premium off the tab bar
  (reach it from Profile/Settings).
- **Acceptance:** Messages is a tab, keeps scroll/state across tab switches, shows an
  unread count.
- **Tests:** widget — tap Messages tab, state preserved on return; badge reflects `totalUnread`.

## G-08 · Report and block are decorative
- **Current:** `lib/screens/match_detail_screen.dart:137` — snackbar: *"Report or block options are reviewed by the trust team."*
- **Status:** **Missing** (presented as present)
- **Reference [D]:** "Report or block from the profile menu." Safety reports reviewed within 24 h.
- **Gap:** The app's only safety affordance is a toast. Block does not exist anywhere
  (`grep` for `Block` yields no feature code). Violates *"Do not use fake buttons … or
  decorative controls pretending to be functional."*
- **Dependencies:** backend to enforce; the UI and local enforcement can land first.
- **Solution:** Real menu → report (reason picker, confirmation) and block (confirm,
  then hide the profile, remove from discovery/matches, disable the conversation).
- **Acceptance:** Blocking removes the profile from discovery, matches and search, and
  disables the thread; blocks persist; server enforces on both sides.
- **Tests:** unit — blocked ids excluded from every list; widget — menu actions, confirm
  dialogs, blocked-conversation state.

## G-09 · "Search Rishtey" screen missing
- **Current:** `lib/screens/filters_screen.dart` (filter sheet only)
- **Status:** **Missing**
- **Reference [D]:** A named screen, "Search Rishtey", for browsing recommendations with
  filters and a Suggestions/Nearby switch.
- **Gap:** No search screen, no keyword search, no result list distinct from the Discover deck.
- **Solution:** New search screen with query + filters + paginated results.
- **Acceptance:** Query and filters combine correctly; results paginate; empty and error
  states handled; filter state restored on return.
- **Tests:** unit — filter composition; widget — empty results, error retry, pagination.

## G-10 · Suggestions / Nearby modes missing
- **Status:** **Missing**
- **Reference [D]:** "Switch between Suggestions and Nearby." App Store privacy labels
  confirm **coarse location** collection.
- **Gap:** No location permission, no location field, no mode toggle. Whether Nearby uses
  GPS or a stated city is **[U]**.
- **Dependencies:** `permission_handler`/location plugin; server-side geo query.
- **Solution:** Mode toggle; request coarse location with rationale; graceful degradation
  to city when denied.
- **Acceptance:** Permission denial degrades gracefully, never blocks the app.
- **Tests:** widget — toggle, permission-denied path.

## G-11 · Filters incomplete
- **Current:** `lib/models/filters.dart` — `minAge`, `maxAge`, `marriageStatus`, `caste`, `almaMater`, `education`, `profession`, `location`, `contactSharing`, `cities`, `waliVerifiedOnly`, `practiceTags`, `nikahTimeline`
- **Status:** **Partial**
- **Reference [D]:** education, profession, city, **country**, age, **sect**, marital
  status, lifestyle preferences; alma mater with named institutions.
- **Gap:** **`country` and `sect` missing.** Present-but-unsupported: `waliVerifiedOnly`,
  `practiceTags`, `nikahTimeline`, `contactSharing` (invented). `caste` vs the
  reference's "community" wording is **[U]**. Alma mater is a free `String`, not the
  documented institution list (AMU, Jamia, IIT, JNU, AIIMS, DU, IIM, Osmania, IISc, Harvard).
- **Solution:** Add country + sect; back alma mater with a server-driven option list;
  move filtering server-side (see G-14).
- **Acceptance:** All [D] filters present and combinable; options load from config and
  degrade gracefully when unavailable.
- **Tests:** unit — each filter and combinations; serialization round-trip.

## G-12 · Photo management has no real picker, upload, or privacy
- **Current:** `lib/screens/photos_verification_screen.dart`, `lib/widgets/app_images.dart`
- **Status:** **Partial**
- **Reference [D]:** Onboarding step 4 is Photos. "Privacy-first photo options." "Photos
  and contact stay under your control until both sides are ready."
- **Gap:** No `image_picker`, no upload, no crop, no reorder, no per-photo visibility.
  "Modesty blur" is an invented local filter; Barkat's actual photo privacy controls are **[U]**.
- **Dependencies:** `image_picker`, platform permissions (G-06), object storage.
- **Solution:** Real picker, client-side compression, upload with progress/retry,
  per-photo visibility honoured by the server.
- **Acceptance:** Photos upload and persist; private photos are not served to
  unauthorised viewers (server-enforced); upload failures retry.
- **Tests:** unit — upload error mapping; widget — picker invocation, progress, failure.

## G-13 · Mutual-consent contact sharing is faked
- **Current:** `lib/providers/app_store.dart:446-495`
- **Status:** **Broken**
- **Reference [D]:** "Request Contact" exists; "more information is shared only when both
  sides agree"; **Barkat Contact Reveal ₹99** is a paid action.
- **Gap:** `requestContact()` schedules a 2.4 s `Timer` that calls `acceptContact()` —
  **fabricating the other party's consent** — and `acceptContact()` then calls
  `approveIntro()`, manufacturing a match. Credits decrement locally with no purchase.
- **Dependencies:** backend; IAP for the paid path.
- **Solution:** Request creates a pending record; only the recipient's action (or server)
  can accept. Delete the auto-accept timer.
- **Acceptance:** No client timer changes another user's consent state. Contact details
  are withheld until the server reports mutual agreement.
- **Tests:** unit — request→pending, accept only by recipient, decline path.

## G-14 · All filtering/matching is in-memory over 5 local seeds
- **Current:** `lib/providers/app_store.dart` `discoveredProfiles`; `lib/models/match_profile.dart:162-374`
- **Status:** **Missing** (as a product capability)
- **Reference [D]:** "Curated profiles everyday"; server-side recommendations.
- **Gap:** 5 hardcoded `static const` profiles filtered client-side — the exact
  anti-pattern the project rules forbid ("Avoid fetching the entire user database to
  filter it locally"). Three of the five reuse the same Unsplash photo; all are stock images
  of identifiable people.
- **Dependencies:** Stage 0.
- **Solution:** Repository + paginated server query. Keep the seeds behind an explicit
  demo data source for tests/offline.
- **Acceptance:** Discovery requests a page at a time; filters are query parameters; no
  full-corpus client fetch.
- **Tests:** unit — pagination, dedupe, error mapping.

## G-15 · Messaging is a local timer simulation
- **Current:** `lib/providers/app_store.dart:640-760`; `lib/screens/chat_screen.dart`, `chat_screen_parts.dart`
- **Status:** **Broken** (as messaging)
- **Reference [D]:** Chat unlocks after a match, is free, lives under Messages.
- **Gap:** `sendMessage()` spawns timers that fabricate a reply from the match (3 canned
  strings, round-robin) and a "Chaperone" audit note. No transport, no delivery/read
  status with the peer, no history pagination, no send-failure retry, no blocked-user
  restriction. Violates *"Do not pretend that real-time messaging exists if the backend
  only supports static local messages."*
- **Dependencies:** real-time infrastructure (Stage 0 decision).
- **Solution:** `ChatRepository` with a streaming implementation; delete the fake-reply
  timers. If no infra is approved, the demo path must be **labelled in-app as a demo**.
- **Acceptance:** Messages persist server-side; history paginates; failed sends show
  retry; blocked users cannot send; unread counts derive from server state.
- **Tests:** unit — send failure/retry, pagination, unread computation; widget — empty,
  loading, error, blocked states.

## G-16 · iOS screenshot protection silently absent
- **Current:** `lib/services/privacy_shield.dart`; `ios/Runner/AppDelegate.swift`
- **Status:** **Broken**
- **Gap:** The Dart doc comment promises "secure text entry trick on iOS", and Android's
  `FLAG_SECURE` is correctly implemented in `MainActivity.kt`. **`AppDelegate.swift`
  registers no handler** for `com.barkat.nikah/privacy_shield`, so every iOS call is
  swallowed by `catch (_)`. A stated privacy protection does not exist on iOS.
- **Dependencies:** none. **Fix in Stage 1.**
- **Solution:** Implement the iOS handler, or correct the comment and any UI claim to say
  Android-only. Do not leave the claim unbacked.
- **Acceptance:** Behaviour matches the documentation on both platforms.
- **Tests:** manual on-device verification per platform.

## G-17 · Account deletion missing
- **Status:** **Missing**
- **Reference [D]:** "Delete account" is a footer link and a `/help` topic.
- **Gap:** No deletion flow; `signOut()` only flips a local enum. Store policy on both
  platforms requires in-app deletion for accounts created in-app.
- **Solution:** Settings → delete account, with confirmation, consequences, and a server
  deletion request.
- **Acceptance:** Deletion is confirmed, server-initiated, and clears all local state
  including secure storage.
- **Tests:** widget — confirm dialog, cancel path; unit — local state fully cleared.

## G-18 · Graduate-only eligibility gate missing
- **Status:** **Missing**
- **Reference [D]:** Graduates and degree students only; first-time nikah profiles only.
- **Gap:** No eligibility check at onboarding. `maritalStatus` defaults to "Never married"
  but is not enforced.
- **Solution:** Validate education level at onboarding step 3; surface the policy.
- **Acceptance:** A non-qualifying education level cannot complete onboarding; the reason
  is explained.
- **Tests:** unit — eligibility validator; widget — rejection message.

## G-19 · Onboarding step composition diverges from the reference
- **Current:** account → education/career → **Islamic practice** → photos/verification → **Wali** → biodata → review
- **Status:** **Partial**
- **Reference [D]:** basic info → personal details → education and profession → photos →
  verification → review and submit.
- **Gap:** Both are six steps, but ours substitutes Islamic Practice and Wali for the
  reference's Personal Details and (separate) Verification step; photos and verification
  are merged in ours. Reference step 6 also expects **family type, members and a family
  summary** plus optional guardian phone link — ours over-builds the guardian half and
  omits the family-description half.
- **Solution:** Re-sequence to the documented six; fold sect/practice into Personal
  Details; split Verification into its own step; add family type/members/summary fields.
- **Acceptance:** Six steps matching the reference names, with draft persistence and
  resume preserved (that mechanism already works — keep it).
- **Tests:** widget — full six-step traversal; unit — draft persist/resume.

## G-20 · Two distinct quotas needed; one invented quota present
- **Current:** `AppStore.proposalQuota = 5`, `monthlyContactCredits = 30`
- **Status:** **Partial**
- **Reference [D]:** SKUs prove **two** independent limits — "Daily Intro Limit Increase"
  and "Pending Limit Increase" — plus a credits currency. **[U] the numeric values are
  unpublished.**
- **Gap:** Our `5` and `30` are fabricated constants, enforced only client-side.
- **Solution:** Server-configured `dailyIntroLimit` and `pendingProposalLimit`;
  server-enforced. Client displays, never decides.
- **Acceptance:** No quota number is a Dart constant; exceeding a limit is rejected by
  the server.
- **Tests:** unit — quota display from config, exhausted-state UI.

## G-21 · Guardian/family access authorisation model undefined
- **Current:** `wali_hub_screen.dart` (422), `wali_sms_portal_screen.dart` (381), `wali_onboarding_screen.dart` (424), `models/wali.dart`
- **Status:** **Unverified / over-built**
- **Reference [D]:** "Guardian and parent access so families can participate without
  turning nikah into a public feed"; link a parent/guardian phone during onboarding.
  **[U] mechanics are explicitly not documented.** Barkat never says "wali" or "chaperone".
- **Gap:** ~1,200 LOC implements an invented SMS passcode portal and guardian approval
  gate with **no permission model at all** — `privacy()` is a hardcoded `List<String>`
  (`app_store.dart:800-812`) and `verifyGuardianSms()` simply sets `isVerified: true`
  locally. A guardian's actual scope is undefined, so the project rule *"A guardian must
  not automatically gain unrestricted access to private conversations, documents,
  account credentials, or personal data"* cannot be shown to hold.
- **Dependencies:** **Product decision + backend.** Design the authorisation model before
  touching the UI.
- **Solution:** Define a scoped permission model (view profile / view proposals / receive
  notifications — explicitly **not** conversations, documents or credentials), invite via
  a server-issued token, server-enforced, revocable.
- **Acceptance:** Permissions enumerated and server-enforced; no guardian path reaches
  conversations or documents; revocation is immediate.
- **Tests:** unit — permission matrix incl. every denial; integration — guardian cannot
  read a conversation.

---

# P2 — Quality and completeness

| ID | Gap | Current | Status | Solution | Acceptance |
|---|---|---|---|---|---|
| G-22 | No pagination / refresh / loading / error states in discovery | `discovery_screen.dart:203` | **Partial** | Paginated repository, `RefreshIndicator`, skeletons, error+retry | Scroll loads the next page; pull-to-refresh works; every state renders |
| G-23 | Design system missing skeletons, error-with-retry, confirm dialog, bottom sheet, filter chip | `lib/widgets/` | **Partial** | Add the five widgets; reuse the existing 11 | Each has a widget test; no screen hand-rolls them |
| G-24 | Share profile is a snackbar | `match_detail_screen.dart:128` | **Missing** | Implement share, or remove the control | No decorative control remains |
| G-25 | Six About-screen links are snackbars | `about_screen.dart:65,77,89,105,115,125` | **Broken** | Open real URLs (`url_launcher`) | Each link opens its page |
| G-26 | `AppStore` is a 1299-LOC God object owning 9 domains + its own fake backend | `providers/app_store.dart` | **Partial** | Split behind repository interfaces, keep `provider` | No store exceeds ~300 LOC; each domain independently testable |
| G-27 | Branding inconsistent across platforms | `MaterialApp.title` "Barkat Nikah" · Android label `nikah_app` · iOS "Nikah App"/`nikah_app` · `applicationId com.barkat.nikah.nikah_app` · template `description` | **Broken** | Settle one product name and apply it everywhere | Name identical on both platforms; pubspec description real |
| G-28 | Unverified provenance claim in the theme | `app_theme.dart:3-10` vs `README.md` | **Broken** | Correct the comment to its true origin (Stitch) | No code comment asserts unverified reference fidelity |
| G-29 | No `Proposal`/`Match`/`Conversation`/`Subscription`/`User` entities | `lib/models/` | **Missing** | Add them; match the real backend schema once known | Entities exist with round-trip serialization tests |
| G-30 | No unit tests; 11 widget tests in one 400-LOC file | `test/widget_test.dart` | **Partial** | Split into `test/unit/`, `test/widget/`; add unit coverage | Baseline 11 still pass; unit suite covers models, validators, state machines |
| G-31 | No secure storage | `shared_preferences` only | **Missing** | `flutter_secure_storage` for tokens/session | No credential in plain prefs |
| G-32 | Stray artefacts: 105 KB root `index.html`, `serve.py` | repo root | **Partial** | Move under `tools/` or delete after confirming unused | Repo root holds only project files |
| G-33 | Seed photos: Unsplash stock of real people shown as members | `match_profile.dart` | **Broken** | Replace with original/licensed placeholders | No stock person is presented as a member |
| G-34 | `analysis_options.yaml` is the untouched template | root | **Partial** | Enable stricter lints incrementally | Stricter set passes with 0 issues |

---

# P3 — Polish

| ID | Gap | Status |
|---|---|---|
| G-35 | No `cached_network_image` — images refetch on every rebuild | **Partial** |
| G-36 | Canned 3-string reply pool | **Broken** (removed with G-15) |
| G-37 | No accessibility audit (touch targets, text scaling, semantics) | **Unverified** |
| G-38 | No push notifications; `NotificationItem`s are local objects | **Missing** |
| G-39 | "Events" (referenced in Barkat release notes) has no counterpart | **Unverified** — nature **[U]** |

---

# Unverified — gated on visual evidence

These **cannot be assessed** without screenshots or a recording of the real app. Per
project rules, no colour, dimension, or animation is guessed.

| ID | Item |
|---|---|
| G-40 | Brand colours (exact hex) — ours are Stitch-derived, provenance disputed (G-28) |
| G-41 | Typography family, weights, sizes — ours is Plus Jakarta Sans via `google_fonts` |
| G-42 | Spacing scale and border radii |
| G-43 | Bottom nav and app bar visual design; tab icons (names [D], visuals [U]) |
| G-44 | Profile card layout and image treatment |
| G-45 | Empty / loading / error / success state designs; modals and transitions |

---

# Invented features — needs a product decision, not an engineering one

~2,100 LOC of working, polished code implements features with **no public reference
support**. Removing them deletes functioning work; keeping them makes the app diverge
from the stated target. **This is your call and I have not assumed either way.**

| Feature | LOC | Reference support |
|---|---|---|
| Wali SMS verification portal | 381 | **None** |
| Wali & Privacy Hub | 422 | **None** |
| Wali onboarding step | 424 | Guardian *phone link* is [D]; this flow is not |
| Family meeting scheduler (video/audio/in-person) | 477 | **None** |
| Chaperoned chat with a third "Chaperone" sender | ~200 | **None** — reference says chat is free after match, with no supervision |
| Wali approval gate on introductions | ~150 | **None** — reference gates on mutual *member* consent |
| Islamic Practice onboarding step | 317 | Sect is a [D] filter; a dedicated step is not |
| Honour-pledge checkboxes | ~60 | **None** |
| "Modesty blur" photo filter | ~80 | "Privacy-first photo options" is [D]; blur specifically is [U] |

**Three options:**
- **A — Reference-faithful:** remove or hide the invented surface; rebuild against [D]
  features only. Highest fidelity, discards the most work.
- **B — Superset (recommended):** keep the guardian/family features as a **differentiator**,
  but (i) fix their integrity defects (G-21, G-15), (ii) stop them gating core flows the
  reference leaves ungated, (iii) implement all missing [D] features first.
- **C — Defer:** ship [D] features, leave invented screens behind a feature flag pending
  a decision.

---

# Dependency order

```
Stage 0  Backend decision ─────────────────────────────┐
                                                        │
G-06, G-16, G-27, G-28, G-32  (no dependencies) ────────┤ can start immediately
G-04, G-29, G-30, G-23, G-34  (local modelling) ───────┤
                                                        │
G-01 auth ──→ G-03 verification ──→ G-14 discovery ────┤ all require Stage 0
G-02 proposals (needs G-04) ──→ G-13 ──→ G-15 chat ────┤
G-12 photos (needs G-06) ──→ G-21 guardian ────────────┤
G-05 premium (needs G-01, G-20) ───────────────────────┘

G-07, G-08, G-09, G-11, G-17, G-18, G-19, G-22  partially deliverable offline
G-40…G-45  blocked on screenshots (external dependency)
```
