---
name: store-review
description: Audit a mobile app before it is submitted to Google Play or the App Store and write a report of what will be rejected, what is risky and what the developer still has to do in the store consoles. Read-only — it does not change code. Use when asked "is it ready for the store", "will it pass review", "check before I submit", "Play'e / App Store'a çıkmaya hazır mı". Runs automated audits across Flutter (including monorepos), Expo, React Native, Native Android and Native iOS projects, followed by code verification.
---

# Store review

Goal: before the user uploads a build, tell them — with evidence from their project — what Google Play or Apple App Review will reject, what is risky, and what they still have to fill in the consoles. Talk to the user in their language; the report itself is written in English.

**Read-only.** Do not change, add or delete anything in the project: no fixes, no installs, no builds, no formatting. The only thing you write is the report (see "Where the report goes").

This skill uses the scripts and guides of the **flutter-store-ready** skill from the same repository, installed next to this one. Below, `<kit>` means that folder: `<this skill's folder>/../flutter-store-ready`. If it is missing, tell the user to install the whole repository (all four skills), and stop.

Follow-ups belong to the sibling skills: store forms (Data safety, App Privacy) → **store-forms**; a rejection that already happened → **store-rejection**; fixing what this review found in a Flutter app → **flutter-store-ready**.

## Where the report goes

Use `<project>/build/reports/store-review/` only when git ignores it (`git check-ignore -q build/reports` succeeds — true for standard Flutter and Android projects, often not for React Native / Expo). Otherwise, or when the project is not a git repository, write to a folder outside the project (for example a `store-review-<app>` folder next to it) and say where. If the user names a place, use it.

## 1. Identify the project

`project_report.dart`, `play_readiness.dart` and `app_store_readiness.dart` detect all five project layouts automatically:

| Project type | How it is recognized | Android source of truth | iOS source of truth |
|---|---|---|---|
| Flutter (incl. `packages/*` workspaces) | `pubspec.yaml` with `flutter:` | `android/app/build.gradle(.kts)`, `android/app/src/main/AndroidManifest.xml` | `ios/Runner/Info.plist`, `ios/Runner.xcodeproj` |
| Expo (managed or prebuild) | `package.json` with `expo` or `app.json` | `app.json` → `expo.android` + config plugins (`eas.json` for signing) | `app.json` → `expo.ios` + config plugins |
| React Native (bare) | `package.json` with `react-native` | `android/app/build.gradle(.kts)`, `AndroidManifest.xml` | `ios/<App>/Info.plist`, `ios/<App>.xcodeproj` |
| Native Android | `app/build.gradle(.kts)` | `app/` | — |
| Native iOS | `*.xcodeproj` / `*.xcworkspace` | — | `<App>/Info.plist`, `<App>.xcodeproj` |

**Expo prebuild note:** `app.json` / `app.config.*` and config plugins are the source of truth. The automated scripts warn when a git-ignored `android/` or `ios/` folder exists locally, because hand edits there are lost on `prebuild --clean` or EAS builds. If dynamic logic lives in `app.config.ts` / `app.config.js`, inspect that file directly alongside the script output.

Ask which store(s) to cover only when the user's words do not say and the project targets both platforms.

## 2. Run the automated audit (all project types)

```sh
dart run <kit>/scripts/project_report.dart <project> --out <report folder> [--skip-gates] [--skip-play | --skip-ios] [--last-version-code N] [--last-build-number N]
```

- **Flutter:** Runs quality gates (`dart format`, `flutter analyze`, `check_forbidden.dart`, `flutter test` unless `--skip-gates` is passed), structural Dart & workspace checks (error handling, custom UI wrappers, responsive/large text, BLoC/Provider/Riverpod screen states, security, store policies), plus Google Play and App Store readiness.
- **Expo, React Native, Native Android, Native iOS:** Runs polyglot forbidden-pattern checks (plain `http://`, hardcoded secrets, plain-storage tokens in `AsyncStorage`), account/deletion/privacy/SDK data detection, and the automated Google Play (`play_readiness.dart`) and App Store (`app_store_readiness.dart`) audits. UI layout, error states, and dynamic `app.config.ts` rules are verified in Step 3 using `<kit>/GOOGLE-PLAY-RELEASE.md`, `<kit>/APP-STORE-RELEASE.md`, `<kit>/STORE-POLICIES.md`, and `<kit>/ERROR-HANDLING.md` §§3–5.

Exit code 1 only means "blocking items found". Keep the script's output files intact and write your reviewed report after reading the code.

## 3. Read the code (mandatory verification)

Automated checks — even structural ones — can flag intentional code or miss business-logic flaws. Inspect in this order:

1. **Every ❌ finding** — open the cited file; confirm, re-grade, or drop false alarms with a one-line reason.
2. **Accounts** — sign-in, in-app deletion that truly deletes server data, reviewer access.
3. **Money** — purchases (restore button, paywall terms, store billing for digital goods).
4. **Data leaving the device** — every network call and SDK vs. the privacy policy text.
5. **Permissions** — where each prompt is triggered, and for whom.
6. **UI states & error messages** (especially on non-Flutter projects where UI checks are manual) — loading / error + retry / empty states, no raw technical errors shown to users, and `<kit>/AUDIT-AND-REPORTING.md` ("Then read the code").

## 4. Report

Write `PROJECT_REPORT.md` in the report folder following `<kit>/AUDIT-AND-REPORTING.md`: ❌ **blocking** (breaks the app, exposes data, or gets rejected), ⚠️ risky/recommended, 📝 console tasks or "verify on build", ✅ verified fine.

1. Verdict first: ❌ NOT READY / ⚠️ ALMOST READY / ✅ READY (per store when they differ).
2. Each finding: what, where (`file:line`), why it matters (cite guideline/policy), how to fix it.
3. Section **"Changes to the automated findings"**: every automated finding dropped or re-graded with its reason, plus issues found by reading code that the scripts did not cover.
4. Never include passwords, keys, tokens, or certificate owner names in the report.

In chat, in the user's language, 3–6 lines: verdict, blocking items, single next step, and report path.

## Never

- Change code, settings, dependencies or store consoles.
- Present an automated match as a confirmed violation without opening the file.
- Guess store policy dates or API thresholds from memory — check `<kit>/scripts/store_policies.json` and the official policy links in the guides.
