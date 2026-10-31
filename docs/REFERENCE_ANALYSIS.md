# Reference Product Analysis — Barkat

**Date:** 2026-10-26
**Subject:** Barkat — Muslim Matrimony App (`com.barkat.world` / App Store id6756516309)
**Method:** public web pages fetched and parsed. **No app was installed or run.**

## Evidence-grade key

Every claim below carries a grade. Nothing is asserted without one.

| Grade | Meaning |
|---|---|
| **[D]** Documented | Stated explicitly on a public Barkat page or store listing. Trustworthy. |
| **[O]** Observed | Seen directly in a screenshot or recording. |
| **[R]** Recommendation | My inference. Reasonable, **not** reference behaviour. |
| **[U]** Unknown | Cannot be determined from available access. Requires user input. |

Direct observations are in §0.

## Sources fetched

| URL | Yield |
|---|---|
| `https://www.barkatapp.com/` | High — features, nav, FAQ, positioning |
| `https://www.barkatapp.com/how-to-use` | **Highest** — the 6-step user journey |
| `https://www.barkatapp.com/about` | High — philosophy, filters, guardian access |
| `https://www.barkatapp.com/legal/verification` | High — document types, review process |
| `https://www.barkatapp.com/help` | Low — support scope only |
| App Store listing | **Highest** — IAP SKUs with real prices, privacy labels, version |
| Play Store listing | **Nil** — description did not render to text |

---

## 0. Direct observation of the real app (added 2026-10-31)

Barkat's store screenshots are public and can be downloaded. `§6` of the first version
wrongly said they could not be obtained, and every "[O]: zero claims" statement below is
out of date. Source: 10 App Store and 9 Play screenshots (v5.0.5), plus the app rendered
in Chrome at 390 px. Screens seen: Discover, Profile details, Matches, Filters
("Profile Settings"), Verification, Premium. Not seen: login, OTP, onboarding, Proposals,
Activities, Profile, chat, settings.

### Current app [O]

| Area | Observed |
|---|---|
| Bottom tabs | Discover, Proposals, Matches, Activities, Premium, Profile |
| Discover | "Assalamu Alaikum, Salman", "Introductions for you", 0/5 PROPOSALS SENT, gold-framed card, university crest, New Profile pill, 81% MATCH ring, Self managed, Beyond Caste, Marriage: Ready within 1 year, Incompatible / Send Proposal / Request Contact, Explore next profile |
| Profile details | Share and ⋮ icons, bookmark, "Active 3d ago", TAKE THE NEXT STEP, Accept Request ("They sent you an interest"), Send Message |
| Matches | Match Mode toggle, Shared Contacts / Chat Matches, Message / Unmatch |
| Filters | Age, Marriage Status, Caste, Alma Mater, Education, Profession, Location, Contact Sharing (Manual approval). Diamonds on the last three of the first six. Clear all, Apply |
| Verification | Name proof, Education proof, Good to know (10 MB, 24–48 hours, documents stay private) |
| Premium | Barkat Premium, Monthly, renewal date, 29 remaining out of 50, Buy more, Purchase history. Up to 3 active accepted matches, Daily Proposals: Unlimited, Daily Contact Requests: 5 per day |
| Privacy | "Screenshots are Not Allowed on Profiles" |

Sampled colours: canvas #F1FBF3, primary about #1A5E45, cream #F9F6EF, New Profile pill
#E4CD75. These match `lib/theme/app_theme.dart`.

### Older layout [O, likely superseded]

One App Store screenshot shows "Search Rishtey" with Suggestions / Nearby and tabs Home,
Activity, Messages, Premium, Profile. `/how-to-use` describes this layout. The other
screenshots, including one with a 2026 renewal date, show the six-tab layout, so this
looks older. That is an inference. Check it against the installed app before building it.

### First-version findings that were wrong

