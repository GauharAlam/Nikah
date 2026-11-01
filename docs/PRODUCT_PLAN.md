# Product Plan: How We Differ From Barkat

**Date:** 2026-11-01

**The idea in one line:** the Muslim marriage app where every profile is ID-checked, nobody
pays unless the other person says yes, and the app helps you all the way to nikah rather
than stopping at a match.

Barkat's strength is education and manual review. We keep manual review. We differ on trust,
fairness, dignity and what happens after a match.

## What the research found

| Finding | Strength | Source |
|---|---|---|
| India's cybercrime centre warned that fake matrimony profiles are used for emotional manipulation, money requests and crypto schemes, on the biggest platforms | Strong | [ETV Bharat on the I4C advisory](https://www.etvbharat.com/amp/en/bharat/i4c-detects-two-latest-cyber-crime-trends-in-india-enn25112703639) |
| 78% of women surveyed had met fake profiles on matchmaking apps (1,000 singles, eight cities) | Medium: one private poll | [SheThePeople](https://www.shethepeople.tv/news/fake-profiles-matchmaking-apps-survey-matrimony-app-scams-6950352) |
| Fake profiles are the top complaint on Muslim apps, along with profiles still promoted while inactive | Medium: self-selected reviews | [Muzz on Trustpilot](https://ca.trustpilot.com/review/muzz.com), [SingleMuslim on Trustpilot](https://ch.trustpilot.com/review/singlemuslim.com) |
| Members resent paying just to message, and report refund problems | Medium: individual reviews | [Pure Matrimony](https://spark.mwm.ai/it/apps/pure-matrimony/1132189906), [Sunnah Match](https://ie.trustpilot.com/review/sunnahmatch.com) |
| Parent-run matchmaking can leave young people with little say | Medium: reporting, 2015 | [NPR](https://www.npr.org/transcripts/453988763) |
| Stigma around divorce persists, more so for women, and community bureaus exist just for this group | Weak to medium: older, small sources | [New Age Islam](https://newageislam.com/islam-women-feminism/a-new-match-making-initiative/d/8168) |
| Marriage restrictions are central to caste among Indian Muslims | Medium: academic, no survey of app preferences | [La Vie des idées](https://laviedesidees.fr/IMG/pdf/20140929_castesmusulmans_delage.pdf) |
| Pre-marital counselling is highly recommended; question lists cover deen, money, mahr, children and roles | Medium: scholarly Q&A plus guides | [Darul Iftaa Birmingham](https://islamqa.org/hanafi/daruliftaa-birmingham/136831/what-are-the-guidelines-before-marriage/), [Islamic Foundation questionnaire](https://islamicfoundation.org/pdf/if-premarital-questionnaire.pdf) |

**What we did not find:** any large survey of what Indian Muslim users want from a marriage
app. Everything above is indirect, so talk to 10 to 20 real families before spending on
marketing.

## Legal requirements (get these checked by a lawyer)

| Requirement | Source | What we do |
|---|---|---|
| Matrimonial sites should collect ID and address proof, confirm marriage intent and that details are correct, and warn users about fraud | [2016 advisory, as reported](https://www.governancenow.com/news/regular-story/identity-address-proofs-mandatory-using-matrimonial-websites) | ID required, intent confirmed, Safety Centre. Address proof is not collected yet |
| Possible one-year IP log retention | [Press report only](https://www.tribuneindia.com/news/archive/nation/shaadi-sites-must-verify-users-with-valid-ids-246236) | Not built. Needs the advisory's actual text |
| DPDP Rules were notified in November 2025, with main duties due around May 2027; consent must be explicit | [Law-firm summary](https://www.mondaq.com/india/data-protection/1708164/digital-personal-data-protection-rules-2025-notified) | Explicit consent at submission, deletion, no accounts under 18 |
| Stores require report and block, and Apple requires published contact details | [Google Play](https://support.google.com/googleplay/android-developer/answer/12923286), [Apple](https://developer.apple.com/app-store/review/guidelines/) | Report and block built. Contact details needed before release |

## Features

Each item says what it does and why. **Now** means it is being built in this round.

### Trust

| Feature | How it differs | When |
|---|---|---|
| **ID required to go live** | Barkat treats documents as optional. Ours need name proof before review | Now |
| **Scam Shield** | Warns the reader when a message mentions money, investment, crypto or moving off the app | Now |
| **Safety Centre** | Common scams, what to do, how to report to cybercrime.gov.in or call 1930 | Now |
| **Automatic hold** | Three different members reporting someone hides that profile until a reviewer looks | Now |
| **What was checked** | The profile lists which documents passed, and says what is not checked | Now |
| **Real activity** | Real "active 3d ago". Inactive profiles leave discovery | Now |
| Selfie match to ID | Needs a paid verification vendor | Later |

### Fairness

| Feature | How it differs | When |
|---|---|---|
| **Pay only for a yes** | A contact credit returns if the request is declined or expires | Now |
| **Free chat after match** | Same as Barkat; never paywalled | Done |
| Plain refund page | Complaints elsewhere are about refunds | Before launch |

### Privacy and dignity

| Feature | How it differs | When |
|---|---|---|
| **Photos after match** | A member can keep photos hidden until matched, enforced on the server | Now |
| **Caste is optional** | Barkat requires it. Ours has "Prefer not to say" and can be hidden | Now |
| **Divorced and widowed members** | Treated as ordinary members, with a children field. Barkat's website says first-time nikah only | Now |
| **Family profiles need consent** | Whoever creates a profile for someone confirms that person agreed | Now |
| **Share with family** | Sends a short summary with no photo or contact, only if that member allows it | Now |

### Beyond the match

| Feature | How it differs | When |
|---|---|---|
| **Nikah Journey** | Shared steps after a match: talk, families meet, istikhara, decision | Now |
| **Important Questions** | Both answer questions on deen, money, mahr, children and family. Answers show only after you answer | Now |
| **Deen and values** | Optional prayer, Quran and lifestyle details on the profile, plus a sect filter | Now |
| Family Circle | A linked parent with limited access. Needs its own permission design | Next |
| Scholar and counsellor directory | Needs real partners | Later |

## Decisions for you

1. **Graduates only?** This is Barkat's core position. Opening to everyone would make us
   clearly different but less focused. It is now a server setting (`graduatesOnly`) and stays on.
2. **ID required from day one?** Stronger trust, but fewer sign-ups. It is a server setting
   (`requireIdProof`) and is on.
3. **Religious content:** the app gives no rulings. Have a scholar review the Journey and
   question wording before launch.
4. **Name and brand:** still needed before Firebase setup.
