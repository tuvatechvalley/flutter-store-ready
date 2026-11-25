---
name: flutter-store-ready
description: Build and harden Flutter mobile apps to store-release quality — global error handling with user-friendly error messages, security (OWASP MASVS), responsive layouts that survive 200–300% system font size, navigation and permission pitfalls, store policies, Google Play signing (keystore, key.properties, targetSdk) and App Store setup (bundle id, signing team, Info.plist, privacy manifest). Use when creating a Flutter app, making an existing one production-ready or fixing what an audit found, or preparing a release. For a read-only audit use store-review; for store forms store-forms; for a rejection store-rejection. Always ends with a written report of what is done and what is missing.
---

# Flutter store-ready

Goal: the user gets an app that behaves like a real store app — it does not crash, shows proper loading/error/empty states, never looks broken (any screen size, any font size), keeps data safe, and can be uploaded to Google Play and the App Store. Every task ends with a **report** (`PROJECT_REPORT.md`) listing what is done and what is still missing.

Talk to the user in their language. Reports are written in English.

## Files in this skill

`<skill>` below means the directory that contains this SKILL.md.

| File | Read when |
|---|---|
| `ERROR-HANDLING.md` | writing any data-loading screen, repository or app bootstrap |
| `SECURITY.md` | auth, tokens, networking, storage, logging, release builds |
| `RESPONSIVE-AND-LARGE-TEXT.md` | writing or reviewing any UI |
| `NAVIGATION-AND-LIFECYCLE.md` | tabs, back button, menus and dialogs that start actions, permission prompts, background services, dev servers |
| `STORE-POLICIES.md` | the app has purchases, ads, user content, AI features, sign-in or Google services (Maps, sign-in) |
| `GOOGLE-PLAY-RELEASE.md` | Android signing, keystore, versioning, Play Console, release |
| `APP-STORE-RELEASE.md` | iOS bundle id, signing team, Info.plist, privacy, TestFlight, App Store Connect, review |
| `AUDIT-AND-REPORTING.md` | auditing an existing app, writing the final report |
| `scripts/` | the tools below (pure `dart:io`, run on Windows/macOS/Linux) |
| `templates/starter_app/` | a complete reference app implementing every rule |

Scripts (run from the Flutter project root, or pass the project path):

| Script | Does |
|---|---|
| `scripts/install.dart <project> [--starter]` | installs the toolkit into a project: `tool/flutter_store_ready/`, strict `analysis_options.yaml`, CI workflow, `.gitignore`/`.gitattributes`, Android/iOS hardening. `--starter` also installs the reference app code into a fresh `flutter create` project |
| `tool/flutter_store_ready/verify.dart [--release] [--ci]` | after install: `pub get`, (release AAB), then the full report. `--ci` (pipelines): a missing upload key / `config/prod.json` is a warning, not a blocker |
| `scripts/project_report.dart [project]` | the audit: quality gates + error handling + user-friendly error messages + security + large text + navigation & permissions + store rules + store policy (purchases, ads, user content, AI, data declarations) + Google Play + App Store → `build/reports/flutter-store-ready/PROJECT_REPORT.md` and `findings.json` |
| `scripts/play_readiness.dart [project]` | Google Play audit only: key.properties, keystore (keytool), release signing, applicationId, targetSdk ≥ 36, icon, INTERNET permission, cleartext, backups, sensitive permissions, 16 KB, AAB signature, secrets in git → `PLAY_READINESS.md` |
| `scripts/app_store_readiness.dart [project]` | App Store audit only, from the project files (runs on Windows/Linux too; only the build needs a Mac): bundle id, signing team, version/build, 1024 px icon (default / alpha), deployment target, iPad orientations, ATS, export compliance, permission keys and their wording, privacy manifest, tracking/ATT, Sign in with Apple, push entitlement, background modes, certificates in git → `APP_STORE_READINESS.md` |

| `scripts/check_forbidden.dart [project]` | blocking (exit 1): http://, disabled TLS checks, hard-coded secrets, tokens in SharedPreferences. Warning only: print / debugPrint, empty catch |
| `scripts/harden_platforms.dart [project] [--secure-screens]` | INTERNET permission, backup/extraction rules, strict network security config for release + a debug-only one that allows plain HTTP to a dev server, release signing from key.properties (Kotlin and Groovy Gradle files), R8, optional FLAG_SECURE |

