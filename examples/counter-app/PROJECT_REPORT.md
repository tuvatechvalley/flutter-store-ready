# Production readiness report — `counter_app`

Generated: 2026-11-25 23:40 · by the flutter-store-ready skill

## ❌ NOT READY — 11 blocking item(s) must be fixed before release.

| ❌ Missing (blocking) | ⚠️ Recommended | 📝 Your manual tasks | ✅ Done |
|:-:|:-:|:-:|:-:|
| **11** | **24** | **21** | **24** |

## ❌ Missing — must fix before release

1. **Global error handlers** _(Error handling)_  
   Missing: FlutterError.onError, PlatformDispatcher.instance.onError. Uncaught errors crash or vanish silently.
   → **Fix:** Add a bootstrap() like templates/starter_app/lib/bootstrap.dart (ERROR-HANDLING.md).
2. **Default counter app** _(Template leftovers)_  
   lib/main.dart is still the `flutter create` counter demo.
   → **Fix:** Replace it with the real app (or install the starter: scripts/install.dart --starter).
3. **Tests** _(Code health)_  
   1 test file(s).
   → **Fix:** Add unit, widget and responsive tests.
4. **android/key.properties** _(Google Play · Signing)_  
   Missing. Release builds would be signed with the debug key and Play rejects them.
   → **Fix:** Create an upload key and android/key.properties (see GOOGLE-PLAY-RELEASE.md in the flutter-store-ready skill).
5. **Release signingConfig** _(Google Play · Signing)_  
   The release build type is signed with the DEBUG key.
   → **Fix:** Run `dart run tool/flutter_store_ready/harden_platforms.dart` or configure signingConfigs.release.
6. **applicationId** _(Google Play · App identity)_  
   "com.example.counter_app" — Play rejects com.example.* and it can never be changed after release.
   → **Fix:** Choose a permanent reverse-domain id you own, e.g. com.yourcompany.app (also update namespace and the Kotlin package).
7. **Launcher icon** _(Google Play · App identity)_  
   Still the default Flutter icon.
   → **Fix:** Generate icons (e.g. flutter_launcher_icons) incl. adaptive + monochrome.
8. **INTERNET permission (main manifest)** _(Google Play · Manifest & security)_  
   Missing: the RELEASE build cannot reach the network (debug works, so this is often missed).
   → **Fix:** Add <uses-permission android:name="android.permission.INTERNET"/> to app/src/main/AndroidManifest.xml.
9. **Bundle identifier** _(App Store · App identity)_  
   "com.example.counterApp" — com.example.* cannot be registered and the bundle id can never be changed after the first upload.
   → **Fix:** Set a permanent reverse-domain id you own in Xcode (Runner > Signing & Capabilities) for Debug, Profile and Release.
10. **App icon (1024 px)** _(App Store · App identity)_  
   Still the default Flutter icon.
   → **Fix:** Generate icons (e.g. flutter_launcher_icons with `remove_alpha_ios: true`).
11. **Development team** _(App Store · Signing)_  
   No DEVELOPMENT_TEAM in the project: `flutter build ipa` cannot sign the archive.
   → **Fix:** Open ios/Runner.xcworkspace in Xcode > Runner > Signing & Capabilities and pick your team (needs a paid Apple Developer Program membership). See APP-STORE-RELEASE.md in the flutter-store-ready skill.

## ⚠️ Recommended

1. **Friendly build-error widget** _(Error handling)_  
   A widget that throws shows a grey box (release) or red screen (debug).
   → **Fix:** Set ErrorWidget.builder to a calm placeholder.
2. **Crash reporting** _(Error handling)_  
   No crash reporting: you will not know when the app crashes for users.
   → **Fix:** Add sentry_flutter or firebase_crashlytics.
3. **Screens covered by widget tests** _(Responsive & large text)_  
   1/1 screens never rendered in a test: `MyHomePage` (lib/main.dart)
   → **Fix:** Add them to a responsive matrix test (5 sizes × 100–300% text × locales), see RESPONSIVE-AND-LARGE-TEXT.md.
4. **Large-text test (200–300%)** _(Responsive & large text)_  
   No test renders the app with enlarged text, so overflow at 200% font size goes unnoticed.
   → **Fix:** Copy templates/starter_app/test/responsive_test.dart and large_text_test.dart.
5. **Safe areas (notch, gesture bar)** _(Responsive & large text)_  
   No SafeArea: content can hide under the notch or gesture bar.
   → **Fix:** Wrap screen bodies with SafeArea (or use Scaffold app bars).
6. **Adaptive layout (tablet / landscape)** _(Responsive & large text)_  
   No size-based layout found: tablets and landscape show a stretched phone UI.
   → **Fix:** Use width breakpoints (compact/medium/expanded) divided by text scale (RESPONSIVE-AND-LARGE-TEXT.md).
7. **Privacy policy link in the app** _(Store requirements)_  
   No privacy policy link inside the app.
   → **Fix:** Add a "Privacy policy" item in settings that opens your public policy URL (url_launcher).
