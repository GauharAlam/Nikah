# Product Flow Audit

**Audited:** 2026-11-01, commit `a202624`. Stages follow the master brief.

## Journey status at the audit

| Stage | State |
|---|---|
| Launch and session restore | Works; no failure handling |
| Landing | Works; placeholder legal links and wrong brand |
| Phone sign-in | Works in code; never run against Firebase |
| Onboarding | Seven steps, not six; family section and several fields missing |
| Review | Works; thin reviewer tools |
| Discovery | Paged and server-side; no search or nearby |
| Proposals and matches | Solid |
| Chat | Real transport; several false indicators |
| Family | Basic code-based circle |
| Privacy and deletion | Partial |
| Notifications | Written; never run on a device |
| Purchases | Android path cannot succeed (SEC-07) |

---

## Findings

### FLOW-01 · Onboarding does not follow the six steps — High
- **Existing:** seven steps: who, basics, location, details, education, photos, verify and
  review. Identity, location and date of birth are scattered across three.
- **Expected:** Basic Information, Personal and Family, Education and Profession, Photos,
  Verification, Review and Submit.
- **Files:** `lib/screens/onboarding/onboarding_screen.dart`,
  `lib/widgets/onboarding_shell.dart`.
- **Solution:** regroup existing widgets into six steps, with a migration of the saved
  `step` value so drafts in progress resume at the right place.
- **Acceptance:** six steps, and a saved step 7 opens step 6.
- **Tests:** widget test for each step and the validation; unit test of step migration.

### FLOW-02 · Required profile fields are missing — High
- **Existing:** no preferred language, family type, family background, family values,
  family location, siblings, graduation year, education status, employment status, work
  location, or career description.
- **Expected:** all present, sensitive ones optional.
- **Files:** `lib/models/ward_profile.dart`, onboarding, `functions/src/rules.ts`.
- **Solution:** add fields to the draft, with family details visible only per the
  classification in `FIREBASE_SECURITY.md`.
- **Acceptance:** fields round-trip and reach the right audience.
- **Tests:** model round-trip; flow test for card contents.

### FLOW-03 · Photo management is minimal — High
- **Existing:** multi-select only, a blocking spinner, no camera, reorder, primary photo,
  upload progress, or moderation status.
- **Expected:** the full list in the brief.
- **Files:** onboarding, `lib/data/firebase_backend.dart`, `functions/src/*`.
- **Solution:** a shared `PhotoManager` widget used by onboarding and Edit Profile.
- **Acceptance:** reordering changes the primary photo; a rejected photo shows its state.
- **Tests:** widget test.

### FLOW-04 · Verification flow incomplete — High
- **Existing:** four states; image gallery only, though the server accepts PDFs; no file
  size check, no preview, and an upload can't be retried from its error.
- **Expected:** six states, file picker, preview, validation, progress and resubmission.
- **Files:** `lib/screens/verification_screen.dart`, `lib/models/verification_doc.dart`,
  `functions/src/*`.
- **Solution:** add `file_picker`, validate before upload, and show reason and resubmit.
- **Acceptance:** an oversized file is refused locally and by rules; a rejected document
  shows its reason and a resubmit action.
- **Tests:** widget test per state.

### FLOW-05 · Reviewer tools are too thin to review — High
- **Existing:** a card with a few text fields. No photos, no request-resubmission, no held
  profiles, no reports, no history.
- **Expected:** a usable moderation console.
- **Files:** `lib/screens/review_queue_screen.dart`, `functions/src/*`.
- **Solution:** tabs for Submissions, Edits, Reports; full preview with signed photo URLs,
  and three decisions: approve, request changes, reject.
- **Acceptance:** a reviewer can complete each case in the app.
- **Tests:** widget tests.

### FLOW-06 · Sign-in edge cases — High
- **Existing:** Google accounts skip phone verification, so one person can hold two
  accounts. `sendOtp` never times out if no callback arrives, and Android auto-verify
  leaves the future pending. Resend does not use the force-resend token.
- **Expected:** one account per verified phone; every path ends in a clear state.
- **Files:** `lib/data/firebase_backend.dart`, `lib/screens/phone_signin_screen.dart`.
- **Solution:** link a phone during onboarding, complete on auto-verify, add a timeout, and
  pass `forceResendingToken`.
- **Acceptance:** Google users cannot submit without a linked phone.
- **Tests:** widget test; controller test.

### FLOW-07 · Discovery lacks search and nearby — High
- **Existing:** deck and filters only; no Search Rishtey, no country filter, no skeletons;
  location used only to fill a city field.
- **Expected:** search by text and institution, suggestions and nearby, with consent.
- **Files:** `lib/screens/discovery_screen.dart`, `lib/screens/filters_screen.dart`,
  `lib/models/filters.dart`, `functions/src/*`.
- **Solution:** a search screen on server-side filters; nearby uses the coarse city a
  member chose to share.
- **Acceptance:** all filters combine; turning nearby off removes the member from it.
- **Tests:** logic, flow and widget tests.

### FLOW-08 · Chat shows things that are not true — High
- **Existing:** a permanent green "online" dot; a "seen" label on incoming messages driven
  by a local toggle; `unread` from a device-local read time, so a reinstall marks every
  message unread, and the server counter only ever rises.
