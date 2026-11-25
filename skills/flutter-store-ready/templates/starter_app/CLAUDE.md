# Project rules (flutter-store-ready)

This app was set up with the **flutter-store-ready** skill. Follow its rules:

- Material import: `package:material_ui/material_ui.dart` (Flutter 3.47+).
- Never show raw error text: `mapToFailure` → `AppLocalizations.failureMessage`.
- Every data screen renders loading / error (+ retry) / empty / data → `AsyncValueView`.
- Secrets only in `SecureStore`. No `print`: use `AppLogger` (redacts secrets).
- New strings go into `AppLocalizations` in **every** language (missing = compile error).
- URL / deep-link parameters are untrusted: validate with `InputValidators`.
- Large text (200–300%) must work: no fixed heights around text, `Expanded` for text in rows, layout decisions via `WindowSize.of`. New screens go into `test/responsive_test.dart`.

## Before saying "done"

```bash
dart run tool/flutter_store_ready/verify.dart            # gates + report
dart run tool/flutter_store_ready/verify.dart --release  # + obfuscated AAB (and IPA on macOS) + store audits
```

Then give the user `build/reports/flutter-store-ready/PROJECT_REPORT.md` and summarize it in their language.
