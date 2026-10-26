# Codebase Audit — Nikah_App

**Date:** 2026-10-26
**Auditor:** Claude (senior Flutter engineer role)
**Commit audited:** `00a9180` — "Initial commit: Barkat Nikah app with complete Islamic matrimony flows"
**Working tree:** clean

---

## 1. Verdict in one paragraph

This is **not** a broken prototype. It is a well-engineered, internally consistent,
**100% offline demo** of a Muslim matrimony app: 55 Dart files, ~17,400 LOC, zero
analyzer issues, 11/11 widget tests passing. The code quality is genuinely good
(null-safe, typed, controllers disposed, design tokens centralised, go_router with
real deep links, persistent state).

The problem is not quality — it is **provenance and substance**:

1. **There is no backend of any kind.** No HTTP client, no Firebase, no Supabase, no
   auth provider, no socket. Every profile, message, proposal, verification approval
   and match is generated locally from 5 hardcoded seed objects.
2. **It was not reverse-engineered from Barkat.** `README.md` states it was built from
   **Google Stitch** AI-generated designs for a generic "Islamic matrimony" concept.
   `lib/theme/app_theme.dart` claims its colours were "pixel-sampled" from Barkat Play
   Store screenshots, but the README documents a different, Stitch-derived palette.
   Those two claims contradict each other; neither is verifiable from this repo.
3. **Roughly half the feature surface is invented**, not observed in Barkat: the Wali
   SMS verification portal, chaperoned chat with a third-party "Chaperone" message
   sender, guardian approval gates on introductions, and the family-meeting scheduler
   have **no counterpart in any public Barkat material** (see `REFERENCE_ANALYSIS.md`).
4. Conversely, **several confirmed Barkat features are entirely absent**: Suggestions/
   Nearby discovery modes, keyword "Search Rishtey", country and sect filters, Messages
   as a bottom-nav tab, block, and account deletion.

---

## 2. Verified project structure

Directories that **actually exist** (verified by `ls`/`find`):

```
lib/  android/  ios/  web/  linux/  macos/  windows/  test/  stitch/  build/  .idea/
pubspec.yaml  analysis_options.yaml  README.md  serve.py  index.html  pubspec.lock
```

Note: the prompt's expected structure was accurate. Two unlisted items exist:
`serve.py` (a local static file server) and a 105 KB root `index.html` — a one-off web
export artefact, not wired into the Flutter build.

### `lib/` tree (verified)

```
lib/
├── main.dart                     45 LOC   entry point
├── app_router.dart              ~230 LOC  go_router route table
├── theme/app_theme.dart          320 LOC  design tokens + ThemeData
├── providers/app_store.dart     1299 LOC  ⚠️ the entire app's state + fake backend
├── services/privacy_shield.dart   42 LOC  FLAG_SECURE MethodChannel
├── models/      (9 files,  ~1455 LOC)
├── screens/     (33 files, ~13,000 LOC)
└── widgets/     (11 files, ~1700 LOC)
```

---

## 3. Architecture

**Pattern: layered, presentation-heavy, with a single God-object store.**

| Layer | Implementation | Assessment |
|---|---|---|
| Presentation | `screens/` + `widgets/` | Good. Consistent, token-driven. |
| State management | `provider` + one `ChangeNotifier` (`AppStore`) | Works, but `AppStore` is 1299 LOC and owns 9 unrelated domains. |
| Domain / business logic | **Fused into `AppStore`** | No domain layer exists. |
| Repository | **Does not exist** | — |
| Data source / API client | **Does not exist** | — |
| Models | `models/` with manual `toJson`/`fromJson` + `copyWith` | Solid, hand-written, no codegen. |
| DI | None (single `ChangeNotifierProvider.value` in `main.dart`) | Acceptable at this size. |
| Navigation | `go_router` 16, `StatefulShellRoute.indexedStack` | **Genuinely good.** Declarative table in `AppRoutes`, path params, deep links, custom transitions, error builder. Preserve this. |
| Persistence | `shared_preferences`, JSON-encoded per domain | Works. Not secure storage — fine today (no real tokens), a blocker later. |

### Dependencies (all current, no bloat)

```yaml
cupertino_icons ^1.0.8   google_fonts ^9.0.0   go_router ^16.0.0
provider ^6.1.5          shared_preferences ^2.5.3   intl ^0.20.2
dev: flutter_lints ^6.0.0
```

Notably **absent** and required for the real product: any HTTP client, `image_picker`,
`cached_network_image`, `flutter_secure_storage`, `firebase_*`/`in_app_purchase`,
`permission_handler`.

