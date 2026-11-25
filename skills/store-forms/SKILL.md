---
name: store-forms
description: Draft the answers for the store forms that describe an app — Google Play Data safety, Advertising ID, App access, Ads, Target audience, content rating hints, and Apple App Privacy labels, tracking, export compliance and App Review Information — from what the project and its SDKs actually do, and check them against the privacy policy. Produces a copy-ready STORE_FORMS.md; nothing is entered into a console. Use before a first release, after adding or removing an SDK (ads, analytics, crash reporting, sign-in, location), or when asked "Data safety'yi nasıl dolduracağım", "App Privacy formu", "what do I declare".
---

# Store forms

Goal: forms that match the app. A form that says "no data collected" while an ads or crash SDK is installed, or that disagrees with the privacy policy, is one of the most common reasons for a Play removal or an App Review rejection. Talk to the user in their language; write the answers in English (the consoles' language) with the console's own labels.

**Read-only.** Do not change the project. The only file you write is `STORE_FORMS.md` — in `<project>/build/reports/store-forms/` when git ignores that folder (`git check-ignore -q build/reports`), otherwise in a folder outside the project, or where the user asks.

This skill uses the scripts and guides of the **flutter-store-ready** skill installed next to it (`<kit>` = `<this skill's folder>/../flutter-store-ready`) and `DATA-DECLARATIONS.md` in this folder.

## 1. Collect the facts

**Existing drafts first.** Look for earlier answers in the repository (files mentioning "Data safety", "App Privacy", "App Store Connect", "veri güvenliği" …). Compare them with the code at the end and list what is outdated — an old draft that someone copies again is the biggest risk.

**Flutter: run the audit** (it gathers most facts):

```sh
dart run <kit>/scripts/project_report.dart <project> --skip-gates --out <report folder>
```

Read from `findings.json` / the reports: "Data your SDKs collect", sign-in and account deletion, permissions, tracking prompt and `NSUserTrackingUsageDescription`, `ITSAppUsesNonExemptEncryption`, ads and purchases. The Play report reads the **merged** manifest (what plugins add, `AD_ID`) only if a release build exists; if there is none, or the bundle is older than the code (the report says so), mark those answers "verify on the next build". Exit code 1 only means blocking items were found.

**Then read the code** (any project type):

| Question | Where |
|---|---|
| What leaves the device? | Every network call: your API (which fields?), SDKs. Data that never leaves the device is **not** "collected" in either store's terms |
| Which SDKs, configured how — and on which platform? | Dependencies; their init code. An SDK in the dependencies that is never started on one platform (e.g. ads disabled on iOS) collects nothing there: answer per store |
| Is anything linked to a person? | Sign-in, user ids sent with events, crash reports, ad requests (e.g. a custom user id for rewarded-ad verification) |
| Tracking (Apple) / sharing (Google)? | Ads and attribution SDKs and their settings (personalized or not, ATT prompt or not); data sent to third parties other than service providers |
| Can users delete their data? | In-app deletion, web deletion URL, what the backend keeps after deletion (logs, tokens, rows with `ON DELETE SET NULL`) |
| Who is the app for? | Content, age gate, school levels, "kids" wording, the audience the user intends (`<kit>/STORE-POLICIES.md` section 9) |
| What does the server keep? | If the backend is in reach, its models and logging (IP addresses, retention). Otherwise ask |

## 2. Map facts to answers

Use `DATA-DECLARATIONS.md`: the definitions both stores use and what common SDKs collect. Each SDK's own data-disclosure page is the authority; when you cannot read it (offline), say once at the top of the file that SDK rows follow `DATA-DECLARATIONS.md` and must be checked against the vendor pages — do not mark every row.

Mark only the answers that depend on something you could not see with **(confirm)** and say what to check. Server-side facts you could not read (retention, other processors, encryption at rest) are questions for the user, not guesses.

## 3. Write STORE_FORMS.md

In console order:

**Google Play Console → App content**
1. Privacy policy — URL (public HTTPS, not a PDF).
2. App access — "all functionality available without special access", or the test account instructions (no real password in the file: "enter in Play Console").
3. Ads — contains ads: yes / no.
4. Content rating — the questionnaire answers that matter for this app (user interaction, user-generated content, location sharing, digital purchases, gambling-like mechanics), each with a reason.
5. Target audience and content — age groups; if under 13 is included, what the Families policy then requires (`<kit>/STORE-POLICIES.md` section 9).
6. Data safety —
   - a table: data type | collected | shared | ephemeral | required / optional | purposes | source (your server or which SDK) | evidence (`file:line`). "Optional" means the user can use the app without providing it; if the same type is required for one feature and optional for another, it is required;
   - encrypted in transit (check cleartext settings — `usesCleartextTraffic`, `http://` URLs — before answering yes);
   - account creation and deletion: how accounts are created, the in-app deletion path and the web deletion URL (confirm the current form fields in Play Console).
7. Advertising ID — yes / no and purposes; must match `AD_ID` in the merged manifest.
8. Other declarations that apply (financial features, health, government, news, VPN …) or "none apply".

**App Store Connect**
1. App Privacy — a table: data type | linked to the user | used for tracking | purposes | evidence. A data type is "linked" if **any** collection of it is linked. Then: tracking answers vs the ATT prompt; App Privacy vs `PrivacyInfo.xcprivacy` (the collected-data types there should match).
2. Export compliance — `ITSAppUsesNonExemptEncryption`: what the code uses (HTTPS / OS crypto only, or its own encryption). A legal declaration: give the facts, the user decides.
3. App Review Information — sign-in needed? demo account instructions; review notes for anything not obvious (permissions, hardware, region, features disabled on iOS).
4. Age rating — the questionnaire answers that matter, with reasons.

**Consistency**
- Every declared data type against the privacy policy (in-app legal text or its URL): missing or contradicting sentences, with suggested wording. Check the specific claims too ("guests send nothing", "nothing is kept after deletion").
- Play answers against Apple answers — the same data, unless an SDK runs on one platform only (say which).
- Earlier drafts found in the repository: what is outdated.
- Open questions for the user.

In chat, in the user's language: the 3–5 answers to double-check first (the ones a hurried form usually gets wrong for this app), and where the file is.

## Never

- Enter anything into Play Console or App Store Connect, or tell the user a form is "done" — these are drafts the user reviews and submits.
- Declare "no data collected" because the app has no server: SDKs collect.
- Decide legal questions (export compliance, children's privacy, sensitive categories) for the user — give the facts and the rule.