| Finding | Correct position |
|---|---|
| The app was built from Stitch and not reverse-engineered from Barkat | Its screens, wording and palette closely follow the real app. Stitch was only an early stage |
| The palette's "pixel-sampled" claim is unverified | The claim holds; the comment is restored |
| G-07: Messages must be a tab, and Premium as a tab has no support | Premium is a real tab. The current app has no Messages tab, so **do not move it** |
| `proposalQuota = 5` is invented | 0/5 is observed. `30` credits remains unverified (one user shows 50) |
| Caste and Contact Sharing filters are invented | Both are observed |
| G-09 / G-10: Search Rishtey and Nearby are missing P1 gaps | Probably superseded; deprioritised |
| No screenshots obtainable; all visuals Unknown | G-40 to G-45 can now be assessed for the six screens above |
| Barkat never says "wali" or "chaperone" on any page | Checked only in summaries of 5 pages, and stated for `/about` only |

Wali, chaperoned chat and meeting features were not seen in these screenshots, which
cover only part of the app. "Self managed" suggests profiles can also be managed by
someone else.

---

## 1. Product positioning [D]

- "World's 1st Educated Muslim Matrimony Platform"; hero: "AMU to Harvard, Everyone is on Barkat."
- Tagline: "Exclusive Community for Educated Muslims for Nikah."
- Logo wordmark "Barkat" alongside "بركة". Footer: "Made with Barkat in India 🇮🇳 · © 2026 Barkat."
- **Eligibility is restricted: graduates and degree students only, first-time nikah profiles only.**
- Explicitly "Nikah-focused matchmaking. Not a dating or casual chat app."
- Claimed scale: 10,000+ members (App Store description). Developer: Tahir Ahmad. Category: Lifestyle.
- Markets: India, UAE, Pakistan, UK, USA, Canada. Priority cities: Delhi NCR, Bangalore, Hyderabad, Mumbai, Aligarh.
- Current version 5.0.5; 72 MB; 13+; 4.5★ from 30 ratings; English only.

> **Implication for Nikah_App:** the reference's differentiator is *education/alma mater*,
> not guardian supervision. Our app's centre of gravity is in the wrong place.

---

## 2. The confirmed user journey — Barkat's own 6 steps [D]

Verbatim structure from `/how-to-use`.

### Step 01 — Create your profile [D]
- Sign in, then onboarding in **exactly six steps**:
  1. Basic info
  2. Personal details
  3. **Education and profession**
  4. Photos
  5. Verification
  6. Review and submit
- Prompted to add **university, city, and values** (university feeds the Alma Mater filter).
- Upload **Photo ID, degree, and profession documents** "where asked".
- **Every profile is manually reviewed before it goes live.**

### Step 02 — Search with filters [D]
- Screen is named **"Search Rishtey"**.
- Filters: **alma mater** (AMU, Jamia, IIT, JNU, AIIMS, DU, and more), **age, city, profession**.
- A **Suggestions / Nearby** toggle.
- Opening a profile shows **education, profession, community, bio**.
- From `/about`, the institution list extends to IIM, Osmania, IISc, Harvard.
- From the App Store listing, searchable attributes are: **education, profession, city,
  country, age, sect, marital status, lifestyle preferences**.

### Step 03 — Send a proposal [D]
- From **Discover**, tap the **heart labelled "Send Proposal"**.
- **"Mark Incompatible"** skips a profile.
- **"Request Contact"** when ready for a call with family involved.
- "Photos and contact stay under your control until both sides are ready."
- Proposals are limited to "a limited number" per period — **[U] the exact number is not published**.

### Step 04 — Match when both accept [D]
- **"A match happens only when interest is mutual."**
- Accept an incoming proposal with a **checkmark**, or **decline** it.
- **"Message"** starts the conversation.
- "Sharing is family-first: more information is shared only when both sides agree."

### Step 05 — Chat with intent [D]
- Chats live under **"Messages" in the bottom navigation**.
- **Chat unlocks after a match and is free** (`/about`).
- Users are encouraged to keep early conversations on-platform.
- **Report or block from the profile menu.**