## Workflows

Pick the one matching the request. Do not skip the final report.

### A. New app

1. `flutter create --org com.<company> --platforms=android,ios <app_name>` (ask for the real org/app id if unknown — it is permanent on the stores; never `com.example`).
2. `dart run <skill>/scripts/install.dart <app_name> --starter`
   The starter needs the Flutter version in `templates/starter_app/pubspec.yaml` (currently ≥ 3.47). On an older Flutter the script installs the toolkit but refuses the starter: tell the user, and ask before running `flutter upgrade` — never upgrade their SDK silently, never use `--force` to get around it.
   This gives: bootstrap with every error path covered, typed failures, Dio with SPKI pinning/retry/token refresh, secure storage, adaptive shell, large-text scaling, TR/EN localization, login + settings (theme, language, text size, privacy policy, delete account), tests incl. the responsive/large-text matrix, CI.
3. `cd <app_name> && flutter pub get`, then build the user's features on top, following the patterns already in `lib/` (repository → `guardFailures`; controller → Riverpod `AsyncNotifier`; screen → `AsyncValueView` + `ResponsiveCenter`; strings → `AppLocalizations` in every language; screen added to `test/responsive_test.dart`; nested routes covered by `test/navigation_test.dart`).
4. Replace leftovers: app name, brand color, the sample "Items" feature, `config/prod.json`.
5. Final report (section "Finish").

### B. Make an existing app production-ready

1. `dart run <skill>/scripts/install.dart .` (never `--starter` on existing code). If it warns that the project still allows Dart 2, do not change the SDK constraint on your own: run the scripts from `<skill>/scripts/` instead of `tool/`, and tell the user.
2. `dart run tool/flutter_store_ready/verify.dart` → read `PROJECT_REPORT.md`.
3. Show the user the blocking items and the plan; fix in this order: crashes & global error handling → security → large text / responsive → store requirements → leftovers. Port pieces from `templates/starter_app/lib/core/` instead of reinventing them.
4. Re-run verify until no ❌ remains (or the user accepts the rest). Final report.

### C. Audit only → the `store-review` skill

A read-only audit ("check my app", "is it ready for Play / the App Store?", "keystore var mı?") is the job of the **store-review** skill in this repository: follow it. Store forms (Data safety, App Privacy) → **store-forms**; a rejection from Apple or Google → **store-rejection**. All three use this skill's scripts and guides.

### D. Release preparation

- **Google Play**: follow `GOOGLE-PLAY-RELEASE.md`: upload keystore + `android/key.properties`, version bump, `config/prod.json`, then `dart run tool/flutter_store_ready/verify.dart --release` and fix every ❌ in `PLAY_READINESS.md`.
- **App Store**: follow `APP-STORE-RELEASE.md`: bundle id, team in Xcode, icon, permission texts, privacy manifest, then the same `verify.dart --release` and fix every ❌ in `APP_STORE_READINESS.md`. The iOS archive is only built on macOS; on Windows/Linux say plainly that the project files were audited but no iOS build was made, and that the user needs a Mac or a macOS CI runner for `flutter build ipa` and the upload. Never set `ITSAppUsesNonExemptEncryption` or pick a signing team for the user — those are their declarations.

## Non-negotiable rules