8. **Localization** _(Store requirements)_  
   No localization: dates, numbers and system widgets stay in English.
   → **Fix:** Add localization delegates and supportedLocales.
9. **App title** _(Template leftovers)_  
   MaterialApp title is still "Flutter Demo" (shown in the task switcher).
   → **Fix:** Set the real app name.
10. **pubspec description** _(Template leftovers)_  
   Still the template description.
   → **Fix:** Describe your app in pubspec.yaml.
11. **Strict static analysis** _(Code health)_  
   Only default lints: many crash-prone patterns (dynamic calls, unawaited futures) go unnoticed.
   → **Fix:** Use templates/starter_app/analysis_options.yaml (strict-casts, unawaited_futures as error...).
12. **CI pipeline** _(Code health)_  
   No CI: nothing stops a broken build from shipping.
   → **Fix:** Copy templates/starter_app/.github/workflows/ci.yml.
13. **versionCode** _(Google Play · App identity)_  
   versionName 1.0.0, versionCode 1. Must be higher than every previous upload (pass --last-version-code to verify).
14. **App name (android:label)** _(Google Play · App identity)_  
   "counter_app" looks like the package name, not a user-facing name.
   → **Fix:** Set android:label to the real app name (or a @string resource for localization).
15. **Cleartext HTTP** _(Google Play · Manifest & security)_  
   No network security config.
   → **Fix:** Run `dart run tool/flutter_store_ready/harden_platforms.dart`.
16. **Backups** _(Google Play · Manifest & security)_  
   App data (incl. caches) can be copied by adb/cloud backup.
   → **Fix:** Set allowBackup="false" and add dataExtractionRules.
17. **App bundle (.aab)** _(Google Play · Release bundle)_  
   Not built yet (build/app/outputs/bundle/release/app-release.aab).
   → **Fix:** flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
18. **Tracked secrets** _(Google Play · Secrets)_  
   Not a git repository; could not check tracked files.
19. **Build number** _(App Store · App identity)_  
   Version 1.0.0, build 1. Each upload of the same version needs a higher build; a released version number can never be reused (pass --last-build-number to verify).
20. **Deployment target** _(App Store · Build settings)_  
   iOS 13.0 is accepted today. From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later.
   → **Fix:** Plan to raise the deployment target to 15.0 before April 2027 (check which of your users are still on iOS 13–14).
21. **Export compliance key** _(App Store · Network & export compliance)_  
   Missing: App Store Connect asks the export-compliance question on every upload and the build waits until someone answers.
   → **Fix:** Add ITSAppUsesNonExemptEncryption to Info.plist: <false/> when the app only uses HTTPS and the operating system's crypto. This is a legal declaration: decide it yourself.
22. **Privacy manifest** _(App Store · Privacy)_  
   No app privacy manifest. Required when your own code uses "required reason" APIs (UserDefaults, file timestamps, disk space, boot time) or collects data.
   → **Fix:** In Xcode: File > New > File > App Privacy, target Runner (creating the file by hand does not add it to the project).
23. **App archive (.ipa)** _(App Store · Release build)_  
   Not built. iOS builds need a Mac with Xcode (or a macOS CI runner such as Codemagic or GitHub Actions macos-latest).
   → **Fix:** flutter build ipa --release --obfuscate --split-debug-info=build/symbols-ios --dart-define-from-file=config/prod.json
24. **Tracked secrets** _(App Store · Secrets)_  
   Not a git repository; could not check tracked files.

## 📝 Your manual tasks (outside the code)

1. **Environment config** _(Production config)_  
   No config/ folder. Make sure release builds point to the production API over https and contain no secrets.
2. **Plugin native libraries** _(Google Play · 16 KB page size)_  
   Every plugin with .so files must be 16 KB aligned.
   → **Fix:** After uploading, open Play Console > App bundle explorer > "Memory page size" — it must say compliant.
3. **Play App Signing** _(Google Play · Play Console (manual))_  
   Enrolled (default for new apps). Upload key ≠ app signing key; keep the upload key backed up.
4. **Privacy policy** _(Google Play · Play Console (manual))_  
   Public HTTPS URL in Store listing and inside the app (Settings/About).
5. **Data safety form** _(Google Play · Play Console (manual))_  
   Declare every data type collected by you AND SDKs (e.g. Sentry crash data, device ids).
6. **Content rating & target audience** _(Google Play · Play Console (manual))_  
   Complete the questionnaire; children in audience triggers the Families policy.
7. **Ads declaration** _(Google Play · Play Console (manual))_  
   Declare whether the app contains ads.
8. **Closed testing (new personal accounts)** _(Google Play · Play Console (manual))_  
   Personal accounts created after 13 Nov 2023: closed test with >= 12 testers opted in for 14 continuous days before production access.
9. **Store listing assets** _(Google Play · Play Console (manual))_  
   512x512 icon, 1024x500 feature graphic, >= 2 phone screenshots (+ 7"/10" tablet screenshots for tablet visibility).
10. **Pre-launch report** _(Google Play · Play Console (manual))_  
   Upload to internal testing first; fix crashes/accessibility/security issues it reports.