### Step 06 — Family access [D]
- Add **family type, family members, and a short family summary** to the profile.
- **Link a parent or guardian phone during onboarding if they manage the search.**
- `/about`: "Guardian and parent access so families can participate without turning nikah
  into a public feed."
- `/about` does not use the words "wali" or "chaperone".
- **[U] How guardian access actually works is not documented.** `/how-to-use` explicitly
  declines to explain the mechanics.

---

## 3. Verification [D] — `/legal/verification`

Documents accepted (**only when the user submits them** — submission is optional):
- **Identity:** government photo ID — Aadhaar, passport, or driving licence.
- **Education:** degree certificates, mark sheets, or university ID.
- **Employment/profession:** employment letter, professional registration, or business proof.
- **Profile quality** (not a document): photos, bio completeness, marriage intent, guideline compliance.

Process:
- **Barkat's team manually reviews profiles before they go live.**
- Reviewers check submitted materials *and* profile content.
- **Reports of suspicious profiles are reviewed within 24 hours.**
- Passing profiles "may show a badge in the app."
- The policy states a badge means the team checked submitted materials — it does **not**
  guarantee every self-written detail.

Explicitly **not** verified: criminal/police checks, family background, character
references, financial status, accuracy of all free-text fields.

**[U]** Pending/approved/rejected state names, rejection reason surfacing, resubmission
flow, and document retention policy are all undocumented.

> **Critical implication:** verification is a **human review queue**. A client that
> approves its own documents (our `approveVerificationDoc`) is not a weak implementation
> of this — it is the opposite of it.

---

## 4. Monetisation [D] — the strongest hard data we have

Barkat's web pages publish **no prices** ("prices shown in the app before purchase").
The **App Store listing enumerates the actual IAP SKUs**:

| SKU name | Price (INR) |
|---|---|
| Barkat Monthly | ₹2,499 |
| Barkat Premium Weekly | ₹999 |
| Barkat Credits Pack Small | ₹499 |
| Barkat Credit Single | ₹99 |
| Barkat Contact Reveal | ₹99 |
| Barkat Pending Limit Increase | ₹99 |
| Barkat Daily Intro Limit Increase | ₹99 |
| Barkat Unlock Profile | ₹49 |
| Unlock Single Profile Message | ₹49 |

Free tier [D]: creating a profile, browsing, **View Profile, Send Proposals, Chats** are
marked "Free" on the homepage. Chat after match is free.

What the SKU names prove about mechanics [D]:
- A **credits** currency exists ("Barkat Credits", introduced in a prior release note).
- **Contact reveal is a paid, per-use action.**
- There is a **daily intro limit** and a **pending(-proposal) limit**, both independently
  purchasable as increases. This confirms two distinct quotas exist.
- Per-profile unlock and per-profile message unlock exist.
- A membership tier is branded **"Barkat Exclusive membership"** (homepage).

**[U] The actual numeric values of the daily intro limit and pending limit.** Our app's
`proposalQuota = 5` and `monthlyContactCredits = 30` are **invented numbers** with no
reference support. They must be made server-configurable rather than guessed.

**[D] Release notes mention:** recommendation improvements, chat, contact-sharing,
verification improvements, **events**, and Barkat Credits. "Events" is a feature our app
has no equivalent of — **[U]** nature unknown.

---

## 5. Privacy & data (App Store privacy labels) [D]

Developer-declared. **Used to track across apps:** Identifiers, Usage Data.
**Linked to the user:** name, email, phone; user content (messages, photos/videos);
coarse location; device ID; advertising data.
Purposes: advertising/marketing, analytics, personalisation, app functionality.

> Confirms the real app collects coarse **location** — consistent with the "Nearby"
> discovery mode. Our app has no location handling at all.

