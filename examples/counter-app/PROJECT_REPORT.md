# Production readiness report — `starter_app`

Generated: 2026-11-25 18:27 · by the flutter-production skill

## ❌ NOT READY — 8 blocking item(s) must be fixed before release.

| ❌ Missing (blocking) | ⚠️ Recommended | 📝 Your manual tasks | ✅ Done |
|:-:|:-:|:-:|:-:|
| **8** | **21** | **11** | **11** |

## ❌ Missing — must fix before release

1. **Global error handlers** _(Error handling)_  
   Missing: FlutterError.onError, PlatformDispatcher.instance.onError. Uncaught errors crash or vanish silently.
   → **Fix:** Add a bootstrap() like templates/starter_app/lib/bootstrap.dart (ERROR-HANDLING.md).
2. **Default counter app** _(Template leftovers)_  
   lib/main.dart is still the `flutter create` counter demo.
   → **Fix:** Replace it with the real app (or install the starter: scripts/install.dart --starter).
3. **Tests** _(Code health)_  
   0 test file(s).
   → **Fix:** Add unit, widget and responsive tests.
4. **android/key.properties** _(Google Play · Signing)_  
   Missing. Release builds would be signed with the debug key and Play rejects them.
   → **Fix:** Create an upload key and android/key.properties (see docs/RELEASE.md).
5. **Release signingConfig** _(Google Play · Signing)_  
   The release build type is signed with the DEBUG key.
   → **Fix:** Run `dart run tool/harden_platforms.dart` or configure signingConfigs.release.
6. **applicationId** _(Google Play · App identity)_  
   "com.example.starter_app" — Play rejects com.example.* and it can never be changed after release.
   → **Fix:** Choose a permanent reverse-domain id you own, e.g. com.yourcompany.app (also update namespace and the Kotlin package).
7. **Launcher icon** _(Google Play · App identity)_  
   Still the default Flutter icon.
   → **Fix:** Generate icons (e.g. flutter_launcher_icons) incl. adaptive + monochrome.
8. **INTERNET permission (main manifest)** _(Google Play · Manifest & security)_  
   Missing: the RELEASE build cannot reach the network (debug works, so this is often missed).
   → **Fix:** Add <uses-permission android:name="android.permission.INTERNET"/> to app/src/main/AndroidManifest.xml.

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
12. **pubspec.lock committed** _(Code health)_  
   pubspec.lock is not committed: builds are not reproducible.
   → **Fix:** Commit pubspec.lock (apps should).
13. **CI pipeline** _(Code health)_  
   No CI: nothing stops a broken build from shipping.
   → **Fix:** Copy templates/starter_app/.github/workflows/ci.yml.
14. **Export compliance key** _(iOS)_  
   Missing: App Store Connect asks the export-compliance question on every upload.
   → **Fix:** Add ITSAppUsesNonExemptEncryption (false if you only use HTTPS / OS crypto).
15. **Privacy manifest** _(iOS)_  
   No app privacy manifest (App Store requires declaring "required reason" APIs).
   → **Fix:** Add ios/Runner/PrivacyInfo.xcprivacy in Xcode (File > New > App Privacy).
16. **versionCode** _(Google Play · App identity)_  
   versionName 1.0.0, versionCode 1. Must be higher than every previous upload (pass --last-version-code to verify).
17. **App name (android:label)** _(Google Play · App identity)_  
   "starter_app" looks like the package name, not a user-facing name.
   → **Fix:** Set android:label to the real app name (or a @string resource for localization).
18. **Cleartext HTTP** _(Google Play · Manifest & security)_  
   No network security config.
   → **Fix:** Run tool/harden_platforms.dart.
19. **Backups** _(Google Play · Manifest & security)_  
   App data (incl. caches) can be copied by adb/cloud backup.
   → **Fix:** Set allowBackup="false" and add dataExtractionRules.
20. **App bundle (.aab)** _(Google Play · Release bundle)_  
   Not built yet (build/app/outputs/bundle/release/app-release.aab).
   → **Fix:** flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json
21. **.gitignore** _(Google Play · Secrets)_  
   key.properties / *.jks are not ignored at the repo root.
   → **Fix:** Run tool/harden_platforms.dart.

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
6. **Account deletion** _(Google Play · Play Console (manual))_  
   If users can create accounts: in-app deletion path + public web deletion URL in the Data safety form.
7. **Content rating & target audience** _(Google Play · Play Console (manual))_  
   Complete the questionnaire; children in audience triggers the Families policy.
8. **Ads declaration** _(Google Play · Play Console (manual))_  
   Declare whether the app contains ads.
9. **Closed testing (new personal accounts)** _(Google Play · Play Console (manual))_  
   Personal accounts created after 13 Nov 2023: closed test with >= 12 testers opted in for 14 continuous days before production access.
10. **Store listing assets** _(Google Play · Play Console (manual))_  
   512x512 icon, 1024x500 feature graphic, >= 2 phone screenshots (+ 7"/10" tablet screenshots for tablet visibility).
11. **Pre-launch report** _(Google Play · Play Console (manual))_  
   Upload to internal testing first; fix crashes/accessibility/security issues it reports.

## ✅ Done

- **No raw error text shown to users** _(Error handling)_ — No `Text(error.toString())` style messages found.
- **Loading / error / empty states** _(Error handling)_ — Async widgets handle the error state.
- **No raw print logging** _(Security)_ — No print/debugPrint in lib/.
- **Text follows the phone's font size** _(Responsive & large text)_ — Text size is never locked or capped below 2x.
- **No fixed heights around text** _(Responsive & large text)_ — No fixed-height boxes around text found.
- **TODO / FIXME** _(Code health)_ — None in lib/.
- **targetSdk** _(Google Play · SDK levels)_ — targetSdk 36 (Play requires >= 36 for new apps and updates).
- **minSdk** _(Google Play · SDK levels)_ — minSdk 24.
- **Sensitive permissions (main manifest)** _(Google Play · Permissions & policy)_ — None declared in the app manifest. Plugins can add more: check the merged manifest (build/app/intermediates/merged_manifests) or Play Console > App bundle explorer.
- **Android Gradle Plugin** _(Google Play · 16 KB page size)_ — AGP 9.3.1.
- **Keystore / key.properties not in git** _(Google Play · Secrets)_ — No signing secrets are tracked.

> Quality gates skipped in this example (generated without the Flutter SDK). Normally format, analyze and tests run here.

---
Google Play details: `PLAY_READINESS.md` (same folder).
