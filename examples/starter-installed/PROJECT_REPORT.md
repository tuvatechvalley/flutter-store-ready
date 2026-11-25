# Production readiness report — `acme_notes`

Generated: 2026-11-25 23:44 · by the flutter-store-ready skill

## ❌ NOT READY — 5 blocking item(s) must be fixed before release.

| ❌ Missing (blocking) | ⚠️ Recommended | 📝 Your manual tasks | ✅ Done |
|:-:|:-:|:-:|:-:|
| **5** | **15** | **25** | **41** |

## ❌ Missing — must fix before release

1. **config/prod.json** _(Production config)_  
   No production configuration file.
   → **Fix:** Copy config/prod.example.json to config/prod.json and fill it in (git-ignored).
2. **android/key.properties** _(Google Play · Signing)_  
   Missing. Release builds would be signed with the debug key and Play rejects them.
   → **Fix:** Create an upload key and android/key.properties (see GOOGLE-PLAY-RELEASE.md in the flutter-store-ready skill).
3. **Launcher icon** _(Google Play · App identity)_  
   Still the default Flutter icon.
   → **Fix:** Generate icons (e.g. flutter_launcher_icons) incl. adaptive + monochrome.
4. **App icon (1024 px)** _(App Store · App identity)_  
   Still the default Flutter icon.
   → **Fix:** Generate icons (e.g. flutter_launcher_icons with `remove_alpha_ios: true`).
5. **Development team** _(App Store · Signing)_  
   No DEVELOPMENT_TEAM in the project: `flutter build ipa` cannot sign the archive.
   → **Fix:** Open ios/Runner.xcworkspace in Xcode > Runner > Signing & Capabilities and pick your team (needs a paid Apple Developer Program membership). See APP-STORE-RELEASE.md in the flutter-store-ready skill.

## ⚠️ Recommended

1. **Back button tested (tabs / nested pages)** _(Navigation & permissions)_  
   The app has tabs or nested navigation and no test presses the Android back button. Typical bug: back on a second-level page closes the app instead of going up.
   → **Fix:** Add a widget test: open a nested page, call `tester.binding.handlePopRoute()`, expect the parent page (NAVIGATION-AND-LIFECYCLE.md).
2. **pubspec description** _(Template leftovers)_  
   Still the template description.
   → **Fix:** Describe your app in pubspec.yaml.
3. **App title (starter)** _(Template leftovers)_  
   The app is still called "Starter".
   → **Fix:** Change appTitle in lib/core/l10n/app_localizations.dart.
4. **Brand color (starter)** _(Template leftovers)_  
   Still the starter's default seed color.
   → **Fix:** Set AppTheme.seed to the brand color.
5. **Sample "Items" feature (starter)** _(Template leftovers)_  
   The demo feature from the starter is still in the app.
   → **Fix:** Replace it with real features (keep: repository + AsyncValueView + tests).
6. **versionCode** _(Google Play · App identity)_  
   versionName 1.0.0, versionCode 1. Must be higher than every previous upload (pass --last-version-code to verify).
7. **App name (android:label)** _(Google Play · App identity)_  
   "acme_notes" looks like the package name, not a user-facing name.
   → **Fix:** Set android:label to the real app name (or a @string resource for localization).
8. **App bundle (.aab)** _(Google Play · Release bundle)_  
   Not built yet (build/app/outputs/bundle/release/app-release.aab).
   → **Fix:** flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
9. **Tracked secrets** _(Google Play · Secrets)_  
   Not a git repository; could not check tracked files.
10. **Build number** _(App Store · App identity)_  
   Version 1.0.0, build 1. Each upload of the same version needs a higher build; a released version number can never be reused (pass --last-build-number to verify).
11. **Deployment target** _(App Store · Build settings)_  
   iOS 13.0 is accepted today. From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later.
   → **Fix:** Plan to raise the deployment target to 15.0 before April 2027 (check which of your users are still on iOS 13–14).
12. **Export compliance key** _(App Store · Network & export compliance)_  
   Missing: App Store Connect asks the export-compliance question on every upload and the build waits until someone answers.
   → **Fix:** Add ITSAppUsesNonExemptEncryption to Info.plist: <false/> when the app only uses HTTPS and the operating system's crypto. This is a legal declaration: decide it yourself.
13. **Privacy manifest** _(App Store · Privacy)_  
   No app privacy manifest. Required when your own code uses "required reason" APIs (UserDefaults, file timestamps, disk space, boot time) or collects data.
   → **Fix:** In Xcode: File > New > File > App Privacy, target Runner (creating the file by hand does not add it to the project).
14. **App archive (.ipa)** _(App Store · Release build)_  
   Not built. iOS builds need a Mac with Xcode (or a macOS CI runner such as Codemagic or GitHub Actions macos-latest).
   → **Fix:** flutter build ipa --release --obfuscate --split-debug-info=build/symbols-ios --dart-define-from-file=config/prod.json
