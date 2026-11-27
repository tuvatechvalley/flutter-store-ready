---
name: flutter-store-ready
description: Build and harden Flutter mobile apps to store-release quality — global error handling with user-friendly error messages, security (OWASP MASVS), responsive layouts that survive 200–300% system font size, navigation and permission pitfalls, store policies, Google Play signing (keystore, key.properties, targetSdk) and App Store setup (bundle id, signing team, Info.plist, privacy manifest). Adapts to existing BLoC, Provider, Riverpod, classic Material and monorepo projects without rewrites. For a read-only audit use store-review; for store forms store-forms; for a rejection store-rejection. Always ends with a written report.
---

# Flutter store-ready

Goal: deliver an app that behaves like a real store release — never crashes silently, renders loading / error + retry / empty / data states, survives any screen size and 200–300% system text scale, protects user data, and passes Google Play and App Store validation. Every task ends with `PROJECT_REPORT.md`.

Talk to the user in their language. Write reports in English.

## Reference guides (load on demand)

`<skill>` = the directory containing this `SKILL.md`. Read only the guides relevant to your current step:

| Guide | Read when |
|---|---|
| `EXISTING-PROJECTS.md` | hardening an existing app (BLoC/Cubit, Provider, `auto_route`, `flutter/material.dart`, Flutter < 3.47, or `packages/*` monorepos) |
| `ERROR-HANDLING.md` | writing app bootstrap, repositories, error mapping, or any data-loading screen |
| `SECURITY.md` | auth, token refresh, TLS pinning, secure storage, redacting logs, deep links, release hardening |
| `RESPONSIVE-AND-LARGE-TEXT.md` | building or fixing UI layouts, themes, dialogs, or widget tests |
| `NAVIGATION-AND-LIFECYCLE.md` | tabs, Android back button, actions started from menus/dialogs, permissions, background isolates, dev servers |
| `STORE-POLICIES.md` | purchases/subscriptions, ads & consent, UGC, AI features, accounts, SHA fingerprints, children's apps |
| `GOOGLE-PLAY-RELEASE.md` | Android upload key, `key.properties`, `targetSdk`, 16 KB pages, merged manifest, Play Console |
| `APP-STORE-RELEASE.md` | iOS bundle id, signing team, `Info.plist`, `PrivacyInfo.xcprivacy`, ATT, TestFlight, App Store Connect |
| `AUDIT-AND-REPORTING.md` | running audits, interpreting heuristics, formatting the final report |

## Toolkit scripts (`<skill>/scripts/`, pure `dart:io`)

| Script | Purpose |
|---|---|
| `install.dart <project> [--starter]` | installs `tool/flutter_store_ready/` (incl. `store_policies.json`), strict analyzer, CI, `.gitignore`, Android/iOS hardening; `--starter` copies the reference app into a fresh `flutter create` project |
| `verify.dart [--release] [--ci]` | runs `flutter pub get`, optional obfuscated release AAB (+ IPA on macOS), quality gates and full report |
| `project_report.dart [project]` | structural Dart + workspace audit (`packages/*` included) + Google Play + App Store → `PROJECT_REPORT.md` & `findings.json` (also audits Expo, React Native and Native Android/iOS projects) |
| `play_readiness.dart [project]` | Google Play readiness audit → `PLAY_READINESS.md` |
| `app_store_readiness.dart [project]` | App Store readiness audit from project files (runs on Windows/Linux/macOS) → `APP_STORE_READINESS.md` |
| `check_forbidden.dart [project]` | blocks on `http://`, disabled TLS, hardcoded secrets, plain-storage tokens; warns on `print`/`debugPrint` and empty `catch` |
| `harden_platforms.dart [project] [--secure-screens]` | main `INTERNET` permission, backup exclusion, release HTTPS + debug LAN cleartext config, `key.properties` signing (Kotlin & Groovy), R8, optional `FLAG_SECURE` |

Annual store thresholds (`targetSdk`, iOS deployment target, Xcode version, 16 KB AGP/NDK) live in `scripts/store_policies.json` — verify against official store announcements when policies change.

## Workflows

### A. New app
1. `flutter create --org com.<company> --platforms=android,ios <app_name>` — ask for the real reverse-domain id first (permanent on both stores; never `com.example`).
2. `dart run <skill>/scripts/install.dart <app_name> --starter`
   Requires the Flutter SDK constraint in `templates/starter_app/pubspec.yaml` (≥ 3.47). If older, `install.dart` installs the toolkit and refuses `--starter`: inform the user and ask before running `flutter upgrade` (never upgrade silently or bypass with `--force`).
3. `cd <app_name> && flutter pub get`, then build requested features following `templates/starter_app/lib/` (`guardFailures` → `AsyncNotifier` → `AsyncValueView` + `ResponsiveCenter` → `AppLocalizations` in all locales → add every screen to `test/responsive_test.dart` and nested routes to `test/navigation_test.dart`).
4. Replace starter placeholders (app title, seed color, sample `items` feature, `config/prod.json`) and run **Finish**.