- **Expected:** only real states are shown.
- **Files:** `lib/screens/chat_screen.dart`, `lib/screens/chat_screen_parts.dart`,
  `functions/src/*`, rules.
- **Solution:** remove the dot, use the other member's real `readAt`, and reset the server
  counter on read.
- **Acceptance:** two devices agree on read state.
- **Tests:** rules test for the reset; controller test.

### FLOW-09 · Chat reliability gaps — High
- **Existing:** failures are a snack and the text is lost; no history paging; no closed
  thread banner; no report from the conversation; offline is not handled.
- **Expected:** pending, failed and retry states; older messages load on scroll.
- **Files:** `lib/screens/chat_screen.dart`, chat controller.
- **Solution:** local pending messages with retry; cursor paging; closed state.
- **Acceptance:** a failed send can be retried without retyping.
- **Tests:** controller and widget tests.

### FLOW-10 · Match views incomplete — Medium
- **Existing:** Chat Matches and Shared Contacts decks only. No pending contact view, no
  closed relationships.
- **Expected:** the five views in the brief.
- **Files:** `lib/screens/matches_hub_screen.dart`.
- **Solution:** add Pending and Closed tabs.
- **Acceptance:** each match appears in exactly one view.
- **Tests:** controller test.

### FLOW-11 · Activities timeline is always empty in production — High
- **Existing:** `activityLog` is a local list that only the demo writes.
- **Expected:** real activity.
- **Files:** `lib/screens/activities_screen.dart`, `lib/providers/app_store.dart`.
- **Solution:** derive the timeline from the member's server notifications and proposals.
- **Acceptance:** a real proposal appears.
- **Tests:** controller test.

### FLOW-12 · Settings miss required controls — High
- **Existing:** no notification preferences, blocked list, unblock, data export, profile
  visibility, deactivation or contact-sharing preference in production.
- **Expected:** all present and enforced by the server.
- **Files:** `lib/screens/settings_screen.dart`, `functions/src/*`.
- **Solution:** a server-backed privacy controller and a blocked members screen.
- **Acceptance:** each setting changes server behaviour.
- **Tests:** flow and widget tests.

### FLOW-13 · Delete Account gives no real journey — High
- **Existing:** a dialog and a fire-and-forget call. No re-authentication, no retention
  explanation, no completion state.
- **Expected:** explanation, recent sign-in, progress and completion.
- **Files:** `lib/screens/settings_screen.dart`.
- **Solution:** a dedicated screen on the deletion job from SEC-08.
- **Acceptance:** an old session is asked to verify again; failure shows retry.
- **Tests:** widget test.

### FLOW-14 · Misleading copy — Medium
- **Existing:** "on this device" in the block dialog, chaperone language, "Report or block
  options are reviewed by the trust team" variants, example.com links.
- **Expected:** copy that matches behaviour.
- **Files:** `lib/screens/match_detail_screen.dart`, others.
- **Solution:** correct each string.
- **Acceptance:** reviewed against behaviour.
- **Tests:** widget tests on key strings.

### FLOW-15 · Shared loading, error and empty states — Medium
- **Existing:** no skeleton or retry widget, so screens improvise; several show a spinner
  forever if a load fails.
- **Expected:** every screen has all states.
- **Files:** `lib/widgets/`, screens.
- **Solution:** add `AppSkeleton` and `ErrorState`, used by all data screens.
- **Acceptance:** failed loads offer retry.
- **Tests:** widget tests.

### FLOW-16 · Launch failure handling — Medium
- **Existing:** if the auth stream errors or the draft fails to load, the app stays on a
  spinner or continues with a null profile. Splash is a bare spinner.
- **Expected:** a branded splash, and retry on failure.
- **Files:** `lib/app_router.dart`, session code.
- **Solution:** a load error state and a timeout.
- **Acceptance:** a failed draft load offers retry.
- **Tests:** controller and widget test.

### FLOW-17 · Deep links are not validated — Medium
- **Existing:** push accepts any path starting with `/`, and `/photo/:id` takes a URL from
  the query string.
- **Expected:** an allow-list; the viewer never loads an arbitrary URL.
- **Files:** `lib/main.dart`, `lib/app_router.dart`.
- **Solution:** a `safeDeepLink` function and a viewer that takes an in-app reference.
- **Acceptance:** unknown links are ignored.
- **Tests:** unit test.

### FLOW-18 · Purchase journey is incomplete — Medium
- **Existing:** no history, no renewal terms, and "Plans" reachable only with no explanation
  of what each grants.
- **Expected:** clear terms, restore, and history.
- **Files:** `lib/screens/plans_screen.dart`, `lib/screens/premium_screen.dart`.
- **Solution:** show server-described plans with the store price, and purchase history.
- **Acceptance:** renewal terms are shown before buying.
- **Tests:** widget test.

### FLOW-19 · Family-managed mode is a label — High
- **Existing:** `managedBy` only changes a badge. The operator and the subject are not
  distinct, and the subject has no account or control.
- **Expected:** the concepts in section 6 of the brief.
- **Files:** see `FAMILY_ACCESS_MODEL.md`.
- **Solution:** implement the model, including subject confirmation (SEC-17).
- **Acceptance:** a family-created profile cannot go live until the subject confirms from
  their own phone.
- **Tests:** flow tests.