11. **Apple Developer Program** _(App Store · App Store Connect (manual))_  
   Paid membership (99 USD / year). Companies need a D-U-N-S number; enrollment can take days.
12. **App record** _(App Store · App Store Connect (manual))_  
   Register the bundle id and create the app in App Store Connect (name, primary language, SKU). The app name must be unique on the store.
13. **Build toolchain** _(App Store · App Store Connect (manual))_  
   Uploads must be built with Xcode 26 / iOS 26 SDK or later. From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later. Apple raises this every spring: check developer.apple.com/news/upcoming-requirements.
14. **App Privacy ("nutrition labels")** _(App Store · App Store Connect (manual))_  
   Declare every data type you and your SDKs collect (crash data, analytics, identifiers) and whether it is linked to the user or used for tracking.
15. **Privacy policy & support URL** _(App Store · App Store Connect (manual))_  
   Public HTTPS privacy policy URL in App Store Connect and inside the app; a working support URL.
16. **Review information** _(App Store · App Store Connect (manual))_  
   Contact details and notes explaining anything not obvious (special hardware, region locks, why a permission is needed). If the app has sign-in: a demo account that works (user + password) — a missing or broken one is the most common avoidable rejection.
17. **Screenshots** _(App Store · App Store Connect (manual))_  
   iPhone screenshots for the largest display size are required; the app supports iPad, so iPad screenshots are required too. App Store Connect shows the exact sizes it currently accepts. They must show the real app.
18. **Age rating & content rights** _(App Store · App Store Connect (manual))_  
   Complete the age-rating questionnaire; confirm you have the rights to third-party content.
19. **EU trader status** _(App Store · App Store Connect (manual))_  
   To distribute in the EU, declare trader / non-trader status (Digital Services Act); traders publish contact details.
20. **TestFlight first** _(App Store · App Store Connect (manual))_  
   Upload, wait for processing, test the exact build on a real device (fresh install, largest text size, no network) before submitting for review.
21. **iPad** _(App Store · App Store Connect (manual))_  
   The app declares iPad support: App Review tests it on iPad. Check every screen there, or make the app iPhone-only.

## ✅ Done

- **Formatting** _(Quality gates)_ — All files formatted
- **Static analysis** _(Quality gates)_ — No errors or warnings
- **Forbidden patterns** _(Quality gates)_ — None found
- **Tests** _(Quality gates)_ — 1 passed
- **Loading / error / empty states** _(Error handling)_ — Async widgets handle the error state.
- **No raw exception text shown to users** _(Error handling)_ — No exception objects, `e.toString()` or stack traces are put on screen.
- **No status codes or server responses shown to users** _(Error handling)_ — No HTTP status code or response body is put on screen.
- **Server error text is not passed straight to users** _(Error handling)_ — No `data['message']` style server text is put on screen.
- **Error wording is plain language** _(Error handling)_ — No developer wording (exception names, "HTTP 500", "status code") in user-facing strings.
- **No raw print logging** _(Security)_ — No print/debugPrint in lib/.
- **Text follows the phone's font size** _(Responsive & large text)_ — Text size is never locked or capped below 2x.
- **No fixed heights around text** _(Responsive & large text)_ — No fixed-height boxes around text found.
- **Account rules** _(Store requirements)_ — No sign-in or sign-up found in the code, so the account rules were not applied: in-app account deletion, reviewer test account, deletion described in the privacy policy. If the app does have accounts (e.g. through a web view), apply them by hand.
- **No development servers in release code** _(Store policy)_ — No localhost / LAN / staging address reaches a release build unguarded.
- **TODO / FIXME** _(Code health)_ — None in lib/.
- **targetSdk** _(Google Play · SDK levels)_ — targetSdk 36 (Play requires >= 36 for new apps and updates).
- **minSdk** _(Google Play · SDK levels)_ — minSdk 24.
- **Sensitive permissions (main manifest)** _(Google Play · Permissions & policy)_ — None declared in the app manifest. Plugins can add more: build a release once (`flutter build appbundle`) and run this audit again to check the merged manifest.
- **Android Gradle Plugin** _(Google Play · 16 KB page size)_ — AGP 9.0.1.
- **App name (CFBundleDisplayName)** _(App Store · App identity)_ — "Counter App" (shown under the icon; keep it short, about 12 characters, or it is cut off).
- **Signing style** _(App Store · Signing)_ — Automatic signing: Xcode creates the distribution certificate and profile.
- **iPad orientations** _(App Store · Build settings)_ — iPad is supported; multitasking requirements are met.
- **App Transport Security** _(App Store · Network & export compliance)_ — HTTPS only.
- **Permission usage descriptions** _(App Store · Permissions)_ — Every known plugin in pubspec.yaml has its Info.plist keys.

## Quality gates

| Gate | Result | Summary |
|---|---|---|
| Formatting | ✅ Pass | All files formatted |
| Static analysis | ✅ Pass | No errors or warnings |
| Forbidden patterns | ✅ Pass | None found |
| Tests | ✅ Pass | 1 passed |

---
Store details (same folder): `PLAY_READINESS.md` (Google Play), `APP_STORE_READINESS.md` (App Store).
