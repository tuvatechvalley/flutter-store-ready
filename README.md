# flutter-production — an agent skill for store-ready Flutter apps

A skill for Claude Code (and other coding agents that support [Agent Skills](https://agentskills.io)) that builds, hardens and audits Flutter apps to **store-release quality**:

- 🧯 **Errors closed**: global handlers, typed failures, no raw exception text, loading / error + retry / empty states on every screen.
- 🔐 **Security (OWASP MASVS)**: Keychain/Keystore tokens, SPKI certificate pinning, single-flight token refresh, HTTPS fail-closed config, log redaction, deep-link validation, Android hardening.
- 📱 **Responsive & large text**: pages never break — tested on 5 screen sizes × **100 / 150 / 200 / 300 % system font size** × every language.
- 🏪 **Google Play readiness**: upload keystore & `key.properties`, release signing, `applicationId`, targetSdk ≥ 36, icon, INTERNET permission, sensitive permissions, 16 KB pages, AAB signature, secrets committed to git.
- 📝 **Always ends with a report**: `PROJECT_REPORT.md` — ❌ missing (blocking), ⚠️ recommended, 📝 your manual store tasks, ✅ done.

## Install

```sh
npx skills add https://github.com/OWNER/flutter-production-skill --skill flutter-production
```

For a user-level install (all projects), add `--global`. Run `npx skills --help` for agent selection.

Manual install (Claude Code):

```sh
git clone https://github.com/OWNER/flutter-production-skill
# macOS / Linux
cp -r flutter-production-skill/skills/flutter-production ~/.claude/skills/
# Windows (PowerShell)
Copy-Item -Recurse flutter-production-skill\skills\flutter-production $HOME\.claude\skills\
```

Requirements: Flutter SDK (the scripts are plain Dart, no packages needed — they run on Windows, macOS and Linux). `keytool` (any JDK / Android Studio's JBR) for keystore checks.

## Use

Open your agent in (or pointed at) a Flutter project and ask, for example:

- `create a production-ready Flutter app called acme_notes`
- `make this Flutter app production-ready`
- `audit this app — is it ready for Google Play?`
- `check my keystore and signing setup`
- `fix the screens that break with 200% font size`

The skill installs its toolkit into the project (`tool/flutter_production/`), works through the rules, and finishes with the report:

```sh
dart run tool/flutter_production/verify.dart            # gates + report
dart run tool/flutter_production/verify.dart --release  # + obfuscated AAB + Play audit
# → build/reports/flutter-production/PROJECT_REPORT.md
```

The scripts can also be used without an agent:

```sh
dart run skills/flutter-production/scripts/project_report.dart path/to/app
dart run skills/flutter-production/scripts/play_readiness.dart path/to/app --last-version-code 41
dart run skills/flutter-production/scripts/install.dart path/to/app [--starter]
```

## Example reports

| Project | Report |
|---|---|
| Untouched `flutter create` counter app | [examples/counter-app/PROJECT_REPORT.md](examples/counter-app/PROJECT_REPORT.md) · [PLAY_READINESS.md](examples/counter-app/PLAY_READINESS.md) |
| App with typical mistakes (token in SharedPreferences, raw errors, locked text size, no account deletion) | [examples/bad-app/PROJECT_REPORT.md](examples/bad-app/PROJECT_REPORT.md) |
| Fresh app after `install.dart --starter` | [examples/starter-installed/PROJECT_REPORT.md](examples/starter-installed/PROJECT_REPORT.md) |

## Files

| File | Purpose |
|---|---|
| `skills/flutter-production/SKILL.md` | workflows (new app, make production-ready, audit, release), non-negotiable rules, mandatory final report |
| `ERROR-HANDLING.md` | bootstrap, typed failures, four UI states, network resilience |
| `SECURITY.md` | OWASP MASVS mapping, pinning, storage, logging |
| `RESPONSIVE-AND-LARGE-TEXT.md` | 200–300 % font size, breakpoints, test matrix |
| `GOOGLE-PLAY-RELEASE.md` | upload key, key.properties, versioning, targetSdk, 16 KB, Play Console checklist |
| `AUDIT-AND-REPORTING.md` | what the audit checks, what to review by hand, report format |
| `scripts/` | `install`, `verify`, `project_report`, `play_readiness`, `check_forbidden`, `harden_platforms` |
| `templates/starter_app/` | complete reference app (Flutter ≥ 3.47, `material_ui`, Riverpod 3, go_router, Dio) with tests and CI |

## Türkçe kısa özet

Flutter uygulamalarını mağazaya çıkacak kaliteye getiren bir agent skill'i: hataları kapatır, güvenliği sağlar, telefonda yazı %200–300 büyütülünce sayfaların bozulmamasını garanti eder, Google Play için keystore/imza/targetSdk gibi her şeyi denetler ve her işin sonunda **neler eksik, neler tamam** raporu (`PROJECT_REPORT.md`) verir. Kurulum: yukarıdaki `npx skills add …` komutu. Sonra Claude'a "bu uygulamayı production'a hazırla" ya da "Play'e çıkmaya hazır mı denetle" demen yeterli.

## License

MIT