### B. Make an existing app production-ready
1. Read `EXISTING-PROJECTS.md`. **Preserve the app's existing architecture** (BLoC/Cubit, Provider, Riverpod, `auto_route`, `Navigator`, or `package:flutter/material.dart`) — never rewrite state management or upgrade SDK constraints unprompted.
2. Run `dart run <skill>/scripts/install.dart .` (never `--starter` on existing code). If `pubspec.yaml` still targets Dart 2, run scripts from `<skill>/scripts/` instead of `tool/` and tell the user.
3. Run `dart run tool/flutter_store_ready/verify.dart` and inspect `PROJECT_REPORT.md`.
4. Present blockers and fix in priority order: **crashes & global error handlers → security → responsive / 200–300% text → store requirements → leftovers**. Adapt pure-Dart modules from `templates/starter_app/lib/core/` (`EXISTING-PROJECTS.md`).
5. Re-run `verify.dart` until all ❌ blockers are resolved (or explicitly accepted by the user), then run **Finish**.

### C. Read-only audit, forms, or rejection
Delegate to sibling skills: pre-submission read-only audit → **store-review**; Data safety & App Privacy drafts → **store-forms**; Apple/Google rejection triage & reply → **store-rejection**.

### D. Release preparation
- **Google Play** (`GOOGLE-PLAY-RELEASE.md`): upload keystore + `android/key.properties`, bump `+versionCode`, configure `config/prod.json`, run `verify.dart --release`, resolve ❌ in `PLAY_READINESS.md`.
- **App Store** (`APP-STORE-RELEASE.md`): permanent bundle id, `DEVELOPMENT_TEAM`, opaque 1024 px icon, specific `NS*UsageDescription` strings, `PrivacyInfo.xcprivacy` in target, run `verify.dart --release`, resolve ❌ in `APP_STORE_READINESS.md`. On Windows/Linux state clearly that files were audited without building an IPA (macOS/Xcode required). Never choose `ITSAppUsesNonExemptEncryption` or signing teams on the user's behalf.

## Non-negotiable rules (checklists in guides)

- **Errors (`ERROR-HANDLING.md`):** Close all startup error paths (`FlutterError.onError`, `PlatformDispatcher.instance.onError`, `Isolate` listener, `ErrorWidget.builder`, state observer, crash reporter). Map all repository exceptions to typed `AppFailure`s. Never render exception text (`$e`, `e.toString()`), HTTP status codes, raw payloads, or developer jargon on screen. Render loading, error + retry, empty, and data states while keeping stale data on refresh/pagination failure.
- **Security (`SECURITY.md`):** Store tokens exclusively in Keychain/Keystore (`flutter_secure_storage`) with first-launch-after-reinstall wipe on iOS; never ship secrets in code, assets, or `--dart-define`. Enforce HTTPS fail-closed in release, SPKI pinning (≥ 2 pins) for own APIs, single-flight token refresh on a separate `Dio`, secret-redacting logger, deep-link validation, and `--obfuscate --split-debug-info`.
- **Responsive & large text (`RESPONSIVE-AND-LARGE-TEXT.md`):** Support system font scaling up to 3× (never `TextScaler.noScaling` or caps < 2× except ~1.3× on nav chrome with tooltips). Compute breakpoints via `width / textScale`, avoid fixed heights around text, avoid full-width button themes, and test every screen across 5 sizes × 100/150/200/300% text × every locale.
- **Navigation & lifecycle (`NAVIGATION-AND-LIFECYCLE.md`):** Test that Android system back steps up from nested routes instead of exiting. Capture long-lived cubits/notifiers *before* `await` in menus/dialogs so `if (!mounted) return;` never aborts sign-out or account deletion. Request permissions in context (never at launch). Isolate background refresh sessions.
- **Store compliance (`STORE-POLICIES.md`, `GOOGLE-PLAY-RELEASE.md`, `APP-STORE-RELEASE.md`):** When accounts exist: provide real in-app account deletion (+ web URL), document deletion in legal text, offer Sign in with Apple alongside third-party logins on iOS, and remind the user in chat to configure a non-expiring **reviewer demo account** in both consoles. Enforce restore + transparent paywalls for IAP, UMP + ATT consent before ads/tracking, report + block for UGC, and AI data disclosure.

## Finish (mandatory)

1. Run `dart run tool/flutter_store_ready/verify.dart` (or `dart run <skill>/scripts/project_report.dart .` if not installed). If `flutter` is unavailable, state clearly which gates were skipped — never claim unrun tests passed.
2. Deliver `build/reports/flutter-store-ready/PROJECT_REPORT.md` (plus `PLAY_READINESS.md` / `APP_STORE_READINESS.md` for release tasks).
3. Reply in the user's language in 3–6 lines: verdict, remaining blockers, fixes applied, and the single next step.
