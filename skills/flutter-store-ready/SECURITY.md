# Security (OWASP MASVS)

Reference implementation in `templates/starter_app/lib/core/`.

| MASVS | Control | Reference |
|---|---|---|
| STORAGE | Tokens only in Keychain/Keystore via `flutter_secure_storage`; iOS `first_unlock_this_device`, not synchronizable | `storage/secure_store.dart` |
| | iOS Keychain survives uninstall: wipe secrets on first launch after install (marker in SharedPreferences) | `security/token_store.dart` |
| | Android: `allowBackup="false"`, `dataExtractionRules`, `fullBackupContent` exclude everything | `scripts/harden_platforms.dart` |
| | Logs redact bearer tokens, JWTs, passwords/tokens/api keys, e-mails, card numbers; URLs logged without query | `logging/redactor.dart` |
| CRYPTO | No custom crypto; platform APIs only | — |
| AUTH | Access + refresh token, single-flight refresh, sign-out on rejected refresh | `network/auth_interceptor.dart` |
| | Generic "wrong e-mail or password" (no account enumeration); client-side lockout is UX only — real rate limiting is server-side | `features/auth/` |
| | Password fields: no suggestions, no IME learning, autofill hints | `login_page.dart` |
| NETWORK | HTTPS only; release refuses an `http://` config (fail closed) | `config/env.dart` |
| | SPKI pinning: `base64(sha256(SubjectPublicKeyInfo))`, ≥ 2 pins in prod (current + offline backup key) | `network/certificate_pinner.dart` |
| | `badCertificateCallback` always false; no redirects to other hosts | `network/api_client.dart` |
| | Android network security config: no cleartext, system CAs only in release; a separate **debug-only** config (`src/debug/res/xml/`) allows plain HTTP to a dev server (also from a real phone on the LAN) and user CAs for proxy tools | `scripts/harden_platforms.dart` |
| PLATFORM | Deep-link ids validated (`^[A-Za-z0-9_-]{1,64}$`), `from=` redirects only to internal paths (no open redirect), ids `Uri.encodeComponent`-ed in paths | `security/input_validators.dart`, `router/app_router.dart` |
| | Strip control / zero-width / bidi characters from user text | `InputValidators.sanitize` |
| | App content hidden in the app switcher; optional `FLAG_SECURE` | `widgets/privacy_shield.dart`, `harden_platforms.dart --secure-screens` |
| CODE | Every error path handled (see ERROR-HANDLING.md); no raw errors shown | `bootstrap.dart` |
| | CI: forbidden patterns, gitleaks over full history, OSV scan of `pubspec.lock`, Dependabot | `scripts/check_forbidden.dart`, template CI |
| RESILIENCE | `--obfuscate --split-debug-info=build/symbols`, R8; keep symbols private | `GOOGLE-PLAY-RELEASE.md` |
| | High-risk apps (banking, health): add freeRASP (root/jailbreak, hooks, emulator, tamper) — follow its current docs; on detection inform the user and lock sensitive actions | — |

## Pinning

Generate a pin:

```sh
openssl s_client -connect api.example.com:443 -servername api.example.com </dev/null \
  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary | base64
```

Dart's `HttpClient` does not use Android's network-security-config pins, so pinning is done in Dart (`IOHttpClientAdapter.validateCertificate`, leaf SPKI). Rotation: ship the new key's pin as backup first, switch the server after most users updated, remove the old pin later. A mismatch shows `SecurityFailure` and refuses to connect.

## Never

- Secrets in the app (API secret keys, signing keys, admin tokens) — anything shipped can be extracted; `--dart-define` values are not secret. Not secrets, and fine to ship: Firebase / Google API keys in `firebase_options.dart` (restrict them in the console), Stripe **publishable** keys (`pk_…`), Supabase anon keys, RevenueCat public SDK keys.
- Tokens in SharedPreferences / files / SQLite / logs.
- `badCertificateCallback => true`, `http://` (except a dev server in debug), `NSAllowsArbitraryLoads`, `usesCleartextTraffic="true"` in the main manifest (use the debug-only config; `NAVIGATION-AND-LIFECYCLE.md`, section 6).
- Showing exception text to users. Retrying POSTs without idempotency keys.
- Committing `key.properties`, `*.jks`, `.env`, `config/prod.json`. If it happened: rotate — deleting from history is not enough.
