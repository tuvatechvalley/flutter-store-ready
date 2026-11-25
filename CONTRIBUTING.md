# Contributing

Issues and pull requests are welcome. Every pull request is reviewed by a maintainer before it is merged; nothing merges automatically, and a maintainer may decline a change that does not fit the skill.

## The most useful contributions

1. **False alarms** — the report flagged correct code. Open a "False alarm" issue with the finding and the code it pointed at.
2. **Missed problems** — a real crash, broken screen or store rejection the report did not catch. Open a "Missed problem" issue: what happened, the cause, the fix.
3. A pull request that turns one of those into a fixture and a fix.

## Before you open a pull request

```sh
dart format skills/flutter-store-ready/scripts tests/run.dart
dart run tests/run.dart        # must end with "everything passes"
```

- **A check changes → a fixture changes.** `tests/fixtures/` holds small projects with planted problems (the audit must report them) and decoys (it must not). A fix for a false alarm adds the case as a decoy; a new check plants the problem it finds and at least one decoy that looks similar and is fine.
- **One topic per pull request.** A new check, its guide text and its fixture belong together; unrelated clean-ups do not.

## What a reviewer checks

This skill runs scripts on other people's machines, and coding agents follow its Markdown files as instructions. Both are reviewed as code.

- **Scripts** (`skills/flutter-store-ready/scripts/`): pure `dart:io`, no packages, no network access, no downloads. They may start only `flutter`, `dart`, `git` and `keytool`. They never print or store passwords, tokens or keystore contents. They write only inside the audited project (and the report folder).
- **Guides and `SKILL.md`**: plain instructions for building and auditing a Flutter app. Nothing that tells an agent to run commands unrelated to that, to fetch remote content, to change its own settings, or to hide what it did from the user.
- **Agent-neutral**: no wording or tooling that only one coding agent understands. Agent-specific files are optional extras next to a neutral equivalent.
- **Policy facts** (store rules, dates, API levels, SDK requirements) come with a link to the official Apple or Google page in the pull request description. Without a source they are not merged.
- **Severity**: a finding is blocking only when it breaks the app for users, exposes their data, or gets the build rejected. A check that matches a keyword being present or absent is a recommendation at most.
- **Wording**: findings say what is wrong, where, why it matters and how to fix it, in plain language.

## What will not be merged

- Checks without a fixture, or "keyword is missing" checks without a decoy.
- New dependencies, binaries, generated or minified files, obfuscated code.
- Anything that sends data anywhere, or collects information about the audited project beyond the report.
- Changes to CI permissions, release settings or the license without a prior issue.

## Security problems

Do not open a public issue. See [SECURITY.md](SECURITY.md).

## License

By contributing you agree that your contribution is released under the repository's [MIT license](LICENSE).
