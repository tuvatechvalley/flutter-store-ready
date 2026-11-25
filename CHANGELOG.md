# Changelog

Versions follow [semantic versioning](https://semver.org). While the version is 0.x the checks and their severities can still change between releases.

## 0.1.0 — internal preview (2026-11-25)

First version tried on real apps.

### Audits
- `project_report.dart`: one report (`PROJECT_REPORT.md`) with blocking items, recommendations, manual store tasks and what is done.
- `play_readiness.dart`: Google Play — signing, keystore, ids, targetSdk, manifest, sensitive permissions, 16 KB pages, the built bundle, and after a release build the merged manifest (permissions added by plugins, advertising ID).
- `app_store_readiness.dart`: App Store — bundle id, team, icon, deployment target, Info.plist, permission texts, privacy manifest, tracking, Sign in with Apple, push, background modes. Reads project files only, so it also runs on Windows and Linux.
- Error messages users can understand: exception text, status codes and server messages on screen.
- Loading and error states per screen; tokens in plain storage; locked text scaling.
- Store policy (only when the app has the feature): purchases, ads and consent, user content, AI, data declarations, payments outside store billing.
- Navigation and permissions: back button, permission prompts at launch, full-width button themes, background work next to a refreshing session.
- Account rules apply only when the app has sign-in: in-app deletion, reviewer test account, deletion described in the legal text.

### Tooling
- `install.dart` (toolkit, strict analyzer, CI, hardening; `--starter` for a new app), `verify.dart` (`--release`, `--ci`), `harden_platforms.dart` (Kotlin and Groovy Gradle files; debug-only network config), `check_forbidden.dart` (security patterns block, habits warn).
- Regression fixtures in `tests/` with planted problems and decoys; CI on Linux and Windows.
- Works with any coding agent: plain `SKILL.md` + Dart scripts; the starter ships `AGENTS.md` and `CLAUDE.md`.

### Known limits
- Most checks match text patterns: they can flag correct code and miss real problems. Report both with the issue templates.
- The iOS build step (`flutter build ipa`) and the starter template's full test suite have only been run in CI, not on the machine the scripts were developed on.
- The starter needs Flutter ≥ 3.47.
