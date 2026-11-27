# flutter-store-ready — store-release agent skills for mobile apps

An agent skill bundle in the open [Agent Skills](https://agentskills.io) format — for Antigravity, Claude Code, Codex, Cursor, Gemini CLI and any other coding agent — that builds, hardens and audits mobile apps to **store-release quality**:

- 🧯 **Errors closed**: global handlers, typed failures, user-friendly messages (no exception text, status codes or server responses on screen — even inside custom UI wrappers), loading / error + retry / empty states on every screen.
- 🔐 **Security (OWASP MASVS)**: Keychain/Keystore tokens, SPKI certificate pinning, single-flight token refresh, HTTPS fail-closed config, log redaction, deep-link validation, Android & iOS hardening.
- 📱 **Responsive & large text**: pages never break — tested on 5 screen sizes × **100 / 150 / 200 / 300 % system font size** × every language; structural detection of fixed-height `SizedBox` / `Container` boxes around text.
- 🧩 **Fits existing Flutter stacks & monorepos**: adapts cleanly to `flutter_bloc` / `Cubit`, `provider`, Riverpod, `auto_route`, classic `package:flutter/material.dart` (Flutter < 3.47), and `packages/*` workspaces without rewrites.
- 🏪 **Google Play readiness (automated)**: upload keystore & `key.properties`, release signing, `applicationId`, targetSdk ≥ 36, icon, INTERNET permission, sensitive permissions, 16 KB pages, AAB signature, Expo `app.json` / `eas.json` / prebuild drift, secrets committed to git.
- 🍎 **App Store readiness (automated on Windows, Linux & macOS)**: bundle id, signing team, opaque 1024 px icon, deployment target, iPad orientations, ATS, export compliance, permission keys and their wording, privacy manifest, ATT, Sign in with Apple, push entitlement, certificates committed to git.
- 📝 **Always ends with a report**: `PROJECT_REPORT.md` — ❌ missing (blocking), ⚠️ recommended, 📝 your manual store tasks, ✅ done.

> **Status: 0.2.0.** Powered by a zero-dependency structural Dart scanner (`dart_scanner.dart`), cross-ecosystem project detector (`project_detector.dart`), and centralized store policy configuration (`store_policies.json`). Please report false alarms or missed bugs using the issue templates. See [CHANGELOG.md](CHANGELOG.md).

## Commands

Four skills in one repository. Each one is a command (`/store-review` in Claude Code; in Antigravity, Cursor or Gemini CLI call it by name or describe the task). They are split by **task**, and automatically detect the project type.

| Command | What it does | When |
|---|---|---|
| `/flutter-store-ready` | Creates a new Flutter app from the production starter, or hardens an existing Flutter app (preserving its state management and router) | Starting an app; making it production-ready; fixing what a review found |
| `/store-review` | Read-only automated + code audit before you upload: what Google Play or App Review will reject, what is risky, what is left in the consoles → `PROJECT_REPORT.md` | Before every submission |
| `/store-forms` | Drafts the Data safety, Advertising ID, App access, target audience and Apple App Privacy / export compliance answers from what the code and its SDKs actually do, and checks them against the privacy policy → `STORE_FORMS.md` | First release; after adding or removing an SDK |
| `/store-rejection` | Takes a rejection or policy e-mail, finds the cause in the project with `file:line` evidence, says fix / reply / update a form / appeal, drafts the reply or appeal → `REJECTION_RESPONSE.md` | When Apple or Google says no |

Nothing is sent and no console is changed by any of them: replies, appeals and form answers are drafts you submit yourself.

**Frameworks:** Full code + UI + platform automation for **Flutter** (including `packages/*` monorepos). Automated platform, permission, signing, secret, account-deletion and SDK-data audits + guided UI verification for **Expo** (managed `app.json` or prebuild), **React Native**, **Native Android** and **Native iOS**.

## Install

```sh
npx skills add https://github.com/tuvatechvalley/flutter-store-ready
```

Installs all four skills; keep them together — the store skills share the scripts, policies and guides in `flutter-store-ready/`. For a user-level install (all projects), add `--global`.

> **Private repository / offline install?** Clone first and install from the local folder with telemetry off:
>
> ```sh
> git clone https://github.com/tuvatechvalley/flutter-store-ready
> DISABLE_TELEMETRY=1 npx skills add ./flutter-store-ready --skill '*'
> # Windows (PowerShell): $env:DISABLE_TELEMETRY=1; npx skills add .\flutter-store-ready --skill '*'
> ```

**Manual install (Antigravity / `.agents` standard / Claude Code):**

```sh
git clone https://github.com/tuvatechvalley/flutter-store-ready
# Project-level (Antigravity, Cursor, Gemini CLI, Codex):
mkdir -p .agents/skills && cp -r flutter-store-ready/skills/* .agents/skills/
# User-level (Claude Code):
cp -r flutter-store-ready/skills/* ~/.claude/skills/
# Windows (PowerShell — Antigravity workspace):
New-Item -ItemType Directory -Force .agents\skills | Out-Null
Copy-Item -Recurse flutter-store-ready\skills\* .agents\skills\
```

Claude Code plugin marketplace: `/plugin marketplace add tuvatechvalley/flutter-store-ready`, then `/plugin install flutter-store-ready`.

Requirements: Dart / Flutter SDK for the automated scripts (pure `dart:io` & `dart:convert`, zero external packages — runs on Windows, macOS and Linux). `keytool` (any JDK / Android Studio's JBR) for keystore inspection.

## Use

Open your agent in a mobile project and ask, for example:

- `create a production-ready Flutter app called acme_notes`
- `make this Flutter BLoC app production-ready without changing its architecture`
- `audit this Expo app — is it ready for Google Play and the App Store?`
- `draft my Data safety and App Privacy forms`
- `we got rejected under Guideline 5.1.1(v) — find the cause and draft the reply`

Standalone CLI usage (no agent required):

```sh
dart run skills/flutter-store-ready/scripts/project_report.dart path/to/app
dart run skills/flutter-store-ready/scripts/play_readiness.dart path/to/app --last-version-code 41
dart run skills/flutter-store-ready/scripts/app_store_readiness.dart path/to/app --last-build-number 41
dart run skills/flutter-store-ready/scripts/install.dart path/to/flutter_app [--starter]
```

## Tests

```sh
dart run tests/run.dart                 # all fixtures + skill & policy validation
dart run tests/run.dart monorepo-bloc   # workspace + BLoC + custom wrappers + comment decoys
dart run tests/run.dart expo-bad        # Expo managed multi-store audit
```

## Files

| File | Purpose |
|---|---|
| `skills/flutter-store-ready/SKILL.md` | concise workflows, non-negotiable rules index, mandatory final report |
| `EXISTING-PROJECTS.md` | adapting core helpers to BLoC/Cubit, Provider, `auto_route`, `flutter/material.dart` (< 3.47), and `packages/*` monorepos |
| `ERROR-HANDLING.md` | bootstrap, typed failures, user-readable messages, four UI states, network resilience |
| `SECURITY.md` | OWASP MASVS mapping, SPKI pinning, secure storage, redacting logger |
| `RESPONSIVE-AND-LARGE-TEXT.md` | 200–300 % font size, breakpoints, test matrix |
| `NAVIGATION-AND-LIFECYCLE.md` | back button, menu/dialog actions, permission prompts, background isolates, dev servers |
| `STORE-POLICIES.md` | purchases, ads & consent, UGC, AI, data declarations, SHA fingerprints, children's apps |
| `GOOGLE-PLAY-RELEASE.md` | upload key, `key.properties`, versioning, targetSdk, 16 KB, Play Console checklist |
| `APP-STORE-RELEASE.md` | bundle id, signing, `Info.plist`, privacy manifest, TestFlight, App Store Connect |
| `AUDIT-AND-REPORTING.md` | structural audit coverage, manual code checks, report format |
| `scripts/` | `install`, `verify`, `project_report`, `play_readiness`, `app_store_readiness`, `check_forbidden`, `harden_platforms`, `dart_scanner`, `project_detector`, `store_policies` + `store_policies.json` |
| `templates/starter_app/` | reference app (Flutter ≥ 3.47, `material_ui`, Riverpod 3, `go_router`, `Dio`) with 136 tests and CI |

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

MIT
