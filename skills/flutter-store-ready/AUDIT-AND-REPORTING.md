# Audit and reporting

## Run the automated audit

```sh
dart run <skill>/scripts/project_report.dart <project> [--last-version-code N] [--last-build-number N] [--out <dir>]
```

Output (default `<project>/build/reports/flutter-store-ready/`, git-ignored):

| File | Content |
|---|---|
| `PROJECT_REPORT.md` | verdict, ❌ Missing (blocking), ⚠️ Recommended, 📝 Manual tasks, ✅ Done, quality-gate output |
| `findings.json` | machine-readable report (`project`, `projectKind`, `verdict`, `counts`, `items`) |
| `PLAY_READINESS.md` / `play_readiness.json` | Google Play audit details |
| `APP_STORE_READINESS.md` / `app_store_readiness.json` | App Store (iOS) audit details |

Exit code 1 when anything is blocking. Flags: `--skip-gates` (no format/analyze/test run), `--gates-passed`, `--skip-play`, `--skip-ios`, `--last-version-code N`, `--last-build-number N`, `--no-fail`, `--ci` (on CI pipelines missing signing keys and `config/prod.json` become warnings instead of blockers).

Store policy thresholds (`targetSdk`, minimum iOS deployment target, Xcode version, 16 KB AGP/NDK) are loaded from `scripts/store_policies.json`.

### Supported project types

- **Flutter (including `workspace:` and `packages/*` / `modules/*` monorepos):** Full structural Dart analysis + quality gates + Google Play + App Store audits.
- **Expo (managed `app.json` or prebuild), React Native, Native Android, Native iOS:** Automated polyglot forbidden-pattern scan (`http://`, hardcoded secrets, `AsyncStorage` tokens), account/deletion/privacy/SDK-data detection, and full automated Google Play + App Store readiness checks (including Expo `app.json` / `eas.json` / prebuild drift checks and non-`Runner` Xcode targets).

### What the structural Dart & platform audits check

- **Structural Dart scanner (`dart_scanner.dart`):** Masks `//` and nested `/* ... */` comments and string contents while preserving `${...}` interpolations so parentheses in strings or comments never corrupt call-tree, `.when(error:)`, `catch` scope, or fixed-height `SizedBox`/`Container` inspection. Discovers project-defined UI text/dialog wrappers, loading widgets, and error views across workspace packages.
- **Quality gates:** `dart format` (warning), `flutter analyze`, `check_forbidden.dart` (security holes block; `print` / `debugPrint` / empty `catch` warn), `flutter test`.
- **Error handling & screen states:** Global handlers, `ErrorWidget.builder`, crash reporting SDK, `FutureBuilder`/`StreamBuilder` without `hasError`, `.when(...)` without `error:`, and data screens (Riverpod, BLoC/Cubit, Provider) missing loading or error + retry states.
- **User-facing error messages:** Exception text (`$e`, `e.toString()`, `runtimeType`), HTTP status codes / response bodies (blocking), raw server messages (`data['message']`), and developer jargon in UI calls (including custom project UI wrappers) and `.arb` files.
- **Security:** Keychain/Keystore token storage, SPKI pinning, timeouts, raw `print` calls, git-tracked signing keys / `.env` files.
- **Responsive & large text:** Screens missing from widget tests, 200–300% text-scale test, locked/capped text scaling, fixed-height `SizedBox`/`Container` wrapping text, full-width button themes, `SafeArea`, adaptive breakpoints.
- **Store policies & navigation:** Restore purchases, UMP ad consent, ATT prompt vs `Info.plist`, UGC report/block, AI disclosures, SDK data summary, unguarded dev hosts, reviewer detection, system back-button test, startup permission prompts, background token refresh isolation, in-app account deletion + legal documentation.
- **Google Play & App Store:** Everything in `GOOGLE-PLAY-RELEASE.md` and `APP-STORE-RELEASE.md` §4.

## Then read the code (what scripts cannot judge)

Add these to the report under the matching heading with `file:line`:

1. Each data screen: are loading / error + retry / empty / data all reachable? What happens offline?
2. Every error message in every language: would a non-technical user understand what happened and what to do?
3. Each repository: are all errors converted to typed failures? Any `!` on unvalidated data?
4. Auth flow: token refresh, logout on 401, session restore race, what is stored where.
5. Every `Row` with text, every fixed-height box, every `Stack` with text: does it survive 3× text and 320 dp width?
6. Deep links / routes with parameters: validated? open redirect?
7. Anything that sends personal data: is it in the privacy policy / Data safety / App Privacy?
8. Destructive actions (sign out, delete account) started from a menu / dialog / bottom sheet: is the cubit/notifier captured before `await` so closing the menu does not skip the action? (`NAVIGATION-AND-LIFECYCLE.md` §3)
9. Which roles and screens trigger each permission prompt?
10. Read the privacy policy and terms (in-app or public URL) against actual app behavior.

## When the audit is wrong

Even structural analysis uses heuristics for business intent. In the report: drop false alarms and state why in one line under **"Changes to the automated findings"**. Intentional code lines can be exempted with `// forbidden:allow`. Maintainers: add false alarms as decoys and missed bugs as planted cases in `tests/fixtures/`, then run `dart run tests/run.dart`.

## Report rules

- Verdict first: ❌ NOT READY / ⚠️ ALMOST READY / ✅ READY. Blocking (❌) is strictly for crashes, exposed user data, or store rejection triggers.
- Every finding: what, where (`file:line`), why it matters, **Fix**.
- Never include secrets, passwords, tokens, or certificate owner names in reports.
- Heuristic findings are never blocking and never stated as violations without reading the file first.
- Skipped gates are reported as skipped — never as passed. On Windows/Linux state clearly when no iOS archive was built.
- Deliver the `.md` file to the user and give a 3–6 line summary in chat in the user's language.
