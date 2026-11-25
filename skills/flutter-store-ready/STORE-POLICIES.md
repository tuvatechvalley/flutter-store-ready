# Store policies that depend on what the app does

Both stores reject for the same handful of reasons. Each section applies only when the app has that feature; the audit (`project_report.dart`, section "Store policy") turns it on from `pubspec.yaml` and `lib/`. These checks are heuristics, so they are recommendations or manual tasks — never blocking. Read the code before repeating a finding to the user.

Policies change. Before quoting a rule or a date, check the current text: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Play Developer Policy Center](https://play.google.com/about/developer-content-policy/).

## 1. In-app purchases and subscriptions

- **Restore**: a visible "Restore purchases" button (paywall or settings) that calls `restorePurchases()`. Required for non-consumables and subscriptions (Apple 3.1.1); not for consumables.
- **Paywall**, before the buy button: the price from the store (never hard-coded), what the user gets, billing period, "renews automatically", how to cancel, trial length and the price after it, links to the Terms of use (EULA) and the Privacy policy. The amount actually billed is at least as prominent as a per-month figure.
- **Digital goods use the store's billing** on both platforms: content, subscriptions, feature unlocks, virtual currency. Stripe / PayPal / iyzico are for physical goods and real-world services. Regional exceptions exist and change; check them for your countries instead of assuming.
- The reviewer must be able to reach the paywall and complete a sandbox purchase: say how in the review notes.

## 2. Ads

- **Consent first**: for users in the EEA, the UK and Switzerland, Google requires consent collected with a certified consent platform before ads are requested. Run the UMP flow (`ConsentInformation.requestConsentInfoUpdate` → show the form) and only then `MobileAds.initialize()`.
- **iOS tracking**: if the SDK tracks, set `NSUserTrackingUsageDescription` **and** call `AppTrackingTransparency.requestTrackingAuthorization()` before the SDK starts. The key without the call means the user is never asked. If you do not track, configure the SDK accordingly and leave the key out.
- **Advertising ID (Android)**: the ad SDK adds the `AD_ID` permission to the shipped manifest. The Play Console "Advertising ID" answer and the Data safety form must match it.
- **Placement**: no full-screen ad at launch or on exit, interstitials only at natural breaks and closable, rewarded ads only when the user chooses, nothing that looks like an app button.
- **Test ads while developing**: use the SDK's test unit ids (or register test devices) in every build that is not the store build. Clicking your own live ads gets the ad account suspended.

## 3. User-generated content

If users see content written by other users (chat, comments, posts, profiles, reviews):

- report on every message / post / profile, and block user;
- filtering of objectionable content before it is shown;
- a published contact, and reports acted on quickly;
- terms that users accept before posting.

Apple 1.2, Google Play user-generated content policy. Not needed when users only see their own content.

## 4. Generative AI

- Before personal data goes to a third-party AI, the app says who receives it and asks for permission (Apple 5.1.2(i)).
- Users can report or flag offensive generated content inside the app (Google Play AI-generated content policy).
- The privacy policy and both store data forms name the AI provider.
- The provider's API key never ships in the app: call the model through your own backend.

## 5. Data declarations

The Play **Data safety** form, Apple's **App Privacy** labels and the **privacy policy** must describe the same data. The audit lists what the installed SDKs collect (crash reporting, analytics, ads, push, sign-in, location, purchases) as a starting point; add what the app itself sends to your server. Declaring "no data collected" with an analytics, ads or crash SDK installed is a common reason for removal.

Plugins also add **permissions** you never wrote. After a release build the audit reads the merged manifest and lists them: remove the ones you do not use (`tools:node="remove"`), declare the rest.

## 6. Accounts

- In-app account deletion (not only deactivation, not only "e-mail us"), which really deletes on the server; plus a web address for people who uninstalled (Google Play).
- The privacy policy / terms describe it: how, what is deleted, what is kept and for how long.
- A reviewer test account in both consoles: never expires, has sample data, needs no SMS / e-mail code.
- Third-party login (Google, Facebook …) → also offer a privacy-focused option such as Sign in with Apple (Apple 4.8). Not needed for the company's own accounts only.

## 7. The same app for reviewers and users

- No code that detects review, TestFlight or sandbox to show something different (Apple 2.3.1). Selecting the sandbox purchase environment is fine.
- No "beta", "demo", "test" in the app name; no placeholder content; no staging server.
- iOS text must not mention other platforms ("also on Android", "Google Play").
- Ask for a rating with `in_app_review`, never with a custom dialog that sends only happy users to the store.

## 8. Keys that work in debug and fail in the store build

Google Play re-signs the app with the **app signing key**. Its SHA-1 / SHA-256 differ from the upload key and from debug. Register all three wherever a Google service checks them: Firebase project settings, API key restrictions (Maps), the OAuth client (Google sign-in), `assetlinks.json` (app links). Symptoms when one is missing: grey map, Google sign-in fails, links open the browser — only in the build downloaded from Play.

Maps also needs the key in the app: `com.google.android.geo.API_KEY` in the Android manifest and `GMSServices.provideAPIKey` in the iOS AppDelegate.
