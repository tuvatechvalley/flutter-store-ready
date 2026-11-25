# Data declarations: definitions and common SDKs

Official texts (check them before relying on a detail here): Google Play — Play Console Help, "Provide information for Google Play's Data safety section"; Apple — App Store Connect Help, "App privacy details". Policies and SDK behavior change; each SDK publishes its own data-disclosure page, which wins over this table.

## Definitions that decide most answers

| Term | Google Play (Data safety) | Apple (App Privacy) |
|---|---|---|
| Collected | Data transmitted off the device by the app or its SDKs. Data processed only on the device is not collected. Data processed ephemerally (in memory, only to serve the request) can be marked as such | Data transmitted off the device and stored longer than needed to serve the request in real time |
| Shared | Transferred to a third party. Transfers to a service provider acting for you, with user consent, or for legal reasons are not "sharing" | — (Apple asks about tracking and third-party advertising instead) |
| Linked to the user | — | Data connected to the user's identity (account, device id tied to an account …) |
| Tracking | — | Linking data from this app with other companies' data for advertising or measurement, or sharing it with data brokers. Requires the ATT prompt |
| Optional | The user can choose not to provide it and still use the app | — |
| Deletion | Whether users can request deletion of their data, and how | (Account deletion is a review guideline, 5.1.1(v), not a label) |

## Categories (console labels)

**Google Play data types:** Location (approximate, precise) · Personal info (name, email address, user IDs, address, phone number, race and ethnicity, political or religious beliefs, sexual orientation, other info) · Financial info (user payment info, purchase history, credit score, other) · Health and fitness · Messages · Photos and videos · Audio files · Files and docs · Calendar · Contacts · App activity (app interactions, in-app search history, installed apps, other user-generated content, other actions) · Web browsing · App info and performance (crash logs, diagnostics, other app performance data) · Device or other IDs.
**Purposes:** App functionality · Analytics · Developer communications · Advertising or marketing · Fraud prevention, security, and compliance · Personalization · Account management.

**Apple data types:** Contact Info (name, email address, phone number, physical address, other) · Health & Fitness · Financial Info (payment info, credit info, other) · Location (precise, coarse) · Sensitive Info · Contacts · User Content (emails or text messages, photos or videos, audio data, gameplay content, customer support, other) · Browsing History · Search History · Identifiers (user ID, device ID) · Purchases (purchase history) · Usage Data (product interaction, advertising data, other usage data) · Diagnostics (crash data, performance data, other diagnostic data) · Other Data.
**Purposes:** Third-Party Advertising · Developer's Advertising or Marketing · Analytics · Product Personalization · App Functionality · Other Purposes.

## Common SDKs (typical — confirm with the vendor's page and your configuration)

