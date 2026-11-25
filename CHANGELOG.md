# Changelog

Versions follow [semantic versioning](https://semver.org). While the version is 0.x the checks and their severities can still change between releases.

## Unreleased

### Commands
- The repository now has four skills, split by task: `flutter-store-ready` (build and harden Flutter apps), `store-review` (read-only pre-submission audit), `store-forms` (Data safety / App Privacy and other console answers), `store-rejection` (cause, fix and reply for a rejection). The audit workflow moved out of `flutter-store-ready` into `store-review`.
- The three store skills also handle native Android / iOS, React Native and Expo projects as a checklist review; automated checks remain Flutter-only.
- Tried by fresh agents on four real apps (Flutter ×3, Expo ×1) with read-only rules; the projects were verified unchanged afterwards. Fixed from what they hit: report location in projects where `build/` is not git-ignored, one severity definition, a "changes to the automated findings" section, an Expo key map and prebuild warning, a children's-apps section (`STORE-POLICIES.md` §9, previously a broken reference), per-platform SDK answers, more data-declaration rows (own analytics, push tokens, age band, public nicknames, third-party names, server IP logs), console-dependent rejections (ask first, branches), "no reply needed" for Play form fixes, a subscription-rejection row for apps that sell none.

### Audit
- Play: a bundle older than the source code is a warning ("not the current code"); the certificate owner's name is no longer printed.
- `in_app_purchase` is listed as collected purchase history only when the app or its server records purchases.

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

### Starter template fixes (found on Flutter 3.50.1)
- Pagination: after a failed "load more", a successful retry left the old error under the list.
- Test helper overrode the same provider twice, which Riverpod 3 rejects (3 tests failed).
- New `test/navigation_test.dart`: pages animate, and the Android back button goes up one level.

### Tooling
- `install.dart` (toolkit, strict analyzer, CI, hardening; `--starter` for a new app), `verify.dart` (`--release`, `--ci`), `harden_platforms.dart` (Kotlin and Groovy Gradle files; debug-only network config), `check_forbidden.dart` (security patterns block, habits warn).
- Regression fixtures in `tests/` with planted problems and decoys; CI on Linux and Windows.
- Works with any coding agent: plain `SKILL.md` + Dart scripts; the starter ships `AGENTS.md` and `CLAUDE.md`.

### Known limits
- Most checks match text patterns: they can flag correct code and miss real problems. Report both with the issue templates.
- Verified on Flutter 3.50.1 (Dart 3.14): scripts analyze cleanly, the starter installs, analyzes cleanly and passes all 136 tests. Not yet run: `flutter build appbundle` / `flutter build ipa` of the starter, and the iOS build step on macOS.
- The starter needs Flutter ≥ 3.47.
