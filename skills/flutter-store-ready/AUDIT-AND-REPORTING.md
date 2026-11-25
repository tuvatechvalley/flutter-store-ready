# Audit and reporting

## Run the automated audit

```sh
dart run <skill>/scripts/project_report.dart <project> [--last-version-code N] [--out <dir>]
```

Output (default `<project>/build/reports/flutter-store-ready/`, git-ignored):

| File | Content |
|---|---|
| `PROJECT_REPORT.md` | verdict, ❌ Missing (blocking), ⚠️ Recommended, 📝 Manual tasks, ✅ Done, quality-gate output |
| `findings.json` | same items, machine-readable (`section`, `title`, `level`: fail/warn/manual/pass, `detail`, `fix`) |
| `PLAY_READINESS.md` / `play_readiness.json` | the Google Play part in detail |
| `APP_STORE_READINESS.md` / `app_store_readiness.json` | the App Store (iOS) part in detail |

Exit code 1 when anything is blocking. Flags: `--skip-gates` (no format/analyze/test run), `--gates-passed`, `--skip-play`, `--skip-ios` (app ships on one store only), `--last-build-number N`, `--no-fail`, `--ci` (on a pipeline the upload key and `config/prod.json` do not exist: their absence becomes a warning instead of a blocker).

What it checks automatically:

- **Quality gates**: `dart format` (warning: style is not a release risk), `flutter analyze`, forbidden patterns (security patterns block; print / debugPrint / empty catch warn), `flutter test` (pass/fail counts, failing output).
- **Screen states**: screens that fetch data on open but have no loading indicator; screens that call the server but show nothing when it fails (file-level heuristic, recommendation).
- **Error handling**: global handlers, ErrorWidget, crash reporting SDK, FutureBuilder/StreamBuilder without `hasError`, `.when(` without `error:`.
- **Error messages users see**: exception text on screen (`'$e'`, `e.toString()`, `snapshot.error`, `runtimeType`, stack traces — blocking), HTTP status codes / response bodies on screen (blocking), server text passed straight through (`data['message']`), developer wording in user-facing strings and `.arb` files ("SocketException", "HTTP 500", "Internal Server Error"). Only flagged inside something that renders (Text, SnackBar, dialogs, `errorText:` …), not in logging or `throw`.
- **Security**: secure token storage when the app has auth (blocking when a file both opens a plain store — Hive without cipher, SharedPreferences, a file — and handles access / refresh tokens; a warning when there is only no secure-storage dependency), certificate pinning and timeouts when it uses HTTP, print/debugPrint.
- **Responsive & large text**: screens (`*Page`/`*Screen`) not rendered in tests, missing large-text test, locked/capped text scale (blocking), fixed heights around text, SafeArea, adaptive layout.
- **Store policy** (only for features the app has, never blocking — `STORE-POLICIES.md`): restore purchases and a paywall checklist with in-app purchases; consent flow before the ad SDK; report / block when users see each other's content; an AI checklist; what the installed SDKs collect, to copy into Data safety and App Privacy; payment SDK without store billing; localhost / LAN / staging addresses not limited to debug; code that detects reviewers.
- **Navigation & permissions** (`NAVIGATION-AND-LIFECYCLE.md`): tabs or nested pages without a test that presses the back button; permission prompts in the start-up files; a theme that makes every button full-width; background work next to a refreshing sign-in token.
- **Store**: account deletion (blocking when the app has accounts), privacy policy link, localization. With sign-in: a manual task to create the reviewer test account for both stores. With account deletion: whether the legal text shipped in the app (`lib/legal*.dart`, `assets/*privacy*` …) mentions it; if the text is only on a web page, a manual task to check it.
- **Config**: `config/prod.json` https-only, placeholders, mock backend, pins.
- **Leftovers**: counter demo (blocking), "Flutter Demo" title, default description, starter name/color/sample feature.
- **Code health**: TODO/FIXME, deprecated Material import, strict analyzer, tests, `pubspec.lock` committed, CI.
- **App Store (iOS)**: everything in `APP-STORE-RELEASE.md` section 4 — read from the project files, so it also runs on Windows and Linux. Not checked: whether the archive builds, signs and passes upload validation (needs a Mac).
- **Google Play**: everything in `GOOGLE-PLAY-RELEASE.md`.

## Then read the code (what scripts cannot judge)

Add these to the report under the matching heading with `file:line`:

1. Each data screen: are loading / error + retry / empty / data all reachable? What happens offline?
2. Every error message in every language: would a non-technical user understand what happened and what to do? The script only catches patterns — messages built in helpers, returned from the backend, or vague ("Operation failed") need reading.
3. Each repository: are all errors converted to typed failures? Any `!` on unvalidated data?
4. Auth flow: token refresh, logout on 401, session restore race, what is stored where.
5. Every `Row` with text, every `SizedBox`/`Container` with a height, every `Stack` with text: does it survive 3× text and 320 dp width?
6. Deep links / routes with parameters: validated? open redirect?
7. Anything that sends personal data: is it in the privacy policy / Data safety?
8. Sign out, delete account and every destructive action: started from a menu / dialog / bottom sheet, does it still run after that widget closed? (`NAVIGATION-AND-LIFECYCLE.md`, section 3)
9. Which roles and screens trigger each permission prompt? Anyone asked who does not need it?
10. Open the privacy policy and terms (in the app or at their URL) and read them against the app: data collected, account deletion, retention, contact, subscriptions. A policy that contradicts what the app does is a rejection reason on both stores.

## When the audit is wrong

The scripts read text patterns, so they will sometimes flag correct code or miss a real problem. In the report: drop the finding and say why in one line (do not leave a known false alarm for the user to decode). A line can be exempted with `// forbidden:allow`. If you maintain the skill: add the case to `tests/fixtures/` (a decoy for a false alarm, a planted problem for a miss) and run `dart run tests/run.dart` before changing a script.

## Report rules

- Verdict first: ❌ NOT READY / ⚠️ ALMOST READY / ✅ READY. Blocking (❌) is reserved for what breaks the app for users, exposes their data, or gets the build rejected; style and habits are recommendations (⚠️). An app that is already live can still be ❌: say which blockers are risks in the released version rather than implying it cannot ship.
- Every finding: what, where (`file:line`), why it matters, **Fix**.
- Never include secrets (passwords, tokens, keystore passwords) in reports or logs.
- A finding from a heuristic (a keyword that is present or absent) is never blocking and is never repeated to the user as a fact: open the file first. Say "the code has no consent flow that I could find", not "the app violates the consent policy".
- Gates that did not run are reported as skipped — never as passed. A store audit that could not run is a blocking item, not a footnote. If no iOS build was made (no Mac), say so.
- Deliver the `.md` file to the user; in chat give a 3–6 line summary in the user's language.