Error handling (details: `ERROR-HANDLING.md`)
- Bootstrap sets `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `ErrorWidget.builder`, provider/bloc error observer, crash reporting.
- Every thrown error is mapped to a typed failure at the repository boundary. Users never see `e.toString()`; they see a localized message and, when it makes sense, "Try again".
- Error messages are written for non-technical users: what happened + what to do, in their language. Never on screen: exception text, HTTP status codes, response bodies, server messages passed through, words like "Exception" / "HTTP 500" / "status code". Technical detail goes to the logger only.
- Every data screen renders loading, error (+ retry), empty and data. Refresh keeps old data visible. Pagination errors keep the loaded list.
- Defensive JSON parsing; `mounted` checks after `await`; cancel requests of closed screens; no empty `catch`.

Security (details: `SECURITY.md`)
- Tokens only in Keychain/Keystore (`flutter_secure_storage`); wipe on reinstall; nothing secret in code, assets or `--dart-define`.
- HTTPS only (fail closed in release); SPKI pinning with ≥ 2 pins for own APIs; never accept bad certificates; timeouts; single-flight token refresh using a separate Dio (avoids deadlock).
- Redacting logger, no `print`; validate deep-link params and redirects; `--obfuscate --split-debug-info`; secrets scan + dependency scan in CI.

Responsive & large text (details: `RESPONSIVE-AND-LARGE-TEXT.md`)
- Text follows the system font size up to 3× (200% Android, ~310% iOS). Never `TextScaler.noScaling`, never cap below 2×. Only navigation bars may be capped (~1.3×) with tooltips.
- Layout breakpoints use width ÷ text scale. No fixed heights around text. Everything that can overflow scrolls. Dialogs `scrollable: true`. `Wrap` for chip/button groups. `SafeArea`. Min 48dp targets, tooltips/semantics.
- Every screen is in a widget test matrix: 5 sizes × 100/150/200/300% text × every locale; `tester.takeException()` must be null.

Navigation, lifecycle and permissions (details: `NAVIGATION-AND-LIFECYCLE.md`)
- The Android back button goes up one level, never out of the app from a nested page — with a test that presses it.
- `if (!mounted) return;` guards UI updates only; an action started from a menu, sheet or dialog runs through a long-lived notifier captured before the await.
- Permissions are requested where the feature is used and only from the roles that need it — never at launch.
- Background code (push handler, workmanager, location service) has its own session; it never shares a rotating refresh token with the app.
- Plain HTTP only through the debug-only network config; no dev address reaches a release build.

Store policy (details: `STORE-POLICIES.md`; applies only when the app has the feature)
- Purchases: "Restore purchases", a paywall that shows price / period / renewal / Terms + Privacy links, store billing for digital goods.
- Ads: consent flow before the ad SDK starts; on iOS the tracking prompt is really shown; test ad units in every non-store build.
- User content: report and block. AI features: disclosure + consent before personal data leaves, in-app reporting of generated content.
- What the SDKs collect is declared identically in Data safety, App Privacy and the privacy policy.

Store
- When the app has sign-in: tell the user they must create a **reviewer test account** and enter it in Play Console (App content > App access) and App Store Connect (App Review Information) — never-expiring, with sample data, no SMS/e-mail code. Say this in the chat summary, not only in the report.
- When users can delete their account: the privacy policy / terms must describe it (how, what is deleted, what is kept and for how long, contact). If the legal text is in the app the audit reads it; otherwise open the policy URL and check.
- Account deletion in-app (+ web URL) when users can sign up; privacy policy link in the app; targetSdk ≥ 36 (Play, since 2026-08-31); real applicationId; custom icon; release signed with the upload key.
- iOS: real bundle id; signing team set; opaque custom 1024 px icon; deployment target ≥ 13 (≥ 15 from April 2027); every permission has a usage description that explains the benefit to the user; privacy manifest in the Runner target; Sign in with Apple next to third-party logins; ATT before tracking; digital goods through in-app purchase.

Flutter ≥ 3.47: import `package:material_ui/material_ui.dart` (not `package:flutter/material.dart`, deprecated). Riverpod 3: pass `retry: (_, _) => null` to `ProviderScope` when the UI offers its own retry. Verify current package and policy versions before relying on them.

## Finish (mandatory)

Before saying the work is done:

1. Run `dart run tool/flutter_store_ready/verify.dart` (or `dart run <skill>/scripts/project_report.dart .` if the toolkit is not installed).
2. Give the user the file `build/reports/flutter-store-ready/PROJECT_REPORT.md` (and `PLAY_READINESS.md` / `APP_STORE_READINESS.md` for release work).
3. In chat, in the user's language, 3–6 lines: the verdict, the blocking items, what you fixed, and the single next step. Do not paste the whole report.

If `flutter` is not installed where you run, say that gates were skipped and which ones; never claim tests passed when they did not run.