15. **Tracked secrets** _(App Store · Secrets)_  
   Not a git repository; could not check tracked files.

## 📝 Your manual tasks (outside the code)

1. **Test account for store review (the app has sign-in)** _(Store requirements)_  
   Create a dedicated reviewer account and give it to both stores: Google Play Console > App content > App access ("All or some functionality is restricted") and App Store Connect > App Review Information > Sign-in required. It must never expire, already contain sample data, need no SMS / e-mail code (or explain how to get one), and work from abroad. Keep the backend running during review. A missing or broken reviewer login is one of the most common rejections on both stores.
   → **Fix:** If parts of the app work without an account, say so in the review notes. If the app sells subscriptions, say how the reviewer reaches the paywall.
2. **Privacy policy / terms describe account deletion** _(Store requirements)_  
   The app lets users delete their account, and the legal text is not shipped in the app, so it could not be read. Open your privacy policy and terms pages and check they say: that the account can be deleted and where (in-app path + a web address for people who uninstalled), which data is deleted, what is kept and for how long (e.g. invoices), and whom to contact.
   → **Fix:** Google Play also asks for the web deletion URL in the Data safety form; App Store Connect asks about it in App Privacy.
3. **Data your SDKs collect (declare it in both stores)** _(Store policy)_  
   From pubspec.yaml, at least: your own sign-in → e-mail address, user IDs (plus every profile field you store); sentry_flutter → crash logs, diagnostics, device or other IDs. Add what the app itself sends to your server (account details, form fields, content). The Play Data safety form, Apple App Privacy labels and your privacy policy must all say the same thing.
   → **Fix:** A form that says "no data collected" while an analytics, ads or crash SDK is installed is a common reason for removal.
4. **Plugin native libraries** _(Google Play · 16 KB page size)_  
   Every plugin with .so files must be 16 KB aligned.
   → **Fix:** After uploading, open Play Console > App bundle explorer > "Memory page size" — it must say compliant.
5. **Play App Signing** _(Google Play · Play Console (manual))_  
   Enrolled (default for new apps). Upload key ≠ app signing key; keep the upload key backed up.
6. **Privacy policy** _(Google Play · Play Console (manual))_  
   Public HTTPS URL in Store listing and inside the app (Settings/About).
7. **Data safety form** _(Google Play · Play Console (manual))_  
   Declare every data type collected by you AND SDKs (e.g. Sentry crash data, device ids).
8. **Account deletion** _(Google Play · Play Console (manual))_  
   If users can create accounts: in-app deletion path + public web deletion URL in the Data safety form.
9. **Content rating & target audience** _(Google Play · Play Console (manual))_  
   Complete the questionnaire; children in audience triggers the Families policy.
10. **Ads declaration** _(Google Play · Play Console (manual))_  
   Declare whether the app contains ads.
11. **Closed testing (new personal accounts)** _(Google Play · Play Console (manual))_  
   Personal accounts created after 13 Nov 2023: closed test with >= 12 testers opted in for 14 continuous days before production access.
12. **Store listing assets** _(Google Play · Play Console (manual))_  
   512x512 icon, 1024x500 feature graphic, >= 2 phone screenshots (+ 7"/10" tablet screenshots for tablet visibility).
13. **Pre-launch report** _(Google Play · Play Console (manual))_  
   Upload to internal testing first; fix crashes/accessibility/security issues it reports.
14. **Apple Developer Program** _(App Store · App Store Connect (manual))_  
   Paid membership (99 USD / year). Companies need a D-U-N-S number; enrollment can take days.
15. **App record** _(App Store · App Store Connect (manual))_  
   Register the bundle id and create the app in App Store Connect (name, primary language, SKU). The app name must be unique on the store.
16. **Build toolchain** _(App Store · App Store Connect (manual))_  
   Uploads must be built with Xcode 26 / iOS 26 SDK or later. From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later. Apple raises this every spring: check developer.apple.com/news/upcoming-requirements.
17. **App Privacy ("nutrition labels")** _(App Store · App Store Connect (manual))_  
   Declare every data type you and your SDKs collect (crash data, analytics, identifiers) and whether it is linked to the user or used for tracking.
18. **Privacy policy & support URL** _(App Store · App Store Connect (manual))_  
   Public HTTPS privacy policy URL in App Store Connect and inside the app; a working support URL.
19. **Account deletion** _(App Store · App Store Connect (manual))_  
   If users can create an account, they must be able to delete it inside the app (guideline 5.1.1(v)) — not only deactivate it.
20. **Review information** _(App Store · App Store Connect (manual))_  
   Contact details and notes explaining anything not obvious (special hardware, region locks, why a permission is needed). If the app has sign-in: a demo account that works (user + password) — a missing or broken one is the most common avoidable rejection.
21. **Screenshots** _(App Store · App Store Connect (manual))_  
   iPhone screenshots for the largest display size are required; the app supports iPad, so iPad screenshots are required too. App Store Connect shows the exact sizes it currently accepts. They must show the real app.