| Package (Flutter name) | Google Play: data types → purposes | Apple: data types | Notes |
|---|---|---|---|
| `google_mobile_ads` (AdMob) | Device or other IDs (advertising ID); App activity (app interactions); App info and performance (diagnostics); Location (approximate, from IP) → Advertising or marketing, Analytics, Fraud prevention. **Shared** for advertising | Identifiers (device ID); Usage Data (advertising data, product interaction); Diagnostics (performance data); Location (coarse) → Third-Party Advertising, Analytics. **Linked: no** unless you pass your own user id (e.g. rewarded-ad server-side verification). **Tracking: yes** only with personalized ads after the ATT prompt allowed it; with no prompt (or denied) and non-personalized ads: not tracking | Advertising ID declaration = yes when `AD_ID` is in the merged manifest. Child-directed / under-age-of-consent settings make ads non-personalized; ask the vendor page what is still collected. Not started on a platform (e.g. ads disabled on iOS) = nothing collected there |
| `firebase_analytics` | App activity (app interactions); Device or other IDs (app instance ID); App info and performance → Analytics | Usage Data (product interaction); Identifiers (device ID); Diagnostics → Analytics | Linked to the user if you set a user id |
| `firebase_crashlytics`, `sentry_flutter` | App info and performance (crash logs, diagnostics); Device or other IDs → Analytics, App functionality | Diagnostics (crash data, performance data) → App Functionality, Analytics | Linked if you attach user ids or e-mails to reports |
| `firebase_messaging`, `onesignal_flutter` | Device or other IDs (push token) → App functionality, Developer communications | Identifiers (device ID) → App Functionality | Linked when the token is stored with the account |
| Your own sign-in (`firebase_auth`, own API) | Personal info (email address, name, user IDs — each field you store) → App functionality, Account management | Contact Info (email, name); Identifiers (user ID) → App Functionality. **Linked** | Plus every profile field the app sends |
| `google_sign_in`, `sign_in_with_apple` | Personal info (email, name, user IDs) → Account management | Contact Info; Identifiers (user ID). **Linked** | |
| `in_app_purchase`, `purchases_flutter` | Financial info (purchase history) — when your app or server records purchases (receipt validation, a premium flag on your server) → App functionality | Purchases (purchase history) — same condition | RevenueCat (`purchases_flutter`) also sends an app user id |
| `flutter_stripe` and other payment SDKs | Financial info (user payment info, purchase history) → App functionality, Fraud prevention | Financial Info (payment info); Purchases | Card data handled by the processor is still collected by the app's SDK |
| `geolocator`, `location` | Location (precise / approximate) → only if sent off the device | Location (precise / coarse) → same condition | On-device use only (e.g. distance shown locally) is not collected |
| `image_picker`, `camera`, `record`, `file_picker` | Photos and videos / Audio files / Files and docs → only if uploaded | User Content (photos or videos, audio data, other) → only if uploaded | Local processing only = not collected |
| `device_info_plus`, `package_info_plus` | Device or other IDs / App info → only if sent to your server | Identifiers / Diagnostics → same condition | Often sent with crash or support reports |
| Local databases (`drift`, `sqflite`, `hive`, `shared_preferences`) | Nothing, unless synced to a server | Nothing, unless synced | Backups to the user's own cloud (iCloud / Google Drive by the OS) are not collection by you |
| Your own analytics events (sent to your server) | App activity (app interactions, other actions) → Analytics | Usage Data (product interaction) → Analytics. **Linked** if sent with the user id | Data safety counts it even though no SDK is involved |
| Push token stored on your server (`firebase_messaging` + your API) | Device or other IDs → App functionality (Developer communications if you send announcements) | Identifiers (device ID) → App Functionality. **Linked** when stored with the account | Register-for-guests flows still collect it — say so in the policy |
| Age band, birth year, parental consent | Personal info → Other info → App functionality, Account management | Other Data (or Contact Info if it is a date of birth) → App Functionality. **Linked** | Decides children's rules (`<kit>/STORE-POLICIES.md` section 9; `<kit>` = the flutter-store-ready skill) |
| Public nickname / profile shown to other users | Personal info (name or user IDs) → App functionality | Contact Info (name) or Other Data → App Functionality. **Linked** | Being visible to other users does not make it "not collected"; user content shown to others also needs report / block |
| Names or data of other people the user types in (contacts, family members, dedications) | Personal info (other info) or App activity (other user-generated content) → App functionality | User Content (other) → App Functionality | Say so in the privacy policy |
| IP addresses in your server logs | If kept and used beyond serving the request: Device or other IDs, or Approximate location when used for location (confirm with the official definitions) | Location (coarse) only if used to derive location; otherwise usually not a separate type (confirm) | State log retention in the privacy policy |
| Content that suggests a belief or health condition (a religious app, a diet app) | Using the app is not by itself collecting "Political or religious beliefs" or "Health info"; the type applies when the app records that information about the user | Same for Sensitive Info | Mark (confirm) and let the user decide |
| Local notifications, `share_plus`, `url_launcher` | Nothing (stays on the device or goes where the user chooses) | Nothing | |

## Quick consistency checks

- Apple: a data type is **linked** if any one of its collections is linked (the same type cannot be both).
- `PrivacyInfo.xcprivacy` (collected data types, tracking flag, tracking domains) says the same as the App Privacy answers.

- Ads SDK installed → Play "Contains ads: yes", Data safety lists device IDs, Advertising ID declaration answered; Apple App Privacy has advertising data.
- Tracking prompt shown (or `NSUserTrackingUsageDescription` present) ↔ Apple "used to track you" answers. No prompt → nothing marked as tracking, and the SDK configured not to track.
- Accounts → deletion answered in Data safety (in-app + web URL) and described in the privacy policy.
- Every data type declared in a store form appears in the privacy policy, and vice versa.