Toolchain: Flutter 3.47.5 stable, Dart 3.13.4. `environment: sdk: ^3.13.4`.

---

## 4. Screen inventory (33 screens, all verified present and rendering)

### Auth & onboarding
| Screen | File | State |
|---|---|---|
| Landing | `lib/screens/landing_front_screen.dart` | Complete (as a demo) |
| Welcome / intentions | `lib/screens/welcome_intentions_screen.dart` | Complete |
| Sign in | `lib/screens/signin_screen.dart` | **Broken as auth** — see §6.1 |
| Onboarding 1 — account | `lib/screens/create_account_screen.dart` (+ `create_account_widgets.dart`) | Partial |
| Onboarding 2 — education/career | `lib/screens/education_career_screen.dart` | Partial |
| Onboarding 3 — Islamic practice | `lib/screens/islamic_practice_screen.dart` | **Invented** (not in reference) |
| Onboarding 4 — photos/verification | `lib/screens/photos_verification_screen.dart` | Partial — no real picker |
| Onboarding 5 — Wali | `lib/screens/wali_onboarding_screen.dart` | **Invented** |
| Onboarding 6 — biodata | `lib/screens/biodata_screen.dart` | Partial |
| Review & submit | `lib/screens/review_screen.dart` | Partial |

### Main shell (6 tabs — `lib/screens/home_shell.dart`)
| Tab | File | State |
|---|---|---|
| Discover | `lib/screens/discovery_screen.dart` (818 LOC) | Partial — no Suggestions/Nearby, no pagination |
| Proposals | `lib/screens/proposals_screen.dart` | **Broken** — "Received" is permanently empty, §6.2 |
| Matches | `lib/screens/matches_hub_screen.dart` (801 LOC) | Partial |
| Activities | `lib/screens/activities_screen.dart` | Complete (local log) |
| Premium | `lib/screens/premium_screen.dart` | **Broken** — fake subscription, §6.3 |
| Profile | `lib/screens/profile_screen.dart` | Partial |

**Messages is not a tab.** `ChatTabScreen` is routed at `/home/chat` *outside* the
shell, so it has no bottom-nav entry and loses tab state. The reference explicitly
places chats "under Messages in the bottom navigation."

### Sub-pages
`match_detail_screen.dart` (1173 LOC — largest screen), `chat_screen.dart` +
`chat_screen_parts.dart`, `chat_tab_screen.dart`, `filters_screen.dart` (602 LOC),
`schedule_meeting_screen.dart` (**invented**), `notifications_screen.dart`,
`settings_screen.dart`, `about_screen.dart`, `edit_profile_screen.dart`,
`verification_screen.dart`, `photo_viewer_screen.dart`, `wali_hub_screen.dart`
(**invented**), `wali_sms_portal_screen.dart` (**invented**).

---

## 5. Shared components (reusable, good quality — preserve)

`lib/widgets/`: `app_banners.dart`, `app_brand.dart`, `app_buttons.dart`,
`app_card.dart` (270 LOC), `app_images.dart`, `app_inputs.dart` (403 LOC),
`app_snacks.dart`, `app_switch.dart`, `empty_state.dart`, `onboarding_shell.dart`.

Missing from the design system: skeleton/shimmer placeholders, error-state widget with
retry, confirmation dialog, reusable bottom sheet, filter chip, pagination footer.

## Models (9, verified)

`match_profile.dart` (375 LOC, 30+ fields, 5 `static const` seeds),
`ward_profile.dart` (249), `filters.dart` (169), `wali.dart` (168),
`verification_doc.dart` (107), `meeting.dart` (92), `notification_item.dart` (72),
`chat_message.dart` (53).

**No `Proposal`, `Match`, `Conversation`, `Subscription` or `User` entity exists.**
Those concepts are represented as `Set<String>` of ids inside `AppStore` — see §6.5.

---

## 6. Technical issues found

### 6.1 — P0 · Authentication is a no-op
`lib/screens/signin_screen.dart:67-86` validates the form locally, then calls
`AppStore.signIn()` and navigates. `AppStore.signIn()`
(`lib/providers/app_store.dart:81-110`) **accepts any input**, loads
`WardProfile.demoWard`, force-marks all onboarding steps complete, and sets
`AuthStage.active`. There is no credential check, no OTP, no token, no server.
It also writes an activity log entry claiming *"Session opened with 2-factor
verification"* — a false security claim in the UI.