22. **Age rating & content rights** _(App Store · App Store Connect (manual))_  
   Complete the age-rating questionnaire; confirm you have the rights to third-party content.
23. **EU trader status** _(App Store · App Store Connect (manual))_  
   To distribute in the EU, declare trader / non-trader status (Digital Services Act); traders publish contact details.
24. **TestFlight first** _(App Store · App Store Connect (manual))_  
   Upload, wait for processing, test the exact build on a real device (fresh install, largest text size, no network) before submitting for review.
25. **iPad** _(App Store · App Store Connect (manual))_  
   The app declares iPad support: App Review tests it on iPad. Check every screen there, or make the app iPhone-only.

## ✅ Done

- **Global error handlers** _(Error handling)_ — Framework and async errors are caught centrally.
- **Friendly build-error widget** _(Error handling)_ — ErrorWidget.builder is customized.
- **Crash reporting** _(Error handling)_ — A crash reporting SDK is installed.
- **Loading / error / empty states** _(Error handling)_ — Async widgets handle the error state.
- **No raw exception text shown to users** _(Error handling)_ — No exception objects, `e.toString()` or stack traces are put on screen.
- **No status codes or server responses shown to users** _(Error handling)_ — No HTTP status code or response body is put on screen.
- **Server error text is not passed straight to users** _(Error handling)_ — No `data['message']` style server text is put on screen.
- **Error wording is plain language** _(Error handling)_ — No developer wording (exception names, "HTTP 500", "status code") in user-facing strings.
- **Secure token storage** _(Security)_ — flutter_secure_storage (Keychain / Keystore) is used.
- **Certificate pinning** _(Security)_ — TLS certificate / public-key pinning is implemented.
- **Network timeouts** _(Security)_ — Requests have timeouts.
- **No raw print logging** _(Security)_ — No print/debugPrint in lib/.
- **Screens covered by widget tests** _(Responsive & large text)_ — All 5 screens appear in tests.
- **Large-text test (200–300%)** _(Responsive & large text)_ — Tests render screens with enlarged text.
- **Text follows the phone's font size** _(Responsive & large text)_ — Text size is never locked or capped below 2x.
- **No fixed heights around text** _(Responsive & large text)_ — No fixed-height boxes around text found.
- **Safe areas (notch, gesture bar)** _(Responsive & large text)_ — SafeArea is used.
- **Adaptive layout (tablet / landscape)** _(Responsive & large text)_ — Layouts react to the available size.
- **In-app account deletion** _(Store requirements)_ — Users can delete their account in the app.
- **Privacy policy link in the app** _(Store requirements)_ — Found.
- **Localization** _(Store requirements)_ — Localization is set up.
- **No development servers in release code** _(Store policy)_ — No localhost / LAN / staging address reaches a release build unguarded.
- **TODO / FIXME** _(Code health)_ — None in lib/.
- **Strict static analysis** _(Code health)_ — Strict analyzer settings enabled.
- **Tests** _(Code health)_ — 13 test file(s).
- **CI pipeline** _(Code health)_ — CI configuration found.
- **Release signingConfig** _(Google Play · Signing)_ — Release uses signingConfigs "release" from key.properties.
- **applicationId** _(Google Play · App identity)_ — "com.acme.notes.acme_notes" (permanent after first upload).
- **targetSdk** _(Google Play · SDK levels)_ — targetSdk 36 (Play requires >= 36 for new apps and updates).
- **minSdk** _(Google Play · SDK levels)_ — minSdk 24.
- **INTERNET permission (main manifest)** _(Google Play · Manifest & security)_ — Present.
- **Cleartext HTTP** _(Google Play · Manifest & security)_ — Blocked via network security config.
- **Backups** _(Google Play · Manifest & security)_ — allowBackup="false".
- **Sensitive permissions (main manifest)** _(Google Play · Permissions & policy)_ — None declared in the app manifest. Plugins can add more: build a release once (`flutter build appbundle`) and run this audit again to check the merged manifest.
- **Android Gradle Plugin** _(Google Play · 16 KB page size)_ — AGP 9.0.1.
- **Bundle identifier** _(App Store · App identity)_ — "com.acme.notes.acmeNotes" (permanent after first upload).
- **App name (CFBundleDisplayName)** _(App Store · App identity)_ — "Acme Notes" (shown under the icon; keep it short, about 12 characters, or it is cut off).
- **Signing style** _(App Store · Signing)_ — Automatic signing: Xcode creates the distribution certificate and profile.
- **iPad orientations** _(App Store · Build settings)_ — iPad is supported; multitasking requirements are met.
- **App Transport Security** _(App Store · Network & export compliance)_ — HTTPS only.
- **Permission usage descriptions** _(App Store · Permissions)_ — Every known plugin in pubspec.yaml has its Info.plist keys.

> Quality gates skipped (`--skip-gates`).

---
Store details (same folder): `PLAY_READINESS.md` (Google Play), `APP_STORE_READINESS.md` (App Store).
