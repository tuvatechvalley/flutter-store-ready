# App Store readiness report

Generated: 2026-11-25T23:40:39.371315  
Project: `untouched`

**❌ NOT READY — fix the FAIL items before uploading.**

| Result | Count |
|---|---|
| ❌ FAIL | 3 |
| ⚠️ WARN | 6 |
| ✅ PASS | 5 |
| 📝 MANUAL | 12 |

> Static checks of the project files. They do not replace a TestFlight build on a real device or App Review itself.

## App identity

| Result | Check | Details | How to fix |
|---|---|---|---|
| ❌ FAIL | Bundle identifier | "com.example.counterApp" — com.example.* cannot be registered and the bundle id can never be changed after the first upload. | Set a permanent reverse-domain id you own in Xcode (Runner > Signing & Capabilities) for Debug, Profile and Release. |
| ✅ PASS | App name (CFBundleDisplayName) | "Counter App" (shown under the icon; keep it short, about 12 characters, or it is cut off). |  |
| ⚠️ WARN | Build number | Version 1.0.0, build 1. Each upload of the same version needs a higher build; a released version number can never be reused (pass --last-build-number to verify). |  |
| ❌ FAIL | App icon (1024 px) | Still the default Flutter icon. | Generate icons (e.g. flutter_launcher_icons with `remove_alpha_ios: true`). |

## Signing

| Result | Check | Details | How to fix |
|---|---|---|---|
| ❌ FAIL | Development team | No DEVELOPMENT_TEAM in the project: `flutter build ipa` cannot sign the archive. | Open ios/Runner.xcworkspace in Xcode > Runner > Signing & Capabilities and pick your team (needs a paid Apple Developer Program membership). See APP-STORE-RELEASE.md in the flutter-store-ready skill. |
| ✅ PASS | Signing style | Automatic signing: Xcode creates the distribution certificate and profile. |  |

## Build settings

| Result | Check | Details | How to fix |
|---|---|---|---|
| ⚠️ WARN | Deployment target | iOS 13.0 is accepted today. From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later. | Plan to raise the deployment target to 15.0 before April 2027 (check which of your users are still on iOS 13–14). |
| ✅ PASS | iPad orientations | iPad is supported; multitasking requirements are met. |  |

## Network & export compliance

| Result | Check | Details | How to fix |
|---|---|---|---|
| ✅ PASS | App Transport Security | HTTPS only. |  |
| ⚠️ WARN | Export compliance key | Missing: App Store Connect asks the export-compliance question on every upload and the build waits until someone answers. | Add ITSAppUsesNonExemptEncryption to Info.plist: <false/> when the app only uses HTTPS and the operating system's crypto. This is a legal declaration: decide it yourself. |

## Permissions

| Result | Check | Details | How to fix |
|---|---|---|---|
| ✅ PASS | Permission usage descriptions | Every known plugin in pubspec.yaml has its Info.plist keys. |  |

## Privacy

| Result | Check | Details | How to fix |
|---|---|---|---|
| ⚠️ WARN | Privacy manifest | No app privacy manifest. Required when your own code uses "required reason" APIs (UserDefaults, file timestamps, disk space, boot time) or collects data. | In Xcode: File > New > File > App Privacy, target Runner (creating the file by hand does not add it to the project). |

## Release build

| Result | Check | Details | How to fix |
|---|---|---|---|
| ⚠️ WARN | App archive (.ipa) | Not built. iOS builds need a Mac with Xcode (or a macOS CI runner such as Codemagic or GitHub Actions macos-latest). | flutter build ipa --release --obfuscate --split-debug-info=build/symbols-ios --dart-define-from-file=config/prod.json |

## Secrets

| Result | Check | Details | How to fix |
|---|---|---|---|
| ⚠️ WARN | Tracked secrets | Not a git repository; could not check tracked files. |  |

## App Store Connect (manual)

| Result | Check | Details | How to fix |
|---|---|---|---|
| 📝 MANUAL | Apple Developer Program | Paid membership (99 USD / year). Companies need a D-U-N-S number; enrollment can take days. |  |
| 📝 MANUAL | App record | Register the bundle id and create the app in App Store Connect (name, primary language, SKU). The app name must be unique on the store. |  |
| 📝 MANUAL | Build toolchain | Uploads must be built with Xcode 26 / iOS 26 SDK or later. From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later. Apple raises this every spring: check developer.apple.com/news/upcoming-requirements. |  |
| 📝 MANUAL | App Privacy ("nutrition labels") | Declare every data type you and your SDKs collect (crash data, analytics, identifiers) and whether it is linked to the user or used for tracking. |  |
| 📝 MANUAL | Privacy policy & support URL | Public HTTPS privacy policy URL in App Store Connect and inside the app; a working support URL. |  |
| 📝 MANUAL | Account deletion | If users can create an account, they must be able to delete it inside the app (guideline 5.1.1(v)) — not only deactivate it. |  |
| 📝 MANUAL | Review information | Contact details and notes explaining anything not obvious (special hardware, region locks, why a permission is needed). If the app has sign-in: a demo account that works (user + password) — a missing or broken one is the most common avoidable rejection. |  |
| 📝 MANUAL | Screenshots | iPhone screenshots for the largest display size are required; the app supports iPad, so iPad screenshots are required too. App Store Connect shows the exact sizes it currently accepts. They must show the real app. |  |
| 📝 MANUAL | Age rating & content rights | Complete the age-rating questionnaire; confirm you have the rights to third-party content. |  |
| 📝 MANUAL | EU trader status | To distribute in the EU, declare trader / non-trader status (Digital Services Act); traders publish contact details. |  |
| 📝 MANUAL | TestFlight first | Upload, wait for processing, test the exact build on a real device (fresh install, largest text size, no network) before submitting for review. |  |
| 📝 MANUAL | iPad | The app declares iPad support: App Review tests it on iPad. Check every screen there, or make the app iPhone-only. |  |