Other confirmed account/safety surfaces [D]:
- **Delete account** is a first-class flow (footer link + `/help`).
- Support email `mariyam@barkatapp.com`; safety reports use subject "safety".
- Support cannot share another member's private data or override a family's decision.
- "Support will not ask for passwords or OTPs by email" — **implies OTP-based auth exists [D-weak]**.

---

## 6. Visual reference analysis — superseded by §0

Phase 2.2 asked for screen dimensions, colours, typography, weights/sizes, spacing,
radii, button states, app bar/bottom nav, icons, card layouts, scroll behaviour, and
empty/loading/error/success states, with **screenshots as the source of truth.**

**No screenshots were obtainable.** Both store listings returned image placeholders when
fetched as text; neither marketing site exposes in-app captures beyond one described
caption ("Barkat introductions screen with a curated profile, alma mater, verification
badge, and request contact").

Per the project's own non-negotiable rule — *"Do not invent exact colors, dimensions, or
animations when they cannot be observed"* — I am recording the following as **[U]** and
will not guess:

| Attribute | Status |
|---|---|
| Brand colours (exact hex) | **[U]** |
| Typography family, weights, sizes | **[U]** |
| Spacing scale, border radii | **[U]** |
| App bar / bottom nav design and tab icons | **[U]** (names [D], visuals [U]) |
| Profile card layout and imagery treatment | **[U]** |
| Empty / loading / error / success states | **[U]** |
| Transitions and animations | **[U]** |
| Modal sheets and dialogs | **[U]** |

**What our repo currently claims:** `lib/theme/app_theme.dart:3-10` states the palette was
"reverse-engineered from the Barkat app (Play Store screenshots, pixel-sampled)" with
per-constant sampled hex annotations. `README.md` instead attributes the palette to Google
Stitch, citing different values. **This provenance claim is unverified and internally
contradicted; it should not be treated as reference fidelity.** I recommend correcting the
comment to state its true origin.

**To unblock:** the single highest-value thing you can provide is a **screen recording or
a set of screenshots** of the installed Barkat app covering: splash/login, OTP, the six
onboarding steps, Search Rishtey + filter sheet, Discover card, profile detail, proposals
(sent + received), matches, Messages list + a conversation, family access, settings, and
the premium/paywall screen. Everything in Phase 5 and the visual half of Phase 3 depends
on it.

---

## 7. Feature matrix: Barkat (confirmed) vs Nikah_App (actual)

| # | Barkat feature | Grade | In Nikah_App? |
|---|---|---|---|
| 1 | Six-step onboarding (basic/personal/edu+prof/photos/verification/review) | [D] | Partly — 6 steps exist but step 3 is "Islamic Practice" and step 5 is "Wali", not the reference's |
| 2 | Graduate-only eligibility gate | [D] | **Missing** |
| 3 | "Search Rishtey" keyword/filter search screen | [D] | **Missing** (filters sheet only) |
| 4 | Alma Mater filter with named institutions | [D] | **Partial** — `almaMater` field exists |
| 5 | Suggestions / Nearby toggle | [D] | **Missing** (no location at all) |
| 6 | Filters: age, city, **country**, profession, education, **sect**, marital status, lifestyle | [D] | **Partial** — no country, no sect |
| 7 | Discover card with heart = "Send Proposal" | [D] | ✅ Present |
| 8 | "Mark Incompatible" | [D] | ✅ Present |
| 9 | "Request Contact" | [D] | ✅ Present (but auto-accepted by a fake timer) |
| 10 | Mutual-only matching | [D] | **Broken** — one-sided actions create matches |
| 11 | Incoming proposal accept (✓) / decline | [D] | **Broken** — unreachable dead code |
| 12 | Messages in bottom navigation | [D] | **Missing from nav** — routed outside the shell |
| 13 | Chat unlocked by match, free | [D] | Partial — gated on invented wali approval |
| 14 | Report **and block** from profile menu | [D] | **Missing** — snackbar only |
| 15 | Manual human verification before profile goes live | [D] | **Inverted** — client self-approves |
| 16 | ID / degree / profession document upload | [D] | **Partial** — no real file picker or storage |
| 17 | Verification badge from review | [D] | **Partial** — self-granted |
| 18 | Family type, members, family summary on profile | [D] | **Partial** — different shape |
| 19 | Link parent/guardian phone during onboarding | [D] | ✅ Present (over-built) |
| 20 | Credits currency | [D] | **Partial** — invented 30/month figure |
| 21 | Contact Reveal as paid action | [D] | **Missing** as a purchase |
| 22 | Daily intro limit + pending limit (two quotas, purchasable increases) | [D] | **Partial** — one invented 5/day quota |
| 23 | Membership (Monthly ₹2,499 / Weekly ₹999) | [D] | **Fabricated** — fake active subscription |
| 24 | Unlock profile / unlock single message | [D] | **Missing** |
| 25 | Delete account | [D] | **Missing** |
| 26 | Coarse location collection | [D] | **Missing** |
| 27 | "Events" | [D] | **Missing** (nature [U]) |
| 28 | Push notifications | [U] | **Missing** (local models only) |
| 29 | OTP authentication | [D-weak] | **Missing** |

### Features in Nikah_App with NO reference support (invented)

| Nikah_App feature | Files | Reference support |
|---|---|---|
| **Wali SMS verification portal** (6-digit guardian passcode) | `wali_sms_portal_screen.dart` (381 LOC) | **None** |
| **Wali & Privacy Hub** | `wali_hub_screen.dart` (422 LOC) | **None** |
| **Chaperoned chat** — a third "Chaperone" message sender auditing threads | `chat_screen_parts.dart`, `chat_message.dart` | **None.** Barkat says chat is free after match; no supervision described |
| **Wali approval gate** on introductions | `app_store.dart` `requestIntro`/`approveIntro` | **None.** Barkat gates on *mutual member consent*, not guardian approval |
| **Family meeting scheduler** (video/audio/in-person) | `schedule_meeting_screen.dart` (477 LOC) | **None** |
| **Islamic Practice onboarding step** (prayer/sect/practice tags) | `islamic_practice_screen.dart` | Sect is a [D] *filter*; a dedicated practice step is not documented |
| **Honour pledge checkboxes** | `create_account_screen.dart` | **None** |
| **"Modesty blur"** photo filter | `settings_screen.dart`, `app_images.dart` | Barkat has "privacy-first photo options" [D]; blur specifically is **[U]** |
| Caste filter | `filters.dart` | Barkat documents "community" [D]; "caste" wording is **[U]** |

> ~2,100 LOC of working, polished code implements features the reference does not have.
> **This is a product decision, not an engineering one** — see the open question in
> `IMPLEMENTATION_PLAN.md` §0.

---

## 8. Honest summary of what remains unknown [U]

1. **All visual design** (§6) — the biggest gap.
2. Numeric values of the daily intro limit and pending-proposal limit.
3. Guardian-access permission model — what a linked parent can actually see or do.
4. Verification state names, rejection-reason surfacing, resubmission.
5. Auth method: OTP vs password vs social (OTP inferred only from a support disclaimer).
6. Whether "Nearby" uses device GPS or a stated city.
7. What "Events" is.
8. Whether the Play Store and iOS feature sets differ.
9. Server-side matching/recommendation logic ("Curated profiles everyday").
10. Entitlements attached to each IAP SKU.

## Sources

- [Barkat — home](https://www.barkatapp.com/)
- [Barkat — How to use](https://www.barkatapp.com/how-to-use)
- [Barkat — About](https://www.barkatapp.com/about)
- [Barkat — Verification policy](https://www.barkatapp.com/legal/verification)
- [Barkat — Help](https://www.barkatapp.com/help)
- [App Store — Barkat Muslim Matrimony App](https://apps.apple.com/in/app/barkat-muslim-matrimony-app/id6756516309)
- [Google Play — com.barkat.world](https://play.google.com/store/apps/details?id=com.barkat.world) (description did not render)
