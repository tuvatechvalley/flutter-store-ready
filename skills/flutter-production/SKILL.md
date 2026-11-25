---
name: flutter-production
description: Build, harden and audit Flutter mobile apps to store-release quality — global error handling, security (OWASP MASVS), responsive layouts that survive 200–300% system font size, and a Google Play readiness check (keystore, signing, targetSdk, permissions). Use when creating a Flutter app, making an existing one production-ready, auditing it, or preparing a Google Play / App Store release. Always ends with a written report of what is done and what is missing.
---

# Flutter production

Goal: the user gets an app that behaves like a real store app — it does not crash, shows proper loading/error/empty states, never looks broken (any screen size, any font size), keeps data safe, and can be uploaded to Google Play. Every task ends with a **report** (`PROJECT_REPORT.md`) listing what is done and what is still missing.

Talk to the user in their language. Reports are written in English.

## Files in this skill

`<skill>` below means the directory that contains this SKILL.md.

| File | Read when |
|---|---|
| `ERROR-HANDLING.md` | writing any data-loading screen, repository or app bootstrap |
| `SECURITY.md` | auth, tokens, networking, storage, logging, release builds |
| `RESPONSIVE-AND-LARGE-TEXT.md` | writing or reviewing any UI |
| `GOOGLE-PLAY-RELEASE.md` | signing, keystore, versioning, store listing, release |
| `AUDIT-AND-REPORTING.md` | auditing an existing app, writing the final report |
| `scripts/` | the tools below (pure `dart:io`, run on Windows/macOS/Linux) |
| `templates/starter_app/` | a complete reference app implementing every rule |

Scripts (run from the Flutter project root, or pass the project path):

| Script | Does |
|---|---|
| `scripts/install.dart <project> [--starter]` | installs the toolkit into a project: `tool/flutter_production/`, strict `analysis_options.yaml`, CI workflow, `.gitignore`/`.gitattributes`, Android/iOS hardening. `--starter` also installs the reference app code into a fresh `flutter create` project |
| `tool/flutter_production/verify.dart [--release]` | after install: `pub get`, (release AAB), then the full report |
| `scripts/project_report.dart [project]` | the audit: quality gates + error handling + security + large text + store rules + Google Play → `build/reports/flutter-production/PROJECT_REPORT.md` and `findings.json` |
| `scripts/play_readiness.dart [project]` | Google Play audit only: key.properties, keystore (keytool), release signing, applicationId, targetSdk ≥ 36, icon, INTERNET permission, cleartext, backups, sensitive permissions, 16 KB, AAB signature, secrets in git → `PLAY_READINESS.md` |
| `scripts/check_forbidden.dart [project]` | fails on print, http://, disabled TLS checks, hard-coded secrets, tokens in SharedPreferences, empty catch |
| `scripts/harden_platforms.dart [project] [--secure-screens]` | INTERNET permission, backup/extraction rules, network security config, release signing from key.properties, R8, optional FLAG_SECURE |

## Workflows

Pick the one matching the request. Do not skip the final report.

### A. New app

1. `flutter create --org com.<company> --platforms=android,ios <app_name>` (ask for the real org/app id if unknown — it is permanent on the stores; never `com.example`).
2. `dart run <skill>/scripts/install.dart <app_name> --starter`
   This gives: bootstrap with every error path covered, typed failures, Dio with SPKI pinning/retry/token refresh, secure storage, adaptive shell, large-text scaling, TR/EN localization, login + settings (theme, language, text size, privacy policy, delete account), tests incl. the responsive/large-text matrix, CI.
3. `cd <app_name> && flutter pub get`, then build the user's features on top, following the patterns already in `lib/` (repository → `guardFailures`; controller → Riverpod `AsyncNotifier`; screen → `AsyncValueView` + `ResponsiveCenter`; strings → `AppLocalizations` in every language; screen added to `test/responsive_test.dart`).
4. Replace leftovers: app name, brand color, the sample "Items" feature, `config/prod.json`.
5. Final report (section "Finish").

### B. Make an existing app production-ready

1. `dart run <skill>/scripts/install.dart .` (never `--starter` on existing code).
2. `dart run tool/flutter_production/verify.dart` → read `PROJECT_REPORT.md`.
3. Show the user the blocking items and the plan; fix in this order: crashes & global error handling → security → large text / responsive → store requirements → leftovers. Port pieces from `templates/starter_app/lib/core/` instead of reinventing them.
4. Re-run verify until no ❌ remains (or the user accepts the rest). Final report.

### C. Audit only ("check my app", "is it ready for Play?", "keystore var mı?")

1. `dart run <skill>/scripts/project_report.dart .` (add `--last-version-code N` if known).
2. Also read the code for what scripts cannot judge (see `AUDIT-AND-REPORTING.md`) and add those findings with file:line.
3. Deliver the report. Do not change code unless asked.

### D. Release preparation

Follow `GOOGLE-PLAY-RELEASE.md`: upload keystore + `android/key.properties`, version bump, `config/prod.json`, then `dart run tool/flutter_production/verify.dart --release` and fix every ❌ in `PLAY_READINESS.md`.

## Non-negotiable rules

Error handling (details: `ERROR-HANDLING.md`)
- Bootstrap sets `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `ErrorWidget.builder`, provider/bloc error observer, crash reporting.
- Every thrown error is mapped to a typed failure at the repository boundary. Users never see `e.toString()`; they see a localized message and, when it makes sense, "Try again".
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

Store
- Account deletion in-app (+ web URL) when users can sign up; privacy policy link in the app; targetSdk ≥ 36 (Play, since 2026-08-31); real applicationId; custom icon; release signed with the upload key.

Flutter ≥ 3.47: import `package:material_ui/material_ui.dart` (not `package:flutter/material.dart`, deprecated). Riverpod 3: pass `retry: (_, _) => null` to `ProviderScope` when the UI offers its own retry. Verify current package and policy versions before relying on them.

## Finish (mandatory)

Before saying the work is done:

1. Run `dart run tool/flutter_production/verify.dart` (or `dart run <skill>/scripts/project_report.dart .` if the toolkit is not installed).
2. Give the user the file `build/reports/flutter-production/PROJECT_REPORT.md` (and `PLAY_READINESS.md` for release work).
3. In chat, in the user's language, 3–6 lines: the verdict, the blocking items, what you fixed, and the single next step. Do not paste the whole report.

If `flutter` is not installed where you run, say that gates were skipped and which ones; never claim tests passed when they did not run.