### 6.2 — P0 · Incoming proposals are unreachable dead code
`_incomingRequests` (`app_store.dart:304`) is **never added to anywhere in the
codebase**. It is only decoded from prefs (`:988`), removed from (`:479`, `:503`) and
cleared (`:1258`). Consequently `incomingContactRequests` always returns `[]`,
`pendingRequestCount` is always 0, and the Accept/Decline UI in
`proposals_screen.dart:337-356` can never be shown. **Journey D (receive a proposal)
cannot be completed.**

### 6.3 — P0 · Fabricated subscription and verification state
- `premium_screen.dart:118` hardcodes `'Renews 12 Nov 2026 · billed monthly'` —
  an invented active subscription for a user who never purchased.
- `premium_screen.dart:156-162` "Purchase history" is a snackbar.
- `app_store.dart:approveVerificationDoc()` lets the **client approve its own
  verification documents**; `submitOnboarding()` unconditionally sets
  `waliVerified: true`. The verified badge is self-granted.
- `requestContact()` (`app_store.dart:446`) schedules a 2.4 s `Timer` that auto-accepts
  on the other party's behalf, fabricating consent.
- `sendMessage()` (`:665`) schedules timers that fabricate a reply from the match and a
  "Chaperone" audit note.

### 6.4 — P1 · Decorative controls (11 snackbar-only dead ends)
`showAppSnack` is used 35 times; these are controls with no action behind them:
- `match_detail_screen.dart:128` — Share profile
- `match_detail_screen.dart:137` — **Report / block** (the only safety affordance in the
  app is a toast saying the feature is reviewed by a trust team)
- `match_detail_screen.dart:456`, `:564`
- `premium_screen.dart:157` — purchase history
- `about_screen.dart:65,77,89,105,115,125` — six external links

### 6.5 — P1 · Proposal/match state is booleans, not a state machine
Proposal lifecycle is eight parallel `Set<String>`s: `_likes`, `_intros`, `_approved`,
`_proposals`, `_skipped`, `_contactRequestsOut`, `_incomingRequests`, `_sharedContacts`,
`_unmatched`. There is no `ProposalStatus` enum and no transition validation. Illegal
states are reachable (e.g. a profile can be in `_approved` and `_skipped` at once).

### 6.6 — P1 · `AppStore` is a 1299-LOC God object
It owns: session, onboarding steps, profile draft, likes/intros/approvals, proposal
quota, contact credits, verification docs, chats, read receipts, meetings, guardian
state, privacy flags, activity log, notifications and settings — plus its own
persistence and its own fake backend timers.

### 6.7 — P1 · iOS screenshot protection silently does nothing
`lib/services/privacy_shield.dart` documents "secure text entry trick on iOS", and
`MainActivity.kt` correctly implements `FLAG_SECURE` for Android. **`AppDelegate.swift`
registers no handler for the `com.barkat.nikah/privacy_shield` channel**, so on iOS
every call lands in the `catch (_)` and is swallowed. Photo/biodata protection is
advertised and absent on iOS.

### 6.8 — P1 · Release Android builds have no INTERNET permission
`android/app/src/main/AndroidManifest.xml` declares **zero** `uses-permission`.
`INTERNET` exists only in `src/debug/` and `src/profile/`. All profile imagery is
remote (`images.unsplash.com`), so **release builds will show no images**, and any
future API call will fail. No camera/photo-library permissions are declared either, on
Android or in `ios/Runner/Info.plist` — required before photo upload can be built.

### 6.9 — P2 · No pagination, refresh, or error states in discovery
`discovery_screen.dart:203` renders `itemCount: profiles.length` over all 5 local seeds.
No `ScrollController` listener, no `RefreshIndicator`, no loading skeleton, no error
state, no empty-result recovery beyond a static widget. Filtering happens fully
in-memory (`app_store.dart:discoveredProfiles`) — the exact pattern that must not be
carried to a server.

### 6.10 — P2 · Branding is inconsistent across platforms
`MaterialApp.title` = "Barkat Nikah"; Android `android:label` = `nikah_app`; iOS
`CFBundleDisplayName` = "Nikah App", `CFBundleName` = `nikah_app`;
`applicationId` = `com.barkat.nikah.nikah_app` (the real app is `com.barkat.world`);
`pubspec.yaml` description is still the Flutter template default.

### 6.11 — P2 · Unverifiable provenance comment in the theme
`app_theme.dart:3-10` asserts the palette was "pixel-sampled" from Barkat Play Store
screenshots and annotates individual constants with sampled hex values. `README.md`
attributes the palette to Stitch with different values. One of the two is wrong; the
comment must not be trusted as a reference-fidelity claim.

