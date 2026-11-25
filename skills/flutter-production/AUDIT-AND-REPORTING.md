# Audit and reporting

## Run the automated audit

```sh
dart run <skill>/scripts/project_report.dart <project> [--last-version-code N] [--out <dir>]
```

Output (default `<project>/build/reports/flutter-production/`, git-ignored):

| File | Content |
|---|---|
| `PROJECT_REPORT.md` | verdict, ❌ Missing (blocking), ⚠️ Recommended, 📝 Manual tasks, ✅ Done, quality-gate output |
| `findings.json` | same items, machine-readable (`section`, `title`, `level`: fail/warn/manual/pass, `detail`, `fix`) |
| `PLAY_READINESS.md` / `play_readiness.json` | the Google Play part in detail |

Exit code 1 when anything is blocking. Flags: `--skip-gates` (no format/analyze/test run), `--gates-passed`, `--skip-play`, `--no-fail`.

What it checks automatically:

- **Quality gates**: `dart format`, `flutter analyze`, forbidden patterns, `flutter test` (pass/fail counts, failing output).
- **Error handling**: global handlers, ErrorWidget, crash reporting SDK, raw error text in `Text(...)`, FutureBuilder/StreamBuilder without `hasError`, `.when(` without `error:`.
- **Security**: secure token storage when the app has auth, certificate pinning and timeouts when it uses HTTP, print/debugPrint.
- **Responsive & large text**: screens (`*Page`/`*Screen`) not rendered in tests, missing large-text test, locked/capped text scale (blocking), fixed heights around text, SafeArea, adaptive layout.
- **Store**: account deletion (blocking when the app has accounts), privacy policy link, localization.
- **Config**: `config/prod.json` https-only, placeholders, mock backend, pins.
- **Leftovers**: counter demo (blocking), "Flutter Demo" title, default description, starter name/color/sample feature.
- **Code health**: TODO/FIXME, deprecated Material import, strict analyzer, tests, `pubspec.lock` committed, CI.
- **iOS**: ATS, export-compliance key, privacy manifest, missing permission usage descriptions for installed plugins.
- **Google Play**: everything in `GOOGLE-PLAY-RELEASE.md`.

## Then read the code (what scripts cannot judge)

Add these to the report under the matching heading with `file:line`:

1. Each data screen: are loading / error + retry / empty / data all reachable? What happens offline?
2. Each repository: are all errors converted to typed failures? Any `!` on unvalidated data?
3. Auth flow: token refresh, logout on 401, session restore race, what is stored where.
4. Every `Row` with text, every `SizedBox`/`Container` with a height, every `Stack` with text: does it survive 3× text and 320 dp width?
5. Deep links / routes with parameters: validated? open redirect?
6. Anything that sends personal data: is it in the privacy policy / Data safety?

## Report rules

- Verdict first: ❌ NOT READY / ⚠️ ALMOST READY / ✅ READY.
- Every finding: what, where (`file:line`), why it matters, **Fix**.
- Never include secrets (passwords, tokens, keystore passwords) in reports or logs.
- Gates that did not run are reported as skipped — never as passed.
- Deliver the `.md` file to the user; in chat give a 3–6 line summary in the user's language.
