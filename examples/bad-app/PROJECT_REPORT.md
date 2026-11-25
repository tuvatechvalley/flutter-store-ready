# Production readiness report — `planted`

Generated: 2026-11-25 23:43 · by the flutter-store-ready skill

## ❌ NOT READY — 6 blocking item(s) must be fixed before release.

| ❌ Missing (blocking) | ⚠️ Recommended | 📝 Your manual tasks | ✅ Done |
|:-:|:-:|:-:|:-:|
| **6** | **25** | **5** | **4** |

## ❌ Missing — must fix before release

1. **Global error handlers** _(Error handling)_  
   Missing: FlutterError.onError, PlatformDispatcher.instance.onError. Uncaught errors crash or vanish silently.
   → **Fix:** Add a bootstrap() like templates/starter_app/lib/bootstrap.dart (ERROR-HANDLING.md).
2. **No raw exception text shown to users** _(Error handling)_  
   Exception text is shown to users (unreadable for them, and it can leak URLs and tokens): lib/screens/orders_screen.dart:14, lib/screens/orders_screen.dart:16
   → **Fix:** Map the error to a typed failure and show a localized sentence that says what happened and what to do (ERROR-HANDLING.md, "Messages users can understand").
3. **No status codes or server responses shown to users** _(Error handling)_  
   HTTP status code / response body shown to users: lib/screens/orders_screen.dart:16, lib/screens/orders_screen.dart:22
   → **Fix:** Translate the status into a failure type (404 → "not found", 5xx → "something went wrong on our side") and show its localized message. Log the code instead.
4. **Secure token storage** _(Security)_  
   Sign-in tokens are kept in plain storage (Hive / SharedPreferences / file, no encryption) in lib/api.dart. Anyone with a backup, a rooted phone or a stolen unlocked device can copy them and use the account.
   → **Fix:** Store tokens only with flutter_secure_storage (Keychain / Keystore), or open the Hive box with an encryptionCipher whose key lives in secure storage (SECURITY.md).
5. **In-app account deletion** _(Store requirements)_  
   The app has accounts but no account deletion (required by Google Play and the App Store).
   → **Fix:** Add "Delete account" in settings: backend call + wipe local data; also publish a web deletion URL.
6. **Tests** _(Code health)_  
   0 test file(s).
   → **Fix:** Add unit, widget and responsive tests.

## ⚠️ Recommended

1. **Friendly build-error widget** _(Error handling)_  
   A widget that throws shows a grey box (release) or red screen (debug).
   → **Fix:** Set ErrorWidget.builder to a calm placeholder.
2. **Crash reporting** _(Error handling)_  
   No crash reporting: you will not know when the app crashes for users.
   → **Fix:** Add sentry_flutter or firebase_crashlytics.
3. **Screens show a loading state while data loads** _(Error handling)_  
   These screens fetch data when they open but have no loading indicator, so the user sees a blank or half-empty page: lib/screens/stock_screen.dart
   → **Fix:** Show a progress indicator or skeleton until the first data arrives (ERROR-HANDLING.md, "Four states").
4. **Screens tell the user when the server call fails** _(Error handling)_  
   These screens call the server but show nothing when it fails (the page stays empty or the button seems to do nothing): lib/screens/stock_screen.dart
   → **Fix:** Show a friendly message with "Try again"; never swallow the error silently.
