# flutter-store-ready — an agent skill for store-ready Flutter apps

An agent skill in the open [Agent Skills](https://agentskills.io) format — for Claude Code, Codex, Cursor, Gemini CLI and any other coding agent — that builds, hardens and audits Flutter apps to **store-release quality**:

- 🧯 **Errors closed**: global handlers, typed failures, user-friendly messages (no exception text, status codes or server responses on screen), loading / error + retry / empty states on every screen.
- 🔐 **Security (OWASP MASVS)**: Keychain/Keystore tokens, SPKI certificate pinning, single-flight token refresh, HTTPS fail-closed config, log redaction, deep-link validation, Android hardening.
- 📱 **Responsive & large text**: pages never break — tested on 5 screen sizes × **100 / 150 / 200 / 300 % system font size** × every language.
- 🏪 **Google Play readiness**: upload keystore & `key.properties`, release signing, `applicationId`, targetSdk ≥ 36, icon, INTERNET permission, sensitive permissions, 16 KB pages, AAB signature, secrets committed to git.
- 🍎 **App Store readiness**: bundle id, signing team, opaque 1024 px icon, deployment target, iPad orientations, ATS, export compliance, permission keys and their wording, privacy manifest, ATT, Sign in with Apple, push entitlement, certificates committed to git. Reads project files only, so it also runs on Windows and Linux (the build itself needs a Mac).
- 📝 **Always ends with a report**: `PROJECT_REPORT.md` — ❌ missing (blocking), ⚠️ recommended, 📝 your manual store tasks, ✅ done.

> **Status: 0.1.0, internal preview.** Checks and their severities can still change. Most checks match text patterns, so they can flag correct code and miss real problems: please report both with the issue templates ("False alarm", "Missed problem"). See [CHANGELOG.md](CHANGELOG.md).

## Commands

Four skills in one repository. Each one is a command: `/store-review` in Claude Code; in other agents call it by name ("use the store-review skill") or just describe the task. They are split by **task**, not by framework — each one recognizes the project type itself.

| Command | What it does | When |
|---|---|---|
| `/flutter-store-ready` | Creates a new Flutter app from the production starter, or fixes and hardens an existing one, following every rule in the guides | Starting an app; making it production-ready; fixing what a review found |
| `/store-review` | Read-only audit before you upload: what Google Play or App Review will reject, what is risky, what is left in the consoles → `PROJECT_REPORT.md` | Before every submission |
| `/store-forms` | Drafts the Data safety, Advertising ID, App access, target audience and Apple App Privacy / export compliance answers from what the code and its SDKs actually do, and checks them against the privacy policy → `STORE_FORMS.md` | First release; after adding or removing an SDK |
| `/store-rejection` | Takes a rejection or policy e-mail, finds the cause in the project, says fix / reply / update a form / appeal, drafts the reply or appeal → `REJECTION_RESPONSE.md` | When Apple or Google says no |

Nothing is sent and no console is changed by any of them: replies, appeals and form answers are drafts you submit yourself.

Frameworks: everything works fully for **Flutter**. `/store-review`, `/store-forms` and `/store-rejection` also handle native Android / iOS, React Native and Expo projects as a guided checklist review (no automated checks yet — the report says so).

## Install

```sh
npx skills add https://github.com/tuvatechvalley/flutter-store-ready
```

Installs all four skills; keep them together — the store skills use the scripts and guides in `flutter-store-ready/`. For a user-level install (all projects), add `--global`. Run `npx skills --help` for agent selection.

Any agent: each skill is a plain folder (`skills/<name>/SKILL.md` plus guides; `flutter-store-ready/` also holds the Dart scripts and the starter template). `npx skills add` puts them where your agent looks for skills. With an agent that has no skill support, tell it: "read `skills/store-review/SKILL.md` and follow it" — nothing in them depends on a specific agent, and the scripts run without any agent at all.

Claude Code can also install it as a plugin (`.claude-plugin/` holds the manifest): `/plugin marketplace add tuvatechvalley/flutter-store-ready`, then `/plugin install flutter-store-ready`.

Manual install (Claude Code):

```sh
git clone https://github.com/tuvatechvalley/flutter-store-ready
# macOS / Linux
cp -r flutter-store-ready/skills/* ~/.claude/skills/
# Windows (PowerShell)
Copy-Item -Recurse flutter-store-ready\skills\* $HOME\.claude\skills\
```

Requirements: Flutter SDK for the automated checks (the scripts are plain Dart, no packages needed — they run on Windows, macOS and Linux). `keytool` (any JDK / Android Studio's JBR) for keystore checks.

## Use

Open your agent in (or pointed at) a Flutter project and ask, for example:

- `create a production-ready Flutter app called acme_notes`
- `make this Flutter app production-ready`
- `audit this app — is it ready for Google Play?`
- `is the iOS side ready for the App Store?`
- `check my keystore and signing setup`
- `fix the screens that break with 200% font size`

The skill installs its toolkit into the project (`tool/flutter_store_ready/`), works through the rules, and finishes with the report:

```sh
dart run tool/flutter_store_ready/verify.dart            # gates + report
dart run tool/flutter_store_ready/verify.dart --release  # + obfuscated AAB + Play audit
# → build/reports/flutter-store-ready/PROJECT_REPORT.md
```

The scripts can also be used without an agent:

```sh
dart run skills/flutter-store-ready/scripts/project_report.dart path/to/app
dart run skills/flutter-store-ready/scripts/play_readiness.dart path/to/app --last-version-code 41
dart run skills/flutter-store-ready/scripts/app_store_readiness.dart path/to/app --last-build-number 41
dart run skills/flutter-store-ready/scripts/install.dart path/to/app [--starter]
```

## Tests

```sh
dart run tests/run.dart            # all fixtures
dart run tests/run.dart planted    # one fixture
```

`tests/fixtures/` holds tiny projects with **planted problems** (the audit must report them) and **decoys** (things that look like a problem and are not: a list item called `e`, a Firebase API key, an announcement field called `message`, a file called `feedback.dart`). Each has an `expected.json`. When the audit reports something wrong on a real app, add the case as a decoy before fixing the script; when it misses something, plant it. CI runs the fixtures on Linux and Windows.

## Example reports

| Project | Report |
|---|---|
| Untouched `flutter create` counter app | [PROJECT_REPORT.md](examples/counter-app/PROJECT_REPORT.md) · [PLAY_READINESS.md](examples/counter-app/PLAY_READINESS.md) · [APP_STORE_READINESS.md](examples/counter-app/APP_STORE_READINESS.md) |
| App with planted mistakes: raw errors on screen, tokens in plain storage, no account deletion, ads without consent, purchases without restore … (`tests/fixtures/planted`, code checks only) | [PROJECT_REPORT.md](examples/bad-app/PROJECT_REPORT.md) |
| Fresh app after `install.dart --starter` (quality gates not run for this example) | [PROJECT_REPORT.md](examples/starter-installed/PROJECT_REPORT.md) |

## Files

| File | Purpose |
|---|---|
| `skills/flutter-store-ready/SKILL.md` | workflows (new app, make production-ready, audit, release), non-negotiable rules, mandatory final report |
| `ERROR-HANDLING.md` | bootstrap, typed failures, four UI states, network resilience |
| `SECURITY.md` | OWASP MASVS mapping, pinning, storage, logging |
| `RESPONSIVE-AND-LARGE-TEXT.md` | 200–300 % font size, breakpoints, test matrix |
| `NAVIGATION-AND-LIFECYCLE.md` | back button, actions started from menus, permission prompts, background sessions, dev servers |
| `STORE-POLICIES.md` | purchases, ads & consent, user content, AI, data declarations, release fingerprints |
| `GOOGLE-PLAY-RELEASE.md` | upload key, key.properties, versioning, targetSdk, 16 KB, Play Console checklist |
| `APP-STORE-RELEASE.md` | bundle id, signing, Info.plist, privacy manifest, TestFlight, App Store Connect, common rejections |
| `AUDIT-AND-REPORTING.md` | what the audit checks, what to review by hand, report format |
| `scripts/` | `install`, `verify`, `project_report`, `play_readiness`, `app_store_readiness`, `check_forbidden`, `harden_platforms` |
| `templates/starter_app/` | complete reference app (Flutter ≥ 3.47, `material_ui`, Riverpod 3, go_router, Dio) with tests and CI |

## Contributing

Issues and pull requests are welcome; every pull request is reviewed before it is merged. See [CONTRIBUTING.md](CONTRIBUTING.md). Report security problems privately: [SECURITY.md](SECURITY.md).

## License

MIT
