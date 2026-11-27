# Changelog

Versions follow [semantic versioning](https://semver.org). While the version is 0.x the checks and their severities can still change between releases.

## 0.2.0 — 2026-11-27

### Structural Dart & Workspace Scanner (`dart_scanner.dart`)
- Single-pass zero-dependency Dart lexer masks `//` and nested `/* … */` comments and string contents while keeping `${…}` interpolation expressions intact — parentheses or keywords inside strings and comments no longer corrupt call-tree, `.when(error:)`, `catch` scope, or `check_forbidden.dart` checks.
- Structural call-argument inspection (`inspectCallAt`) checks `.when(error:)` accurately without fixed character windows and catches fixed numeric heights on both `SizedBox` and `Container` wrapping text widgets.
- Project-wide semantic discovery (`ProjectSemantics`) automatically detects custom UI text/dialog/snackbar wrappers (catching raw `$e` / status codes passed through helpers like `showAppError` or `AppText`) as well as custom loading/error widgets so screens using them are not falsely flagged.
- Native support for Dart `workspace:` and `packages/*` / `modules/*` monorepos across `project_report.dart` and `check_forbidden.dart`.

### Cross-Platform Automation (Expo, React Native, Native Android & iOS)
- New `project_detector.dart`: `project_report.dart`, `play_readiness.dart`, `app_store_readiness.dart`, and `check_forbidden.dart` now automatically detect and audit **Expo** (managed `app.json` + `eas.json` + prebuild drift warnings), **React Native** (non-`Runner` Xcode targets, `package.json`), **Native Android** (`app/` module layout), and **Native iOS** projects.
- Cross-ecosystem SDK normalization maps npm, Expo config-plugin, Gradle, and CocoaPods dependencies to Play Data safety, App Privacy, ATT, Maps, Sign in with Apple, and permission checks.

### Existing Flutter Architecture Compatibility (`EXISTING-PROJECTS.md`)
- Added `EXISTING-PROJECTS.md` with copy-ready patterns for `flutter_bloc` / `Cubit` (`BlocObserver`, sealed 4-state UI keeping stale items on refresh error), `provider` / `ChangeNotifier`, `auto_route` / `Navigator`, and classic `package:flutter/material.dart` (Flutter < 3.47).
- `install.dart` detects the project's existing stack on non-starter installs and reminds agents not to rewrite state management or routers.
- Screen-state and navigation checks recognize `BlocBuilder`, `BlocConsumer`, `AutoTabsScaffold`, and `CupertinoTabScaffold`.

### Centralized Store Policy Config & Context Optimization
- Extracted annual Google Play, App Store, and Flutter thresholds into `scripts/store_policies.json` (`store_policies.dart`), validated by `tests/run.dart`.
- Streamlined `skills/flutter-store-ready/SKILL.md` (~45% smaller) by removing duplicate prose already covered in the on-demand reference guides.
- Added `monorepo-bloc` and `expo-bad` regression fixtures in `tests/fixtures/`.

### Earlier in 0.2.0
- Split repository into four task-oriented skills: `flutter-store-ready`, `store-review`, `store-forms`, and `store-rejection`.
- Play: a bundle older than source code warns ("not the current code"); certificate owner names are redacted; `in_app_purchase` counts as collected purchase history only when recorded off-device.

## 0.1.0 — internal preview (2026-11-25)

First version tried on real apps.

### Audits
- `project_report.dart`, `play_readiness.dart`, `app_store_readiness.dart`, `check_forbidden.dart`, `harden_platforms.dart`, `install.dart`, `verify.dart`.
- Regression fixtures in `tests/` with planted problems and decoys; CI on Linux and Windows.
- Reference starter in `templates/starter_app/` (Flutter ≥ 3.47, Riverpod 3, `go_router`, `Dio`, SPKI pinning, 136 tests).
