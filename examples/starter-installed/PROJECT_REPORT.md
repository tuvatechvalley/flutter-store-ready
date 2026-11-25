# Production readiness report — `acme_notes`

Generated: 2026-11-25 18:27 · by the flutter-production skill

## ❌ NOT READY — 4 blocking item(s) must be fixed before release.

| ❌ Missing (blocking) | ⚠️ Recommended | 📝 Your manual tasks | ✅ Done |
|:-:|:-:|:-:|:-:|
| **4** | **10** | **10** | **31** |

## ❌ Missing — must fix before release

1. **config/prod.json** _(Production config)_  
   No production configuration file.
   → **Fix:** Copy config/prod.example.json to config/prod.json and fill it in (git-ignored).
2. **android/key.properties** _(Google Play · Signing)_  
   Missing. Release builds would be signed with the debug key and Play rejects them.
   → **Fix:** Create an upload key and android/key.properties (see docs/RELEASE.md).
3. **applicationId** _(Google Play · App identity)_  
   "com.example.starter_app" — Play rejects com.example.* and it can never be changed after release.
   → **Fix:** Choose a permanent reverse-domain id you own, e.g. com.yourcompany.app (also update namespace and the Kotlin package).
4. **Launcher icon** _(Google Play · App identity)_  
   Still the default Flutter icon.
   → **Fix:** Generate icons (e.g. flutter_launcher_icons) incl. adaptive + monochrome.

## ⚠️ Recommended

1. **pubspec description** _(Template leftovers)_  
   Still the template description.
   → **Fix:** Describe your app in pubspec.yaml.
2. **App title (starter)** _(Template leftovers)_  
   The app is still called "Starter".
   → **Fix:** Change appTitle in lib/core/l10n/app_localizations.dart.
3. **Brand color (starter)** _(Template leftovers)_  
   Still the starter's default seed color.
   → **Fix:** Set AppTheme.seed to the brand color.
4. **Sample "Items" feature (starter)** _(Template leftovers)_  
   The demo feature from the starter is still in the app.
   → **Fix:** Replace it with real features (keep: repository + AsyncValueView + tests).
5. **pubspec.lock committed** _(Code health)_  
   pubspec.lock is not committed: builds are not reproducible.
   → **Fix:** Commit pubspec.lock (apps should).
6. **Export compliance key** _(iOS)_  
   Missing: App Store Connect asks the export-compliance question on every upload.
   → **Fix:** Add ITSAppUsesNonExemptEncryption (false if you only use HTTPS / OS crypto).
7. **Privacy manifest** _(iOS)_  
   No app privacy manifest (App Store requires declaring "required reason" APIs).
   → **Fix:** Add ios/Runner/PrivacyInfo.xcprivacy in Xcode (File > New > App Privacy).
8. **versionCode** _(Google Play · App identity)_  
   versionName 1.0.0, versionCode 1. Must be higher than every previous upload (pass --last-version-code to verify).
9. **App name (android:label)** _(Google Play · App identity)_  
   "starter_app" looks like the package name, not a user-facing name.
   → **Fix:** Set android:label to the real app name (or a @string resource for localization).
10. **App bundle (.aab)** _(Google Play · Release bundle)_  
   Not built yet (build/app/outputs/bundle/release/app-release.aab).
   → **Fix:** flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json

## 📝 Your manual tasks (outside the code)

1. **Plugin native libraries** _(Google Play · 16 KB page size)_  
   Every plugin with .so files must be 16 KB aligned.
   → **Fix:** After uploading, open Play Console > App bundle explorer > "Memory page size" — it must say compliant.
2. **Play App Signing** _(Google Play · Play Console (manual))_  
   Enrolled (default for new apps). Upload key ≠ app signing key; keep the upload key backed up.
3. **Privacy policy** _(Google Play · Play Console (manual))_  
   Public HTTPS URL in Store listing and inside the app (Settings/About).
4. **Data safety form** _(Google Play · Play Console (manual))_  
   Declare every data type collected by you AND SDKs (e.g. Sentry crash data, device ids).
5. **Account deletion** _(Google Play · Play Console (manual))_  
   If users can create accounts: in-app deletion path + public web deletion URL in the Data safety form.
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

## ✅ Done

- **Global error handlers** _(Error handling)_ — Framework and async errors are caught centrally.
- **Friendly build-error widget** _(Error handling)_ — ErrorWidget.builder is customized.
- **Crash reporting** _(Error handling)_ — A crash reporting SDK is installed.
- **No raw error text shown to users** _(Error handling)_ — No `Text(error.toString())` style messages found.
- **Loading / error / empty states** _(Error handling)_ — Async widgets handle the error state.
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
- **TODO / FIXME** _(Code health)_ — None in lib/.
- **Strict static analysis** _(Code health)_ — Strict analyzer settings enabled.
- **Tests** _(Code health)_ — 13 test file(s).
- **CI pipeline** _(Code health)_ — CI configuration found.
- **Release signingConfig** _(Google Play · Signing)_ — Release uses signingConfigs "release" from key.properties.
- **targetSdk** _(Google Play · SDK levels)_ — targetSdk 36 (Play requires >= 36 for new apps and updates).
- **minSdk** _(Google Play · SDK levels)_ — minSdk 24.
- **INTERNET permission (main manifest)** _(Google Play · Manifest & security)_ — Present.
- **Cleartext HTTP** _(Google Play · Manifest & security)_ — Blocked via network security config.
- **Backups** _(Google Play · Manifest & security)_ — allowBackup="false".
- **Sensitive permissions (main manifest)** _(Google Play · Permissions & policy)_ — None declared in the app manifest. Plugins can add more: check the merged manifest (build/app/intermediates/merged_manifests) or Play Console > App bundle explorer.
- **Android Gradle Plugin** _(Google Play · 16 KB page size)_ — AGP 9.3.1.
- **Keystore / key.properties not in git** _(Google Play · Secrets)_ — No signing secrets are tracked.

> Quality gates skipped in this example (generated without the Flutter SDK). Normally format, analyze and tests run here.

---
Google Play details: `PLAY_READINESS.md` (same folder).
