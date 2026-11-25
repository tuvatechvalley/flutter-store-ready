# Google Play readiness report

Generated: 2026-11-25T23:40:38.544669  
Project: `untouched`

**❌ NOT READY — fix the FAIL items before uploading.**

| Result | Count |
|---|---|
| ❌ FAIL | 5 |
| ⚠️ WARN | 6 |
| ✅ PASS | 4 |
| 📝 MANUAL | 10 |


## Signing

| Result | Check | Details | How to fix |
|---|---|---|---|
| ❌ FAIL | android/key.properties | Missing. Release builds would be signed with the debug key and Play rejects them. | Create an upload key and android/key.properties (see GOOGLE-PLAY-RELEASE.md in the flutter-store-ready skill). |
| ❌ FAIL | Release signingConfig | The release build type is signed with the DEBUG key. | Run `dart run tool/flutter_store_ready/harden_platforms.dart` or configure signingConfigs.release. |

## App identity

| Result | Check | Details | How to fix |
|---|---|---|---|
| ❌ FAIL | applicationId | "com.example.counter_app" — Play rejects com.example.* and it can never be changed after release. | Choose a permanent reverse-domain id you own, e.g. com.yourcompany.app (also update namespace and the Kotlin package). |
| ⚠️ WARN | versionCode | versionName 1.0.0, versionCode 1. Must be higher than every previous upload (pass --last-version-code to verify). |  |
| ⚠️ WARN | App name (android:label) | "counter_app" looks like the package name, not a user-facing name. | Set android:label to the real app name (or a @string resource for localization). |
| ❌ FAIL | Launcher icon | Still the default Flutter icon. | Generate icons (e.g. flutter_launcher_icons) incl. adaptive + monochrome. |

## SDK levels

| Result | Check | Details | How to fix |
|---|---|---|---|
| ✅ PASS | targetSdk | targetSdk 36 (Play requires >= 36 for new apps and updates). |  |
| ✅ PASS | minSdk | minSdk 24. |  |

## Manifest & security

| Result | Check | Details | How to fix |
|---|---|---|---|
| ❌ FAIL | INTERNET permission (main manifest) | Missing: the RELEASE build cannot reach the network (debug works, so this is often missed). | Add <uses-permission android:name="android.permission.INTERNET"/> to app/src/main/AndroidManifest.xml. |
| ⚠️ WARN | Cleartext HTTP | No network security config. | Run `dart run tool/flutter_store_ready/harden_platforms.dart`. |
| ⚠️ WARN | Backups | App data (incl. caches) can be copied by adb/cloud backup. | Set allowBackup="false" and add dataExtractionRules. |

## Permissions & policy

| Result | Check | Details | How to fix |
|---|---|---|---|
| ✅ PASS | Sensitive permissions (main manifest) | None declared in the app manifest. Plugins can add more: build a release once (`flutter build appbundle`) and run this audit again to check the merged manifest. |  |

## 16 KB page size

| Result | Check | Details | How to fix |
|---|---|---|---|
| ✅ PASS | Android Gradle Plugin | AGP 9.0.1. |  |
| 📝 MANUAL | Plugin native libraries | Every plugin with .so files must be 16 KB aligned. | After uploading, open Play Console > App bundle explorer > "Memory page size" — it must say compliant. |

## Release bundle

| Result | Check | Details | How to fix |
|---|---|---|---|
| ⚠️ WARN | App bundle (.aab) | Not built yet (build/app/outputs/bundle/release/app-release.aab). | flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json |

## Secrets

| Result | Check | Details | How to fix |
|---|---|---|---|
| ⚠️ WARN | Tracked secrets | Not a git repository; could not check tracked files. |  |

## Play Console (manual)

| Result | Check | Details | How to fix |
|---|---|---|---|
| 📝 MANUAL | Play App Signing | Enrolled (default for new apps). Upload key ≠ app signing key; keep the upload key backed up. |  |
| 📝 MANUAL | Privacy policy | Public HTTPS URL in Store listing and inside the app (Settings/About). |  |
| 📝 MANUAL | Data safety form | Declare every data type collected by you AND SDKs (e.g. Sentry crash data, device ids). |  |
| 📝 MANUAL | Account deletion | If users can create accounts: in-app deletion path + public web deletion URL in the Data safety form. |  |
| 📝 MANUAL | Content rating & target audience | Complete the questionnaire; children in audience triggers the Families policy. |  |
| 📝 MANUAL | Ads declaration | Declare whether the app contains ads. |  |
| 📝 MANUAL | Closed testing (new personal accounts) | Personal accounts created after 13 Nov 2023: closed test with >= 12 testers opted in for 14 continuous days before production access. |  |
| 📝 MANUAL | Store listing assets | 512x512 icon, 1024x500 feature graphic, >= 2 phone screenshots (+ 7"/10" tablet screenshots for tablet visibility). |  |
| 📝 MANUAL | Pre-launch report | Upload to internal testing first; fix crashes/accessibility/security issues it reports. |  |