5. **Server error text is not passed straight to users** _(Error handling)_  
   Text from the server response is shown as-is (often English, technical, or not in the user's language): lib/screens/orders_screen.dart:22
   → **Fix:** Show your own localized message chosen by an error code from the server. Server text is acceptable only for field validation the backend already localizes.
6. **Error wording is plain language** _(Error handling)_  
   Developer wording in user-facing text: lib/screens/orders_screen.dart:21 ("Internal Server Error")
   → **Fix:** Rewrite for a non-technical reader: what happened + what to do next ("Could not connect. Check your internet and try again.").
7. **Certificate pinning** _(Security)_  
   No certificate pinning: a malicious Wi-Fi or installed CA can read API traffic.
   → **Fix:** Add SPKI pinning with a backup pin (templates/starter_app/lib/core/network/certificate_pinner.dart).
8. **Network timeouts** _(Security)_  
   No request timeouts found: a dead network can hang screens forever.
   → **Fix:** Set connect/receive timeouts on the HTTP client.
9. **No raw print logging** _(Security)_  
   1 print/debugPrint call(s): logs can leak tokens and personal data on devices.
   → **Fix:** Use one logger that redacts secrets and is silent in release.
10. **Screens covered by widget tests** _(Responsive & large text)_  
   3/3 screens never rendered in a test: `ChatScreen` (lib/screens/chat_screen.dart), `OrdersScreen` (lib/screens/orders_screen.dart), `StockScreen` (lib/screens/stock_screen.dart)
   → **Fix:** Add them to a responsive matrix test (5 sizes × 100–300% text × locales), see RESPONSIVE-AND-LARGE-TEXT.md.
11. **Large-text test (200–300%)** _(Responsive & large text)_  
   No test renders the app with enlarged text, so overflow at 200% font size goes unnoticed.
   → **Fix:** Copy templates/starter_app/test/responsive_test.dart and large_text_test.dart.
12. **Safe areas (notch, gesture bar)** _(Responsive & large text)_  
   No SafeArea: content can hide under the notch or gesture bar.
   → **Fix:** Wrap screen bodies with SafeArea (or use Scaffold app bars).
13. **Adaptive layout (tablet / landscape)** _(Responsive & large text)_  
   No size-based layout found: tablets and landscape show a stretched phone UI.
   → **Fix:** Use width breakpoints (compact/medium/expanded) divided by text scale (RESPONSIVE-AND-LARGE-TEXT.md).
14. **Privacy policy link in the app** _(Store requirements)_  
   No privacy policy link inside the app.
   → **Fix:** Add a "Privacy policy" item in settings that opens your public policy URL (url_launcher).
15. **Localization** _(Store requirements)_  
   No localization: dates, numbers and system widgets stay in English.
   → **Fix:** Add localization delegates and supportedLocales.
16. **Restore purchases** _(Store policy)_  
   In-app purchases (in_app_purchase) but no restore call found. Apple rejects apps whose non-consumable purchases or subscriptions cannot be restored (guideline 3.1.1). Not needed when everything is consumable.
   → **Fix:** Add a visible "Restore purchases" button on the paywall or in settings that calls restorePurchases().
17. **Ads: consent before the ad SDK starts** _(Store policy)_  
   Ad SDK (google_mobile_ads) with no consent flow in the code. For users in the EEA, the UK and Switzerland Google requires consent collected by a certified consent platform (e.g. its UMP SDK) before ads are requested; without it ads are limited or not served there, and it is a policy violation.
   → **Fix:** Run the UMP flow (ConsentInformation.requestConsentInfoUpdate → load and show the form) before MobileAds.initialize(). On iOS show the tracking prompt before as well.
18. **User content: report and block** _(Store policy)_  
   The app seems to show content written by users (lib/screens/chat_screen.dart) but has no report or block action. Both stores require: a way to report content, a way to block users, filtering of objectionable material, and a published contact (Apple guideline 1.2, Google Play user-generated content policy).
   → **Fix:** Add "Report" on every message / post / profile and "Block user"; act on reports quickly. Ignore this if users only see their own content.
19. **No development servers in release code** _(Store policy)_  
   Local or staging addresses that are not limited to debug builds: lib/api.dart:2
   → **Fix:** Read the address from the build configuration, or guard it with kReleaseMode / kDebugMode.
20. **Behaves the same for reviewers** _(Store policy)_  
   Code that detects review / TestFlight / sandbox: lib/store_check.dart:2. Showing reviewers something different from real users is grounds for removal (Apple guideline 2.3.1).
   → **Fix:** Remove it, unless it only selects the sandbox purchase environment.
21. **Back button tested (tabs / nested pages)** _(Navigation & permissions)_  
   The app has tabs or nested navigation and no test presses the Android back button. Typical bug: back on a second-level page closes the app instead of going up.
   → **Fix:** Add a widget test: open a nested page, call `tester.binding.handlePopRoute()`, expect the parent page (NAVIGATION-AND-LIFECYCLE.md).
22. **Permissions are asked when needed, not at launch** _(Navigation & permissions)_  
   A permission is requested while the app starts (lib/main.dart). Users deny prompts they do not understand, and App Review rejects apps that ask before the feature is used.
   → **Fix:** Ask at the moment the feature is used, after a sentence that explains why — and only for the users / roles that need it.
23. **Theme does not force full-width buttons** _(Responsive & large text)_  
   The theme makes every button as wide as possible (lib/main.dart:21). A button placed next to a title in a Row then takes the whole row and the title wraps letter by letter, worst with large text.
   → **Fix:** Keep the theme at a minimum height only (e.g. Size(64, 48)); make a button full-width where it is used (SizedBox(width: double.infinity) or Expanded).
24. **Strict static analysis** _(Code health)_  
   Only default lints: many crash-prone patterns (dynamic calls, unawaited futures) go unnoticed.
   → **Fix:** Use templates/starter_app/analysis_options.yaml (strict-casts, unawaited_futures as error...).
25. **CI pipeline** _(Code health)_  
   No CI: nothing stops a broken build from shipping.
   → **Fix:** Copy templates/starter_app/.github/workflows/ci.yml.

## 📝 Your manual tasks (outside the code)

1. **Test account for store review (the app has sign-in)** _(Store requirements)_  
   Create a dedicated reviewer account and give it to both stores: Google Play Console > App content > App access ("All or some functionality is restricted") and App Store Connect > App Review Information > Sign-in required. It must never expire, already contain sample data, need no SMS / e-mail code (or explain how to get one), and work from abroad. Keep the backend running during review. A missing or broken reviewer login is one of the most common rejections on both stores.
   → **Fix:** If parts of the app work without an account, say so in the review notes. If the app sells subscriptions, say how the reviewer reaches the paywall.
2. **Paywall tells the user what they pay** _(Store policy)_  
   Open the purchase screen and check, before the buy button: the price from the store (not hard-coded), what the user gets, for subscriptions the billing period, that it renews automatically and how to cancel, trial length and the price after it, and working links to the Terms of use (EULA) and the Privacy policy. The total billed amount must be at least as prominent as a per-month figure.
   → **Fix:** Missing terms or links on the paywall are a routine rejection on both stores.
3. **Ads: placement** _(Store policy)_  
   Check on a device: no full-screen ad at app launch or when leaving the app, interstitials only at natural breaks and closable, rewarded ads only when the user chooses them, no ads that look like app buttons, and none in apps for children unless the SDK is certified for families.
4. **Data your SDKs collect (declare it in both stores)** _(Store policy)_  
   From pubspec.yaml, at least: your own sign-in → e-mail address, user IDs (plus every profile field you store); google_mobile_ads → advertising ID, app interactions, approximate location, diagnostics — shared with Google for advertising; geolocator → precise or approximate location; in_app_purchase → purchase history. Add what the app itself sends to your server (account details, form fields, content). The Play Data safety form, Apple App Privacy labels and your privacy policy must all say the same thing.
   → **Fix:** A form that says "no data collected" while an analytics, ads or crash SDK is installed is a common reason for removal.
5. **Environment config** _(Production config)_  
   No config/ folder. Make sure release builds point to the production API over https and contain no secrets.

## ✅ Done

- **Loading / error / empty states** _(Error handling)_ — Async widgets handle the error state.
- **Text follows the phone's font size** _(Responsive & large text)_ — Text size is never locked or capped below 2x.
- **No fixed heights around text** _(Responsive & large text)_ — No fixed-height boxes around text found.
- **TODO / FIXME** _(Code health)_ — None in lib/.

> Quality gates skipped (`--skip-gates`).

---
Store details (same folder): `PLAY_READINESS.md` (Google Play), `APP_STORE_READINESS.md` (App Store).
