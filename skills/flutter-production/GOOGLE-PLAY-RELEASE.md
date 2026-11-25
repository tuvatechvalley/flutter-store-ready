# Google Play release

Audit at any time: `dart run <skill>/scripts/play_readiness.dart .` → `PLAY_READINESS.md` (also part of `project_report.dart`).

## 1. Permanent identity

`applicationId` cannot change after the first upload; `com.example.*` is rejected. Set it at `flutter create --org` time or in `android/app/build.gradle(.kts)` (and `namespace`).

## 2. Upload key

Play App Signing: Google keeps the app signing key, you keep the **upload key**.

```sh
keytool -genkeypair -v -keystore ~/keys/upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 4096 -validity 10000 -alias upload
```

`android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/Users/you/keys/upload-keystore.jks
```

On Windows: `storeFile=C:\\Users\\you\\keys\\upload-keystore.jks` (escaped backslashes) or forward slashes.

`scripts/harden_platforms.dart` wires `signingConfigs.release` to key.properties (falls back to debug signing with a loud warning so local release builds still run). Keep the keystore outside the repo, back it up encrypted, passwords in a password manager. If a keystore or key.properties was ever committed: create a new key and request an upload key reset — removing it from history is not enough.

The audit checks: key.properties fields, keystore exists, alias/password correct (keytool via environment variable, passwords never printed), not the Android debug certificate, validity ≥ 25 years, release not debug-signed, AAB signature.

## 3. Version

`pubspec.yaml` → `version: 1.2.0+12`. `+12` is versionCode: strictly higher on every upload. `--last-version-code 11` makes the audit verify it.

## 4. SDK levels and native

- targetSdk ≥ **36** for new apps and updates since 2026-08-31 (re-check every year: Play raises it each August 31). Flutter's default `flutter.targetSdkVersion` is 36 on current stable.
- 16 KB page size support (apps targeting Android 15+): AGP ≥ 8.5.1, NDK r28+, check App bundle explorer after upload.
- Main manifest must contain `android.permission.INTERNET` — `flutter create` puts it only in debug/profile, so release builds silently have no network.

## 5. Build

```sh
dart run tool/flutter_production/verify.dart --release --config config/prod.json
# = flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
#   --dart-define-from-file=config/prod.json  + full report
```

Keep `build/symbols/` privately (upload to your crash reporter) — obfuscated stack traces are unreadable without it.

## 6. Play Console (manual — listed in the report)

| Item | Notes |
|---|---|
| Privacy policy | Public HTTPS URL in the listing and inside the app |
| Data safety | Every data type you and your SDKs collect (crash data included) |
| Account deletion | If users can create accounts: in-app path + public web deletion URL |
| Content rating, target audience, ads | Required questionnaires; children → Families policy |
| Closed testing | Personal accounts created after 2023-11-13: ≥ 12 testers opted in for 14 continuous days before production access |
| Store assets | 512×512 icon, 1024×500 feature graphic, ≥ 2 phone screenshots (+ 7"/10" tablet for tablet visibility) |
| Pre-launch report | Upload to internal testing first and fix what it finds |
| Sensitive permissions | SMS/Call log, QUERY_ALL_PACKAGES, MANAGE_EXTERNAL_STORAGE, background location, READ_MEDIA_*, foreground service types… need declarations; prefer the photo picker |