### 6.12 — P3 · Misc
- Root `index.html` (105 KB) and `serve.py` are stray artefacts outside the Flutter build.
- `test/widget_test.dart` is a single 400-LOC file holding all 11 tests; no unit tests,
  no test directory structure.
- `analysis_options.yaml` is the untouched Flutter template (no extra strictness).
- `_matchReplies` round-robins 3 canned strings.
- Seed profiles use 5 Unsplash URLs of non-Muslim stock models; 3 of the 5 reuse the
  *same* photo (`photo-1560250097-0b93528c311a`).

### Issues explicitly checked and NOT found (credit where due)
- ✅ No compilation errors, no analyzer issues (`flutter analyze`: clean).
- ✅ No null-safety violations, no broken imports.
- ✅ **All controllers are disposed.** `edit_profile_screen.dart` and
  `biodata_screen.dart` initially looked suspicious (7 and 5 controllers vs 2 `dispose`
  lines) but both dispose via a loop — verified correct.
- ✅ `AppStore` cancels its `Timer`s in `dispose()`.
- ✅ Route handling is correct; back gesture works on sub-pages.
- ✅ No hardcoded secrets, API keys or credentials (there is nothing to hold secrets for).
- ✅ Tests do not hide failures; they use `HttpOverrides` properly for image loading.

---

## 7. Integrations

| Integration | Status |
|---|---|
| Backend API | **None** |
| Auth provider | **None** |
| Database | **None** (device-local `shared_preferences` only) |
| File/document storage | **None** — "uploads" only flip an enum |
| Realtime / messaging infra | **None** — replies are `Timer`s |
| Push notifications | **None** — notifications are local model objects |
| Payments / IAP | **None** |
| Analytics / crash reporting | **None** |
| Native platform channels | `privacy_shield` — Android only, iOS missing |
| Remote assets | 5 Unsplash URLs, loaded via plain `Image.network` (no caching) |

---

## 8. Baseline results (actually executed, 2026-10-26)

```
$ flutter --version
Flutter 3.47.5 • channel stable • Dart 3.13.4

$ flutter pub get
Got dependencies!
17 packages have newer versions incompatible with dependency constraints.

$ flutter analyze
No issues found! (ran in 2.0s)

$ flutter test
00:03 +11: All tests passed!
```

**Baseline = 0 analyzer issues, 11/11 tests passing.** Any regression introduced from
here is a new failure. Platform build checks (`flutter build apk` / `ios`) were **not**
run in this phase.

---

## 9. Must be preserved

1. **`go_router` configuration and the `AppRoutes` table** — the strongest asset in the repo.
2. **The design system** — `theme/app_theme.dart` tokens and all 11 `widgets/`.
3. **All 9 model classes**, their `copyWith`/`toJson`/`fromJson` — these become DTOs.
4. **`StatefulShellRoute.indexedStack`** tab-state preservation.
5. **`PrivacyShield`** + the Android `FLAG_SECURE` native implementation.
6. **The existing 11 tests** — they are the regression net.
7. **The onboarding step/draft persistence mechanism** (`_kSteps`, `_kProfile`) — resume
   on relaunch already works.
8. `stitch/` assets and `README.md` screen mapping — design provenance record.

## 10. Recommended refactoring (incremental, no rewrite)

1. Split `AppStore` into focused `ChangeNotifier`s behind repository interfaces
   (`AuthRepository`, `DiscoveryRepository`, `ProposalRepository`, `ChatRepository`,
   `VerificationRepository`) with an in-memory implementation first — this preserves
   today's demo behaviour while making a backend swappable.
2. Introduce `ProposalStatus` / `MatchStatus` enums and a transition table; replace the
   nine `Set<String>`s.
3. Keep `provider`. **Do not** migrate to Riverpod/Bloc — the audit gives no justification.
4. Move `Messages` into the shell as a 5th/7th branch.
5. Add `flutter_secure_storage` before any real token exists.
6. Split `test/widget_test.dart` into `test/unit/`, `test/widget/`.

## 11. Risks

| Risk | Severity |
|---|---|
| No backend exists; ~70% of the remaining prompt (Phases 6–9) is server-dependent | **Critical** — see `IMPLEMENTATION_PLAN.md` Stage 0 |
| Barkat's actual visual design is unverified (no screenshots obtainable) | **High** — blocks Phase 2.2/5 fidelity |
| Half the current feature set is invented and may need removal, which deletes working code | **High** — needs a product decision, not an engineering one |
| Unsplash images will break in release (no INTERNET permission) and are unlicensed for product use | Medium |
| `app_store.dart` is a single-file bottleneck for every future change | Medium |
