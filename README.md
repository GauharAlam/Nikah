# Barkat Nikah - Muslim Matrimony Flutter App

**Barkat Nikah** is a modern, dignity-first Islamic matrimony application built with **Flutter 3.47+**, adhering to authentic Islamic principles: guardian (**Wali**) oversight, photo modesty controls, verified biodata, and chaperoned communications.

---

## 📱 Stitch Project & Screens

- **Project Title:** Muslim Matrimony Android App
- **Project ID:** `12993025574453771195`

### Complete Inventory of Screens (11 Screens)

| # | Screen Name | Screen ID | Screenshot | HTML Source | Flutter Screen |
|---|---|---|---|---|---|
| 1 | **Chaperoned Match Chat** | `d29f200d474f...` | [1_chaperoned_match_chat.png](stitch/images/1_chaperoned_match_chat.png) | [1_chaperoned_match_chat.html](stitch/html/1_chaperoned_match_chat.html) | [chat_screen.dart](lib/screens/chat_screen.dart) |
| 2 | **Wali & Privacy Hub** | `6ffa154358c2...` | [2_wali_privacy_hub.png](stitch/images/2_wali_privacy_hub.png) | [2_wali_privacy_hub.html](stitch/html/2_wali_privacy_hub.html) | [wali_hub_screen.dart](lib/screens/wali_hub_screen.dart) |
| 3 | **Detailed Profile View** | `be0fbfc42791...` | [3_detailed_profile_view.png](stitch/images/3_detailed_profile_view.png) | [3_detailed_profile_view.html](stitch/html/3_detailed_profile_view.html) | [profile_screen.dart](lib/screens/profile_screen.dart) |
| 4 | **Discovery & Matches** | `b3c1699b4796...` | [4_discovery_matches.png](stitch/images/4_discovery_matches.png) | [4_discovery_matches.html](stitch/html/4_discovery_matches.html) | [discovery_screen.dart](lib/screens/discovery_screen.dart) |
| 5 | **Wali Onboarding & Verification** | `59ec4818d547...` | [5_wali_onboarding.png](stitch/images/5_wali_onboarding.png) | [5_wali_onboarding.html](stitch/html/5_wali_onboarding.html) | [wali_onboarding_screen.dart](lib/screens/wali_onboarding_screen.dart) |
| 6 | **Schedule Family Meeting** | `b42f85ffffd5...` | [6_schedule_family_meeting.png](stitch/images/6_schedule_family_meeting.png) | [6_schedule_family_meeting.html](stitch/html/6_schedule_family_meeting.html) | [schedule_meeting_screen.dart](lib/screens/schedule_meeting_screen.dart) |
| 7 | **Wali SMS Confirmation Portal** | `aadbd61e01ab...` | [7_wali_sms_portal.png](stitch/images/7_wali_sms_portal.png) | [7_wali_sms_portal.html](stitch/html/7_wali_sms_portal.html) | [wali_sms_portal_screen.dart](lib/screens/wali_sms_portal_screen.dart) |
| 8 | **Matches & Introductions Hub** | `65e354fa85ce...` | [8_matches_introductions_hub.png](stitch/images/8_matches_introductions_hub.png) | [8_matches_introductions_hub.html](stitch/html/8_matches_introductions_hub.html) | [matches_hub_screen.dart](lib/screens/matches_hub_screen.dart) |
| 9 | **Welcome & Halal Intentions Landing** ⭐ *(New)* | `854e5f33eb07...` | [9_welcome_intentions_landing.png](stitch/images/9_welcome_intentions_landing.png) | [9_welcome_intentions_landing.html](stitch/html/9_welcome_intentions_landing.html) | [welcome_intentions_screen.dart](lib/screens/welcome_intentions_screen.dart) |
| 10 | **Create Account & Intentions (Step 1)** ⭐ *(New)* | `ab494fbe057c...` | [10_create_account_intentions.png](stitch/images/10_create_account_intentions.png) | [10_create_account_intentions.html](stitch/html/10_create_account_intentions.html) | [create_account_screen.dart](lib/screens/create_account_screen.dart) |
| 11 | **Sign In (Phone & Email Toggle)** ⭐ *(New)* | `2abb82bb2584...` | [11_signin_phone_email_toggle.png](stitch/images/11_signin_phone_email_toggle.png) | [11_signin_phone_email_toggle.html](stitch/html/11_signin_phone_email_toggle.html) | [signin_screen.dart](lib/screens/signin_screen.dart) |

---

## 🏗️ Flutter Codebase Architecture

The app is built in Flutter using Material 3 and Google Fonts (Plus Jakarta Sans):

- **[lib/main.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/main.dart)**: App entry point and theme setup.
- **[lib/theme/app_theme.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/theme/app_theme.dart)**: Stitch design tokens (*Deep Emerald* `#012D1D`, *Sage* `#006C48`, *Gold* `#F7E7B4`, and *Warm Ivory* `#FDFBF7`).
- **[lib/screens/](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/)**:
  1. [welcome_intentions_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/welcome_intentions_screen.dart): Welcome landing with Quran 30:21 verse, 4 pillars of sacred matrimony, and entry points.
  2. [create_account_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/create_account_screen.dart): Step 1 of 4 onboarding with intention designation (Myself, Daughter/Sister, Son/Brother), basic credentials, and Islamic honor pledge.
  3. [signin_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/signin_screen.dart): Phone SMS 2FA and email/password switcher with biometric support, social passkeys, and direct Wali portal access.
  4. [discovery_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/discovery_screen.dart): Halal match discovery card, modesty blur toggle, and Islamic practice chips.
  5. [profile_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/profile_screen.dart): Detailed biodata, sectarian practice, guardian verification badges, and auth shortcuts.
  6. [chat_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/chat_screen.dart): Active chaperone banner, Islamic icebreakers, read receipts, and simulated responses.
  7. [wali_hub_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/wali_hub_screen.dart): Guardian management dashboard with modesty toggles and audit logs.
  8. [wali_onboarding_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/wali_onboarding_screen.dart): Step 3 of 4 guardian designation (Father, Brother/Uncle, Imam), contact details form, permission toggles, and SMS invite dispatch.
  9. [schedule_meeting_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/schedule_meeting_screen.dart): Virtual Video, Audio, or In-Person family meeting scheduler with verified Wali representation.
  10. [wali_sms_portal_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/wali_sms_portal_screen.dart): 6-digit SMS passcode verification portal for guardians with Arabic language toggle.
  11. [matches_hub_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/matches_hub_screen.dart): Central hub for mutual matches, intro requests, upcoming chaperone milestones, and pending inquiries.
  12. [main_navigation_screen.dart](file:///Users/gauharalam/Documents/Projects/Nikah_App/lib/screens/main_navigation_screen.dart): Bottom navigation coordinator with deep links across all 11 screens.

---

## 🚀 Running and Testing

```bash
# Verify static analysis & tests (0 errors, 100% passing across 4 test suites)
flutter analyze
flutter test

# Run Web (Chrome)
flutter run -d chrome

# Run Desktop (macOS)
flutter run -d macos
```

---

## 📱 Interactive Mobile Simulator

Open and interact with all 11 screens inside the live simulator:
- [emulator.html](file:///Users/gauharalam/.gemini/antigravity/brain/78744f8d-797a-4ee9-b837-65303cc1ebe9/emulator.html)
- [index.html](file:///Users/gauharalam/Documents/Projects/Nikah_App/index.html)
