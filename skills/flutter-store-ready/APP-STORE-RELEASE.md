# App Store (iOS) release

Audit at any time, on any operating system: `dart run <skill>/scripts/app_store_readiness.dart .` → `APP_STORE_READINESS.md` (also part of `project_report.dart`). The audit reads project files only. **Building and uploading needs a Mac with Xcode** (or a macOS CI runner: Codemagic, GitHub Actions `macos-latest`, Xcode Cloud).

Policy values in the script were checked on 2026-11-25. Re-check them before relying on them: [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/), [submit page](https://developer.apple.com/ios/submit/).

## 1. Permanent identity

The bundle identifier cannot change after the first upload; `com.example.*` cannot be registered. Set it at `flutter create --org` time, or in Xcode (Runner → Signing & Capabilities) for Debug, Profile **and** Release. It does not have to equal the Android `applicationId`, but one id for both keeps Firebase, deep links and support simpler.

## 2. Account and signing

- Apple Developer Program membership (paid, yearly). Organizations need a D-U-N-S number — start early, enrollment can take days.
- In Xcode: open `ios/Runner.xcworkspace` → Runner → Signing & Capabilities → select the team. This writes `DEVELOPMENT_TEAM` into `project.pbxproj`; without it `flutter build ipa` cannot sign.
- **Automatic signing** (default): Xcode creates the distribution certificate and profile. **Manual signing**: you maintain them; both expire after one year.
- CI: use an App Store Connect API key (`.p8`) or fastlane match. Never commit `.p12`, `.p8`, `.mobileprovision` — if one was committed, revoke it; removing it from history is not enough. On CI run the audit with `--ci` (a missing team is then a warning).

## 3. Version

`pubspec.yaml` → `version: 1.2.0+12`. `1.2.0` is the App Store version (max three numeric parts, can never be reused once released); `+12` is the build number, higher for every upload of that version. `--last-build-number 11` makes the audit verify it. Keep `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` in Info.plist — hard-coded values silently ignore pubspec.

## 4. Project settings the audit checks

| Check | Why |
|---|---|
| Deployment target ≥ iOS 13 | required for uploads since 2026-09-09; from April 2027 iOS 15 + iOS 27 SDK (warning today) |
| 1024 px icon: custom and **opaque** | an alpha channel is rejected at upload (`flutter_launcher_icons: remove_alpha_ios: true`) |
| iPad: all four orientations or `UIRequiresFullScreen` | upload validation fails otherwise; or make the app iPhone-only |
| `UILaunchStoryboardName` present | missing launch screen = letter-boxed app, rejected |
| No `NSAllowsArbitraryLoads` | plain HTTP needs a justification in review |
| `ITSAppUsesNonExemptEncryption` | without it every build waits for the export-compliance answer. `false` when the app only uses HTTPS and OS crypto. It is a legal declaration, so the scripts never add it for you |
| Permission keys for installed plugins | iOS kills the app when a permission is requested without its `NS…UsageDescription` |
| Permission texts explain the purpose | "Camera" / "This app needs the camera" is rejected (guideline 5.1.1). Write what the user gets: "Take a photo of your receipt to attach it to an expense." Localize in `InfoPlist.strings` |
| Privacy manifest in the Runner target | add with Xcode (File → New → File → App Privacy); a file created by hand is not bundled |
| Tracking SDKs → ATT | ads / attribution SDKs need `NSUserTrackingUsageDescription` and the prompt before tracking (5.1.2). The audit also warns when the key is set but the Dart code never calls `requestTrackingAuthorization()` |
| `google_maps_flutter` → `GMSServices.provideAPIKey` | missing = blank map on iOS |
| App name without "beta" / "demo" / "test" | rejected as an unfinished app (2.2) |
| `google_mobile_ads` → `GADApplicationIdentifier` | missing = crash at launch |
| Third-party login → Sign in with Apple | guideline 4.8: offer an equivalent privacy-focused login; plus the entitlement when the plugin is installed |
| Push SDK → `aps-environment` entitlement | otherwise no push token on iOS |
| Background modes | each one must be visibly needed (2.5.4) |
| Payment SDK without in-app purchase | digital content and subscriptions must use Apple in-app purchase (3.1.1); physical goods and services may use other payment |
| No certificates / API keys in git | |

## 5. Build and upload (on a Mac)

```sh
dart run tool/flutter_store_ready/verify.dart --release --config config/prod.json
# on macOS also runs:
#   flutter build ipa --release --obfuscate --split-debug-info=build/symbols-ios
#     --dart-define-from-file=config/prod.json
# → build/ios/ipa/*.ipa
```

Upload with Transporter, `xcrun altool --upload-app`, or Xcode Organizer. Keep `build/symbols-ios/` privately (upload to your crash reporter).

Then **TestFlight first**: wait for processing, install that exact build on a real device, and test a fresh install, sign-in, the largest accessibility text size, airplane mode, and every permission prompt.

## 6. App Store Connect (manual — listed in the report)

| Item | Notes |
|---|---|
| App record | name (unique on the store), primary language, bundle id, SKU |
| App Privacy | every data type you and your SDKs collect; linked to the user? used for tracking? Must match the privacy manifest and the privacy policy |
| Privacy policy + support URL | public HTTPS pages; policy also reachable inside the app |
| Account deletion | if users can create an account: delete it inside the app (5.1.1(v)), not only deactivate |
| Review information | working demo account, contact, notes for anything not obvious. Missing or broken demo logins are the most common avoidable rejection |
| Screenshots | for the largest iPhone size; iPad too when the app supports iPad. App Store Connect shows the sizes it currently accepts |
| Age rating, content rights | questionnaires |
| EU trader status | required to distribute in the EU (Digital Services Act) |
| Export compliance | answered once per build unless the Info.plist key is set |

## 7. Common rejections to check by hand

- Crashes or blank screens on first launch without network, or on iPad.
- Placeholder content, "beta" / "test" wording, broken links, lorem ipsum.
- Login required with no demo account, or sign-up forced before the user can see anything of value.
- Asking for a permission before the user understands why (ask at the moment of use).
- The app is only a wrapped website, or mentions other platforms ("also on Android").
- Error messages that show technical text (see `ERROR-HANDLING.md`, section 3).
