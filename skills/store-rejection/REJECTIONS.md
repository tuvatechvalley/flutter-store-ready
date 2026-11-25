# Common rejections: where to look, what fixes them

A map from the rule cited in the message to the place in the project and the usual fix. It is a starting point, not the rule itself: read the current text before replying — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Play Developer Policy Center](https://play.google.com/about/developer-content-policy/). Guides referenced below (`<kit>/…`) belong to the flutter-store-ready skill.

## Apple App Review

| Cited | What it usually means | Where to look | Typical fix | Path |
|---|---|---|---|---|
| 2.1 App Completeness — crash / bug | Crash or broken screen on the reviewer's device (often iPad, a fresh install, no network, or a newer iOS) | Crash log from App Store Connect / Xcode Organizer; start-up code; screens the reviewer named; `<kit>/ERROR-HANDLING.md` | Fix the crash; test on a fresh install, iPad, offline | New build |
| 2.1 — Information Needed | Reviewer could not sign in or reach a feature | App Review Information in App Store Connect; sign-in flow; region or invite gates | Working demo account with sample data, no SMS / e-mail code; steps in the review notes | Reply, no build |
| 2.1 — placeholder / incomplete | "Lorem ipsum", empty screens, "coming soon", broken links | Strings, empty states, settings links | Remove or finish; empty states explain what to do | New build |
| 2.3 Accurate Metadata | Screenshots, description or name do not match the app; features described that do not exist | Store listing in App Store Connect | Update the listing to the real app | Console, no build |
| 2.3.10 | Other platforms mentioned ("Android", "Google Play") in the app or listing | `.arb` / string files, store text, screenshots | Remove platform names on iOS | Console or new build |
| 2.3.1 Hidden features | Behavior differs for reviewers, or a feature unlocks remotely | Remote config, "review mode" flags | Remove the gating; describe every feature in review notes | New build |
| 2.5.4 Background modes | `UIBackgroundModes` without a visible feature that needs it | `Info.plist` / `app.json` `ios.infoPlist` | Remove the mode, or explain and show the feature (video) | New build or reply |
| 3.1.1 In-App Purchase | Digital content / features / currency sold outside Apple IAP, or links to an outside purchase | Payment SDKs (Stripe, PayPal, iyzico), web checkout links | Use IAP for digital goods; physical goods and services may stay | New build |
| 3.1.1 / 3.1.2 — restore, terms | The app sells subscriptions or non-consumables, and has no "Restore purchases", or the paywall lacks price, period, auto-renew terms, Terms (EULA) and Privacy links | Paywall screen, settings; App Store Connect → App Information (Privacy Policy URL, License Agreement / EULA) and the subscription's metadata | `<kit>/STORE-POLICIES.md` section 1; fill the App Store Connect fields | New build and/or console |
| 3.1.2 cited, but the code sells no auto-renewable subscription | A product is configured as a subscription in App Store Connect, or a screen looks like one (a subscription *tracker*, "premium" wording), or the reviewer generalised | The product **types** in App Store Connect (ask the user — the code cannot show them); screens that mention subscriptions; the product ids in the code | Ask the user first. No subscription product → reply explaining the purchase type and where it is; a stray subscription product → remove it or fix its metadata | Reply, or console |
| 4.0 Design / 4.2 Minimum Functionality | App is a wrapped website, too thin, or looks broken (iPad layout, large text) | WebView-only screens; iPad and large-text layouts | Native value beyond the site; fix layouts (`<kit>/RESPONSIVE-AND-LARGE-TEXT.md`) | New build |
| 4.3 Spam | Many near-identical apps (white-label, templates) | Other apps from the same account | Merge into one app, or show clear differences | Reply or new build |
| 4.8 Login Services | Third-party login (Google, Facebook …) without an equivalent privacy-focused option | Sign-in screen, dependencies | Add Sign in with Apple (or a compliant alternative); not needed for company-only accounts | New build |
| 5.1.1 — permission text | Purpose string vague or missing; permission asked before it is needed | `Info.plist` `NS…UsageDescription`; where the prompt is triggered | Specific purpose string; ask at the moment of use (`<kit>/NAVIGATION-AND-LIFECYCLE.md` section 4) | New build |
| 5.1.1 — data not needed | App requires personal data unrelated to its function, or sign-up before any value | Sign-up form, onboarding | Make fields optional; let users try before signing up | New build |
| 5.1.1(v) Account deletion | Accounts can be created but not deleted in the app (or only "e-mail us") | Settings / profile; backend delete endpoint | In-app delete that really deletes; describe it in the privacy policy | New build |
| 5.1.2 Data Use and Sharing | Tracking without the ATT prompt, or App Privacy answers say "tracking" without the prompt | Ad / attribution SDK start-up; `NSUserTrackingUsageDescription`; App Privacy labels | Show ATT before tracking, or configure SDKs not to track and fix App Privacy | New build and/or console |
| 1.2 User-Generated Content | Users see others' content with no report, block, filtering or contact | Chat, comments, profiles, feeds | Report + block + filter + published contact (`<kit>/STORE-POLICIES.md` section 3) | New build |
| Privacy manifest (ITMS-91053 and similar e-mails) | Required-reason API used without a reason in `PrivacyInfo.xcprivacy`, or an SDK without its manifest | `ios/Runner/PrivacyInfo.xcprivacy`; SDK versions | Add the reasons; update SDKs that now ship manifests | New build |

## Google Play

| Cited policy | What it usually means | Where to look | Typical fix | Path |
|---|---|---|---|---|
| User Data — Data safety | The form does not match what the app or its SDKs collect or share | The **merged** manifest (`AD_ID`, permissions plugins add — a local build may be stale: compare with Play Console → App bundle explorer); dependencies (ads, analytics, crash, push, sign-in); network calls; push tokens sent to your server | Correct the form — **store-forms** drafts it; also check the Advertising ID row below | Console, no reply needed |
| User Data — prominent disclosure | Personal or sensitive data collected without an in-app explanation and consent first | Location, contacts, photos, installed apps; first-run flow | Disclosure screen before the permission / collection, with accept and decline | New build |
| User Data — privacy policy | Policy missing, unreachable, a PDF, or not covering the data collected | Store listing URL, in-app link | Public HTTPS page that matches the app | Console (and build if the in-app link is wrong) |
| Account deletion | Accounts can be created but there is no in-app path and/or no web deletion URL | Settings; Data safety "data deletion" answers | In-app deletion + public web URL; update Data safety | New build + console |
| Permissions — Photo and Video | `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` without core use | **Merged** manifest (plugins add them) | Use the system photo picker; remove with `tools:node="remove"`; or file the declaration if core | New build |
| Permissions — background location | `ACCESS_BACKGROUND_LOCATION` without core use, disclosure and video | Manifest, location service | Remove, or declaration + prominent disclosure + video | New build + console |
| Permissions — SMS / Call log, all files access, package visibility, exact alarms, full-screen intent | Restricted permission without an allowed use | Merged manifest | Remove (often added by a plugin), or file the declaration | New build + console |
| Foreground service types | Foreground service type without its declaration / video | Manifest `foregroundServiceType` | Remove or declare with video | New build + console |
| App access (missing credentials) | Reviewer could not sign in | Play Console → App content → App access | Working test account, no OTP, instructions | Console |
| Advertising ID | AD_ID declared but form says no ads ID use, or the reverse | Merged manifest; App content → Advertising ID | Make the form match the manifest | Console |
| Ads policy | Disruptive ads (full-screen at launch or exit, unexpected), ads that mimic app UI | Ad placement code | `<kit>/STORE-POLICIES.md` section 2 | New build |
| Families | App appeals to children: target audience, ads SDK not certified for families, AD_ID in a child-directed app | Target audience form; ad request configuration | Correct target audience; child-directed ad settings; remove AD_ID | Console and/or new build |
| Payments | Digital goods / subscriptions sold without Google Play Billing | Payment SDKs, web checkout | Play Billing for digital goods (regional exceptions exist) | New build |
| Deceptive behavior / Metadata | Listing claims features the app lacks, misleading icon / title, keyword stuffing | Store listing | Accurate listing | Console |
| Spam and minimum functionality / broken functionality | Crashes, empty app, web wrapper, duplicate apps | Pre-launch report, Android vitals | Fix crashes; add real functionality | New build |
| Target API level | Update rejected: targetSdk below the current requirement | `android/app/build.gradle(.kts)` | Raise targetSdk, test the behavior changes (`<kit>/GOOGLE-PLAY-RELEASE.md`) | New build |
| Impersonation / intellectual property | Brand, logo or name of someone else; copyrighted content | Name, icon, screenshots, content | Remove, or have written permission ready for the appeal | Console / new build / appeal |
| User-generated content | No reporting / blocking / moderation | Chat, posts, profiles | Report + block + moderation; terms users accept | New build |
| Health, financial, VPN, … declarations | Sensitive category without its declaration form | App category, features | File the declaration in App content | Console |

## Reply checklist

- One reply per rejection, covering every point raised — reviewers close threads that leave one unanswered.
- Say what changed and how to see it; add a screenshot or a short screen recording for anything not obvious.
- Credentials go in App Review Information / App access, not in the message text.
- If you disagree, quote the rule text and show the evidence; stay factual.
