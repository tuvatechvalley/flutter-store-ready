// App Store (iOS) release readiness audit.
//
//   dart run <skill>/scripts/app_store_readiness.dart [project_dir]
//        [--ipa <path>] [--last-build-number <n>] [--report <path>]
//        [--json <path>] [--no-fail] [--ci] [--manual-only]
//
// Inspects the iOS project (bundle id, signing team, deployment target,
// icon, Info.plist, permission texts, privacy manifest, entitlements, SDKs
// that trigger App Review rules, built .ipa) and writes a Markdown report.
// Exit code 1 when any check FAILS.
//
// Everything is read from files: it runs on Windows and Linux too. Only the
// build itself (`flutter build ipa`) needs a Mac.
//
// Uses only dart:io so it runs anywhere the Flutter SDK is installed.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Policy values. Re-check every year:
/// https://developer.apple.com/news/upcoming-requirements/
/// and https://developer.apple.com/ios/submit/ (checked 2026-11-25).
const String minDeploymentTarget = '13.0'; // uploads since 2026-09-09
const String requiredXcode = 'Xcode 26 / iOS 26 SDK'; // since 2026-04-28

/// Announced: from April 2027 uploads need the iOS 27 SDK and must target
/// iOS 15 or later.
const String nextDeploymentTarget = '15.0';
const String nextRequirement =
    'From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later';

/// MD5 of Flutter's default 1024px app icon, to detect apps that would ship
/// with the Flutter logo.
const Set<String> defaultIconMd5 = {'c785f8932297af4acd5f5ccb7630f01c'};

enum Status { pass, warn, fail, manual }

final class Check {
  Check(this.area, this.title, this.status, this.detail, [this.fix]);

  final String area;
  final String title;
  final Status status;
  final String detail;
  final String? fix;

  Map<String, Object?> toJson() => {
    'area': area,
    'title': title,
    'status': status.name,
    'detail': detail,
    'fix': fix,
  };
}

final _checks = <Check>[];

void _add(String area, String title, Status s, String detail, [String? fix]) =>
    _checks.add(Check(area, title, s, detail, fix));

late final String _root;

/// `--ci`: the signing team / certificates are not on a CI machine.
bool _ci = false;

const _guide = 'APP-STORE-RELEASE.md in the flutter-store-ready skill';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  const valueFlags = {'--ipa', '--last-build-number', '--report', '--json'};
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (valueFlags.contains(args[i])) {
      i++;
    } else if (!args[i].startsWith('--')) {
      positional.add(args[i]);
    }
  }
  _root = Directory(
    positional.isEmpty ? Directory.current.path : positional.first,
  ).resolveSymbolicLinksSync();
  _ci = args.contains('--ci');

  final reportPath = opt('--report') ?? 'build/reports/app_store_readiness.md';
  final jsonPath = opt('--json');
  final noFail = args.contains('--no-fail');
  final lastBuild = int.tryParse(opt('--last-build-number') ?? '');

  if (args.contains('--manual-only')) {
    _manualChecks(ipad: false);
    _finish(reportPath, jsonPath, noFail);
    return;
  }
  final plist = _read('ios/Runner/Info.plist');
  final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
  if (plist == null || pbx == null) {
    _add(
      'Project',
      'ios/ project',
      Status.fail,
      'ios/Runner/Info.plist or ios/Runner.xcodeproj/project.pbxproj does not exist.',
      'Run `flutter create --platforms=ios .`',
    );
    _finish(reportPath, jsonPath, noFail);
    return;
  }
  final pubspec = _read('pubspec.yaml') ?? '';
  final entitlements = _entitlements();
  final ipad = _setting(
    pbx,
    'TARGETED_DEVICE_FAMILY',
  ).any((v) => v.contains('2'));

  _checkIdentity(plist, pbx, pubspec, lastBuild);
  _checkSigning(pbx);
  _checkBuildSettings(plist, pbx, ipad);
  _checkTransportAndCompliance(plist);
  _checkPermissionTexts(plist, pubspec);
  _checkPrivacy(plist, pbx, pubspec);
  _checkCapabilities(plist, pubspec, entitlements);
  _checkNativeKeys(pubspec);
  _checkBundle(opt('--ipa'));
  _checkSecretsInRepo();
  _manualChecks(ipad: ipad);

  _finish(reportPath, jsonPath, noFail);
}

// ----------------------------------------------------------------- identity

void _checkIdentity(String plist, String pbx, String pubspec, int? lastBuild) {
  const area = 'App identity';
  final ids = _setting(
    pbx,
    'PRODUCT_BUNDLE_IDENTIFIER',
  ).where((id) => !id.endsWith('.RunnerTests')).toSet();
  if (ids.isEmpty) {
    _add(
      area,
      'Bundle identifier',
      Status.fail,
      'PRODUCT_BUNDLE_IDENTIFIER not found in project.pbxproj.',
    );
  } else if (ids.any((id) => id.startsWith('com.example'))) {
    _add(
      area,
      'Bundle identifier',
      Status.fail,
      '"${ids.join('", "')}" — com.example.* cannot be registered and the bundle id can never be changed after the first upload.',
      'Set a permanent reverse-domain id you own in Xcode (Runner > Signing & Capabilities) for Debug, Profile and Release.',
    );
  } else if (ids.length > 1) {
    _add(
      area,
      'Bundle identifier',
      Status.warn,
      'Different ids per build configuration: ${ids.join(', ')}. Fine for flavors; make sure Release is the one registered in App Store Connect.',
    );
  } else {
    _add(
      area,
      'Bundle identifier',
      Status.pass,
      '"${ids.first}" (permanent after first upload).',
    );
  }

  final name = _plistString(plist, 'CFBundleDisplayName') ?? '';
  final looksDefault = name.isEmpty || RegExp(r'^[a-z0-9_]+$').hasMatch(name);
  _add(
    area,
    'App name (CFBundleDisplayName)',
    looksDefault ? Status.warn : Status.pass,
    looksDefault
        ? '"$name" looks like the package name, not a user-facing name.'
        : '"$name" (shown under the icon; keep it short, about 12 characters, or it is cut off).',
    looksDefault ? 'Set CFBundleDisplayName in ios/Runner/Info.plist.' : null,
  );
  if (RegExp(
    r'\b(beta|demo|test|dev|staging)\b',
    caseSensitive: false,
  ).hasMatch(name)) {
    _add(
      area,
      'App name is a release name',
      Status.warn,
      '"$name" contains a word that marks an unfinished build. App Review rejects "beta" / "demo" / "test" apps (guideline 2.2).',
      'Use the final name.',
    );
  }

  final version = RegExp(
    r'^version:\s*([0-9]+(?:\.[0-9]+){0,2})(?:\+([0-9]+))?\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (version == null) {
    _add(
      area,
      'Version',
      Status.fail,
      'pubspec.yaml has no valid `version: x.y.z+build` (App Store allows at most three numeric parts).',
    );
  } else {
    final build = int.tryParse(version.group(2) ?? '');
    if (build == null || build < 1) {
      _add(
        area,
        'Build number',
        Status.fail,
        'Missing build number (+N) in pubspec version.',
      );
    } else if (lastBuild != null && build <= lastBuild) {
      _add(
        area,
        'Build number',
        Status.fail,
        'Build $build is not greater than the last upload ($lastBuild).',
        'Bump the +N part of `version:` in pubspec.yaml.',
      );
    } else {
      _add(
        area,
        'Build number',
        lastBuild == null ? Status.warn : Status.pass,
        'Version ${version.group(1)}, build $build.'
            '${lastBuild == null ? ' Each upload of the same version needs a higher build; a released version number can never be reused (pass --last-build-number to verify).' : ''}',
      );
    }
  }
  for (final key in ['CFBundleShortVersionString', 'CFBundleVersion']) {
    final value = _plistString(plist, key) ?? '';
    if (!value.contains('FLUTTER_BUILD') &&
        !value.contains('MARKETING_VERSION') &&
        !value.contains('CURRENT_PROJECT_VERSION')) {
      _add(
        area,
        key,
        Status.warn,
        'Hard-coded to "$value": the version in pubspec.yaml is ignored on iOS.',
        'Use \$(FLUTTER_BUILD_NAME) / \$(FLUTTER_BUILD_NUMBER).',
      );
    }
  }

  final icon = File(
    '$_root/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
  );
  if (!icon.existsSync()) {
    _add(
      area,
      'App icon (1024 px)',
      Status.warn,
      'Icon-App-1024x1024@1x.png not found (custom icon set layout?). Check that AppIcon has a 1024×1024 image.',
    );
  } else if (defaultIconMd5.contains(_md5(icon))) {
    _add(
      area,
      'App icon (1024 px)',
      Status.fail,
      'Still the default Flutter icon.',
      'Generate icons (e.g. flutter_launcher_icons with `remove_alpha_ios: true`).',
    );
  } else if (_pngHasAlpha(icon)) {
    _add(
      area,
      'App icon (1024 px)',
      Status.fail,
      'The 1024 px icon has an alpha channel. App Store Connect rejects the upload (the icon must be opaque).',
      'Export it without transparency (flutter_launcher_icons: `remove_alpha_ios: true`).',
    );
  } else {
    _add(area, 'App icon (1024 px)', Status.pass, 'Custom, opaque icon.');
  }
}

// ------------------------------------------------------------------ signing

void _checkSigning(String pbx) {
  const area = 'Signing';
  final teams = _setting(
    pbx,
    'DEVELOPMENT_TEAM',
  ).where((t) => t.isNotEmpty).toSet();
  if (teams.isEmpty) {
    _add(
      area,
      'Development team',
      _ci ? Status.warn : Status.fail,
      _ci
          ? 'No DEVELOPMENT_TEAM in the project (expected when CI injects signing).'
          : 'No DEVELOPMENT_TEAM in the project: `flutter build ipa` cannot sign the archive.',
      'Open ios/Runner.xcworkspace in Xcode > Runner > Signing & Capabilities and pick your team (needs a paid Apple Developer Program membership). See $_guide.',
    );
  } else {
    _add(
      area,
      'Development team',
      teams.length == 1 ? Status.pass : Status.warn,
      teams.length == 1
          ? 'Team ${teams.first}.'
          : 'Several teams in one project: ${teams.join(', ')}.',
    );
  }
  final styles = _setting(pbx, 'CODE_SIGN_STYLE').toSet();
  final manual = styles.contains('Manual');
  _add(
    area,
    'Signing style',
    Status.pass,
    manual
        ? 'Manual signing: you maintain the distribution certificate and App Store provisioning profile (they expire after 1 year).'
        : 'Automatic signing: Xcode creates the distribution certificate and profile.',
  );
}

// ----------------------------------------------------------- build settings

void _checkBuildSettings(String plist, String pbx, bool ipad) {
  const area = 'Build settings';
  final targets = _setting(pbx, 'IPHONEOS_DEPLOYMENT_TARGET').toSet();
  final podfile = _read('ios/Podfile') ?? '';
  final podTarget = RegExp(
    r'''^\s*platform\s+:ios\s*,\s*['"]([0-9.]+)['"]''',
    multiLine: true,
  ).firstMatch(podfile)?.group(1);
  if (targets.isEmpty) {
    _add(
      area,
      'Deployment target',
      Status.warn,
      'IPHONEOS_DEPLOYMENT_TARGET not found.',
    );
  } else {
    final lowest = targets.reduce((a, b) => _versionAtLeast(a, b) ? b : a);
    final ok = _versionAtLeast(lowest, minDeploymentTarget);
    final futureProof = _versionAtLeast(lowest, nextDeploymentTarget);
    _add(
      area,
      'Deployment target',
      !ok ? Status.fail : (futureProof ? Status.pass : Status.warn),
      !ok
          ? 'iOS $lowest: App Store Connect only accepts apps targeting iOS $minDeploymentTarget or later.'
          : futureProof
          ? 'iOS $lowest.'
          : 'iOS $lowest is accepted today. $nextRequirement.',
      !ok
          ? 'Set the iOS deployment target to $minDeploymentTarget+ in Xcode.'
          : futureProof
          ? null
          : 'Plan to raise the deployment target to $nextDeploymentTarget before April 2027 (check which of your users are still on iOS 13–14).',
    );
    if (podTarget != null &&
        targets.any((t) => !_versionAtLeast(podTarget, t))) {
      _add(
        area,
        'Podfile platform',
        Status.warn,
        'Podfile says iOS $podTarget but the Xcode project targets iOS ${targets.join(' / ')}.',
        'Use the same version in ios/Podfile (`platform :ios, \'…\'`).',
      );
    }
  }

  if (ipad) {
    final orientations = _plistArray(
      plist,
      'UISupportedInterfaceOrientations~ipad',
    );
    final fullScreen = RegExp(
      r'<key>UIRequiresFullScreen</key>\s*<true\s*/>',
    ).hasMatch(plist);
    final allFour = orientations.toSet().length >= 4;
    _add(
      area,
      'iPad orientations',
      allFour || fullScreen ? Status.pass : Status.fail,
      allFour || fullScreen
          ? 'iPad is supported; multitasking requirements are met.'
          : 'iPad is supported but only ${orientations.length} orientation(s) are declared. App Store validation rejects iPad apps that do not support all four orientations unless they opt out of multitasking.',
      allFour || fullScreen
          ? null
          : 'Declare all four in UISupportedInterfaceOrientations~ipad, or set UIRequiresFullScreen = true, or remove iPad (TARGETED_DEVICE_FAMILY = 1).',
    );
  } else {
    _add(
      area,
      'Devices',
      Status.pass,
      'iPhone only (it still runs on iPad in compatibility mode, and App Review may test it there).',
    );
  }
  final launch = _plistString(plist, 'UILaunchStoryboardName');
  if (launch == null) {
    _add(
      area,
      'Launch screen',
      Status.fail,
      'UILaunchStoryboardName is missing: the app is letter-boxed and App Store validation rejects it.',
      'Restore LaunchScreen.storyboard and the Info.plist key.',
    );
  }
}

// ------------------------------------------------ transport & export rules

void _checkTransportAndCompliance(String plist) {
  const area = 'Network & export compliance';
  final arbitrary = RegExp(
    r'<key>NSAllowsArbitraryLoads</key>\s*<true\s*/>',
  ).hasMatch(plist);
  final insecureDomains = RegExp(
    r'<key>NSExceptionAllowsInsecureHTTPLoads</key>\s*<true\s*/>',
  ).allMatches(plist).length;
  _add(
    area,
    'App Transport Security',
    arbitrary ? Status.fail : (insecureDomains > 0 ? Status.warn : Status.pass),
    arbitrary
        ? 'NSAllowsArbitraryLoads = true allows plain HTTP everywhere; App Review asks for a justification.'
        : insecureDomains > 0
        ? '$insecureDomains domain(s) allow insecure HTTP.'
        : 'HTTPS only.',
    arbitrary || insecureDomains > 0
        ? 'Remove the exception and serve everything over HTTPS.'
        : null,
  );
  final encryption = plist.contains('ITSAppUsesNonExemptEncryption');
  _add(
    area,
    'Export compliance key',
    encryption ? Status.pass : Status.warn,
    encryption
        ? 'ITSAppUsesNonExemptEncryption is set.'
        : 'Missing: App Store Connect asks the export-compliance question on every upload and the build waits until someone answers.',
    encryption
        ? null
        : 'Add ITSAppUsesNonExemptEncryption to Info.plist: <false/> when the app only uses HTTPS and the operating system\'s crypto. This is a legal declaration: decide it yourself.',
  );
}

// -------------------------------------------------------- permission texts

void _checkPermissionTexts(String plist, String pubspec) {
  const area = 'Permissions';
  // plugin → Info.plist keys it needs. `strict`: the app crashes when the
  // plugin asks for the permission without the key.
  const required = <String, List<String>>{
    'camera': ['NSCameraUsageDescription', 'NSMicrophoneUsageDescription'],
    'mobile_scanner': ['NSCameraUsageDescription'],
    'qr_code_scanner': ['NSCameraUsageDescription'],
    'geolocator': ['NSLocationWhenInUseUsageDescription'],
    'location': ['NSLocationWhenInUseUsageDescription'],
    'google_maps_flutter': ['NSLocationWhenInUseUsageDescription'],
    'record': ['NSMicrophoneUsageDescription'],
    'flutter_sound': ['NSMicrophoneUsageDescription'],
    'speech_to_text': [
      'NSMicrophoneUsageDescription',
      'NSSpeechRecognitionUsageDescription',
    ],
    'local_auth': ['NSFaceIDUsageDescription'],
    'contacts_service': ['NSContactsUsageDescription'],
    'flutter_contacts': ['NSContactsUsageDescription'],
    'flutter_blue_plus': ['NSBluetoothAlwaysUsageDescription'],
    'flutter_reactive_ble': ['NSBluetoothAlwaysUsageDescription'],
    'app_tracking_transparency': ['NSUserTrackingUsageDescription'],
    'health': ['NSHealthShareUsageDescription'],
    'nfc_manager': ['NFCReaderUsageDescription'],
  };
  const recommended = <String, List<String>>{
    'image_picker': [
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
    ],
    'image_gallery_saver': ['NSPhotoLibraryAddUsageDescription'],
    'gal': ['NSPhotoLibraryAddUsageDescription'],
    'device_calendar': ['NSCalendarsFullAccessUsageDescription'],
  };
  List<String> missing(Map<String, List<String>> table) => [
    for (final MapEntry(key: pkg, value: keys) in table.entries)
      if (_hasPackage(pubspec, pkg))
        for (final key in keys)
          if (!plist.contains('<key>$key</key>')) '$key (for $pkg)',
  ];
  final hard = missing(required);
  final soft = missing(recommended);
  if (hard.isNotEmpty) {
    _add(
      area,
      'Permission usage descriptions',
      Status.fail,
      'Missing in Info.plist: ${hard.join(', ')}. iOS kills the app the moment it asks for the permission, and App Review rejects it.',
      'Add each key with a sentence that says what the app does with the data.',
    );
  }
  if (soft.isNotEmpty) {
    _add(
      area,
      'Permission usage descriptions (depending on use)',
      Status.warn,
      'Not in Info.plist: ${soft.join(', ')}. Needed as soon as that feature of the plugin is used.',
      'Add the keys for the features you use.',
    );
  }
  if (hard.isEmpty && soft.isEmpty) {
    _add(
      area,
      'Permission usage descriptions',
      Status.pass,
      'Every known plugin in pubspec.yaml has its Info.plist keys.',
    );
  }

  // App Review rejects vague purpose strings (guideline 5.1.1).
  final vague = <String>[];
  for (final m in RegExp(
    r'<key>(NS\w+UsageDescription|NFCReaderUsageDescription)</key>\s*<string>([^<]*)</string>',
  ).allMatches(plist)) {
    final text = m.group(2)!.trim();
    if (text.length < 20 ||
        RegExp(
          r'todo|lorem|^this app (needs|requires|uses)[^,.]*\.?$|^need|^required|^gerekli|izin gerek',
          caseSensitive: false,
        ).hasMatch(text)) {
      vague.add('${m.group(1)}: "$text"');
    }
  }
  if (vague.isNotEmpty) {
    _add(
      area,
      'Permission texts explain the purpose',
      Status.warn,
      'Too short or generic (App Review rejects these under guideline 5.1.1): ${vague.join('; ')}',
      'Say what the user gets: "Take a photo of your receipt to attach it to an expense." Localize it in InfoPlist.strings.',
    );
  }
  if (_hasPackage(pubspec, 'permission_handler')) {
    _add(
      area,
      'permission_handler',
      Status.manual,
      'permission_handler compiles in every permission API by default; App Review then asks for usage descriptions you do not need.',
      'Enable only the permissions you use via the GCC_PREPROCESSOR_DEFINITIONS macros in ios/Podfile (see the plugin README).',
    );
  }
}

// ------------------------------------------------------------------ privacy

void _checkPrivacy(String plist, String pbx, String pubspec) {
  const area = 'Privacy';
  final manifest = File('$_root/ios/Runner/PrivacyInfo.xcprivacy');
  final bundled = pbx.contains('PrivacyInfo.xcprivacy');
  _add(
    area,
    'Privacy manifest',
    manifest.existsSync() ? (bundled ? Status.pass : Status.fail) : Status.warn,
    manifest.existsSync()
        ? (bundled
              ? 'PrivacyInfo.xcprivacy is part of the Runner target.'
              : 'ios/Runner/PrivacyInfo.xcprivacy exists but is not in the Xcode project, so it is not shipped.')
        : 'No app privacy manifest. Required when your own code uses "required reason" APIs (UserDefaults, file timestamps, disk space, boot time) or collects data.',
    manifest.existsSync() && bundled
        ? null
        : 'In Xcode: File > New > File > App Privacy, target Runner (creating the file by hand does not add it to the project).',
  );

  const trackers = [
    'google_mobile_ads',
    'facebook_app_events',
    'appsflyer_sdk',
    'adjust_sdk',
    'applovin_max',
    'unity_ads_plugin',
    'branch_flutter_sdk',
  ];
  final present = trackers.where((p) => _hasPackage(pubspec, p)).toList();
  final prompt = _libContains('requestTrackingAuthorization');
  final key = plist.contains('NSUserTrackingUsageDescription');
  if (prompt && !key) {
    _add(
      area,
      'Tracking prompt without its Info.plist text',
      Status.fail,
      'The app calls requestTrackingAuthorization() but Info.plist has no NSUserTrackingUsageDescription: iOS terminates the app when the prompt is requested.',
      'Add NSUserTrackingUsageDescription with a sentence that explains what tracking is used for.',
    );
  } else if (present.isNotEmpty && !prompt && !key) {
    _add(
      area,
      'App Tracking Transparency',
      Status.manual,
      'Ad / attribution SDKs (${present.join(', ')}) and no tracking prompt: the app does not track on iOS (the advertising ID stays unavailable, ads are limited to non-tracking ones). '
          'Make sure the SDK is configured that way and that App Store Connect > App Privacy says "not used for tracking".',
    );
  } else if (present.isNotEmpty) {
    final att = key;
    _add(
      area,
      'App Tracking Transparency',
      att ? Status.pass : Status.warn,
      att
          ? 'NSUserTrackingUsageDescription is set (SDKs: ${present.join(', ')}). The ATT prompt must be shown before any tracking starts.'
          : 'Advertising / attribution SDKs (${present.join(', ')}) without NSUserTrackingUsageDescription. Tracking users without the ATT prompt is a rejection reason (guideline 5.1.2).',
      att
          ? null
          : 'Add app_tracking_transparency, the Info.plist key, and ask before initializing the SDK — or configure the SDK not to track.',
    );
    if (att && !_libContains('requestTrackingAuthorization')) {
      _add(
        area,
        'Tracking prompt is actually shown',
        Status.warn,
        'NSUserTrackingUsageDescription is set, but the Dart code never calls requestTrackingAuthorization(): the user is never asked, so the SDK must not track.',
        'Call AppTrackingTransparency.requestTrackingAuthorization() before the ad / attribution SDK starts, or remove the key if you do not track.',
      );
    }
  }
  if (_hasPackage(pubspec, 'google_mobile_ads') &&
      !plist.contains('GADApplicationIdentifier')) {
    _add(
      area,
      'AdMob application id',
      Status.fail,
      'google_mobile_ads is installed but GADApplicationIdentifier is not in Info.plist: the app crashes at launch.',
      'Add GADApplicationIdentifier with your AdMob app id.',
    );
  }
}

void _checkNativeKeys(String pubspec) {
  if (!_hasPackage(pubspec, 'google_maps_flutter')) return;
  final dir = Directory('$_root/ios/Runner');
  final native = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.swift') || f.path.endsWith('.m'))
      .map((f) => f.readAsStringSync())
      .join('\n');
  final ok = native.contains('provideAPIKey');
  _add(
    'Capabilities & review guidelines',
    'Google Maps API key (iOS)',
    ok ? Status.pass : Status.fail,
    ok
        ? 'GMSServices.provideAPIKey is called. Restrict the key to this bundle id in Google Cloud.'
        : 'google_maps_flutter is installed but AppDelegate never calls GMSServices.provideAPIKey: the map stays blank on iOS.',
    ok
        ? null
        : 'In ios/Runner/AppDelegate.swift: import GoogleMaps and call GMSServices.provideAPIKey("…") before GeneratedPluginRegistrant.',
  );
}

// ------------------------------------------------- capabilities & guidelines

void _checkCapabilities(String plist, String pubspec, String entitlements) {
  const area = 'Capabilities & review guidelines';
  const thirdPartyLogin = [
    'google_sign_in',
    'flutter_facebook_auth',
    'twitter_login',
    'flutter_login_facebook',
    'kakao_flutter_sdk',
  ];
  final logins = thirdPartyLogin.where((p) => _hasPackage(pubspec, p)).toList();
  final apple = _hasPackage(pubspec, 'sign_in_with_apple');
  if (logins.isNotEmpty && !apple) {
    _add(
      area,
      'Sign in with Apple',
      Status.warn,
      'Third-party login (${logins.join(', ')}) without Sign in with Apple. Guideline 4.8 requires an equivalent privacy-focused login option; Sign in with Apple is the usual way to satisfy it.',
      'Add sign_in_with_apple (and the capability in Xcode), unless the app only uses your company\'s own accounts.',
    );
  }
  if (apple) {
    final ok = entitlements.contains('com.apple.developer.applesignin');
    _add(
      area,
      'Sign in with Apple capability',
      ok ? Status.pass : Status.fail,
      ok
          ? 'Entitlement present.'
          : 'sign_in_with_apple is installed but the entitlement com.apple.developer.applesignin is missing: sign-in fails at runtime.',
      ok
          ? null
          : 'Xcode > Runner > Signing & Capabilities > + Capability > Sign in with Apple.',
    );
  }

  const push = ['firebase_messaging', 'onesignal_flutter', 'flutter_apns'];
  final pushSdks = push.where((p) => _hasPackage(pubspec, p)).toList();
  if (pushSdks.isNotEmpty) {
    final ok = entitlements.contains('aps-environment');
    _add(
      area,
      'Push notifications capability',
      ok ? Status.pass : Status.warn,
      ok
          ? 'aps-environment entitlement present.'
          : '${pushSdks.join(', ')} installed but no aps-environment entitlement: no push token is issued on iOS.',
      ok
          ? null
          : 'Xcode > Signing & Capabilities > + Capability > Push Notifications (and Background Modes > Remote notifications).',
    );
  }

  const modeNotes = <String, String>{
    'location':
        'continuous location: must be a core, visible feature; explain it in the review notes.',
    'audio': 'audio must really keep playing/recording in the background.',
    'voip': 'only for real VoIP calls using CallKit.',
    'fetch': 'background fetch: fine, but iOS decides when it runs.',
    'processing': 'needs BGTaskSchedulerPermittedIdentifiers.',
    'bluetooth-central': 'must talk to a real accessory in the background.',
    'external-accessory': 'must talk to a real accessory in the background.',
  };
  for (final mode in _plistArray(plist, 'UIBackgroundModes')) {
    if (mode == 'remote-notification') continue;
    _add(
      area,
      'Background mode: $mode',
      Status.warn,
      modeNotes[mode] ??
          'App Review rejects background modes the app does not visibly need (guideline 2.5.4).',
      'Remove it if it is not essential.',
    );
  }

  const payments = [
    'flutter_stripe',
    'stripe_payment',
    'iyzico',
    'pay',
    'flutter_paypal',
    'razorpay_flutter',
  ];
  final paymentSdks = payments.where((p) => _hasPackage(pubspec, p)).toList();
  final iap =
      _hasPackage(pubspec, 'in_app_purchase') ||
      _hasPackage(pubspec, 'purchases_flutter');
  if (paymentSdks.isNotEmpty && !iap) {
    _add(
      area,
      'Payments',
      Status.manual,
      'Payment SDK (${paymentSdks.join(', ')}) without in-app purchase. Fine for physical goods and real-world services. Digital content, subscriptions and feature unlocks must use Apple in-app purchase (guideline 3.1.1).',
    );
  }
}

// ------------------------------------------------------------------ bundle

void _checkBundle(String? ipaPath) {
  const area = 'Release build';
  File? ipa;
  if (ipaPath != null) {
    ipa = File(_abs(ipaPath));
  } else {
    final dir = Directory('$_root/build/ios/ipa');
    if (dir.existsSync()) {
      ipa = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ipa'))
          .firstOrNull;
    }
  }
  if (ipa == null || !ipa.existsSync()) {
    _add(
      area,
      'App archive (.ipa)',
      Status.warn,
      Platform.isMacOS
          ? 'Not built yet.'
          : 'Not built. iOS builds need a Mac with Xcode (or a macOS CI runner such as Codemagic or GitHub Actions macos-latest).',
      'flutter build ipa --release --obfuscate --split-debug-info=build/symbols-ios --dart-define-from-file=config/prod.json',
    );
    return;
  }
  final mb = ipa.lengthSync() / (1024 * 1024);
  _add(
    area,
    'App archive (.ipa)',
    Status.pass,
    '${_rel(ipa.path)} (${mb.toStringAsFixed(1)} MB). Upload with Transporter or `xcrun altool`, then test it in TestFlight.',
  );
  if (!Directory('$_root/build/symbols-ios').existsSync() &&
      !Directory('$_root/build/symbols').existsSync()) {
    _add(
      area,
      'Obfuscation symbols',
      Status.warn,
      'No split-debug-info folder found.',
      'Build with --obfuscate --split-debug-info=build/symbols-ios and keep the symbols privately to decode crash stack traces.',
    );
  }
}

// ----------------------------------------------------------------- secrets

void _checkSecretsInRepo() {
  const area = 'Secrets';
  final ProcessResult git;
  try {
    git = Process.runSync('git', ['ls-files'], workingDirectory: _root);
  } on ProcessException {
    return;
  }
  if (git.exitCode != 0) {
    _add(
      area,
      'Tracked secrets',
      Status.warn,
      'Not a git repository; could not check tracked files.',
    );
    return;
  }
  final leaked = const LineSplitter()
      .convert('${git.stdout}')
      .where(
        (f) =>
            f.endsWith('.p12') ||
            f.endsWith('.p8') ||
            f.endsWith('.mobileprovision') ||
            f.endsWith('.cer') && f.contains('ios'),
      )
      .toList();
  _add(
    area,
    'Certificates / API keys not in git',
    leaked.isEmpty ? Status.pass : Status.fail,
    leaked.isEmpty
        ? 'No signing certificates, provisioning profiles or App Store Connect keys are tracked.'
        : 'Tracked secret files: ${leaked.join(', ')}',
    leaked.isEmpty
        ? null
        : 'git rm --cached <file>, add to .gitignore, and REVOKE the certificate / API key (history keeps it).',
  );
}

// ------------------------------------------------------------------ manual

void _manualChecks({required bool ipad}) {
  const area = 'App Store Connect (manual)';
  void m(String title, String detail) =>
      _add(area, title, Status.manual, detail);
  m(
    'Apple Developer Program',
    'Paid membership (99 USD / year). Companies need a D-U-N-S number; enrollment can take days.',
  );
  m(
    'App record',
    'Register the bundle id and create the app in App Store Connect (name, primary language, SKU). The app name must be unique on the store.',
  );
  m(
    'Build toolchain',
    'Uploads must be built with $requiredXcode or later. $nextRequirement. Apple raises this every spring: check developer.apple.com/news/upcoming-requirements.',
  );
  m(
    'App Privacy ("nutrition labels")',
    'Declare every data type you and your SDKs collect (crash data, analytics, identifiers) and whether it is linked to the user or used for tracking.',
  );
  m(
    'Privacy policy & support URL',
    'Public HTTPS privacy policy URL in App Store Connect and inside the app; a working support URL.',
  );
  m(
    'Account deletion',
    'If users can create an account, they must be able to delete it inside the app (guideline 5.1.1(v)) — not only deactivate it.',
  );
  m(
    'Review information',
    'Contact details and notes explaining anything not obvious (special hardware, region locks, why a permission is needed). If the app has sign-in: a demo account that works (user + password) — a missing or broken one is the most common avoidable rejection.',
  );
  m(
    'Screenshots',
    'iPhone screenshots for the largest display size are required${ipad ? '; the app supports iPad, so iPad screenshots are required too' : ''}. App Store Connect shows the exact sizes it currently accepts. They must show the real app.',
  );
  m(
    'Age rating & content rights',
    'Complete the age-rating questionnaire; confirm you have the rights to third-party content.',
  );
  m(
    'EU trader status',
    'To distribute in the EU, declare trader / non-trader status (Digital Services Act); traders publish contact details.',
  );
  m(
    'TestFlight first',
    'Upload, wait for processing, test the exact build on a real device (fresh install, largest text size, no network) before submitting for review.',
  );
  if (ipad) {
    m(
      'iPad',
      'The app declares iPad support: App Review tests it on iPad. Check every screen there, or make the app iPhone-only.',
    );
  }
}

// ------------------------------------------------------------------- report

void _finish(String reportPath, String? jsonPath, bool noFail) {
  final counts = {
    for (final s in Status.values)
      s: _checks.where((c) => c.status == s).length,
  };
  final icon = {
    Status.pass: '✅ PASS',
    Status.warn: '⚠️ WARN',
    Status.fail: '❌ FAIL',
    Status.manual: '📝 MANUAL',
  };
  final verdict = counts[Status.fail]! > 0
      ? '❌ NOT READY — fix the FAIL items before uploading.'
      : counts[Status.warn]! > 0
      ? '⚠️ UPLOADABLE WITH WARNINGS — review them.'
      : '✅ READY (complete the MANUAL items in App Store Connect).';

  final b = StringBuffer()
    ..writeln('# App Store readiness report')
    ..writeln()
    ..writeln('Generated: ${DateTime.now().toIso8601String()}  ')
    ..writeln('Project: `${_root.split(RegExp(r'[\\/]')).last}`')
    ..writeln()
    ..writeln('**$verdict**')
    ..writeln()
    ..writeln('| Result | Count |\n|---|---|')
    ..writeln('| ❌ FAIL | ${counts[Status.fail]} |')
    ..writeln('| ⚠️ WARN | ${counts[Status.warn]} |')
    ..writeln('| ✅ PASS | ${counts[Status.pass]} |')
    ..writeln('| 📝 MANUAL | ${counts[Status.manual]} |')
    ..writeln()
    ..writeln(
      '> Static checks of the project files. They do not replace a TestFlight '
      'build on a real device or App Review itself.',
    );
  String? currentArea;
  for (final c in _checks) {
    if (c.area != currentArea) {
      currentArea = c.area;
      b
        ..writeln('\n## ${c.area}\n')
        ..writeln('| Result | Check | Details | How to fix |')
        ..writeln('|---|---|---|---|');
    }
    String cell(String? s) =>
        (s ?? '').replaceAll('|', r'\|').replaceAll('\n', '<br>');
    b.writeln(
      '| ${icon[c.status]} | ${cell(c.title)} | ${cell(c.detail)} | ${cell(c.fix)} |',
    );
  }

  final file = File(_abs(reportPath))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(b.toString());
  if (jsonPath != null) {
    File(_abs(jsonPath))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert([for (final c in _checks) c.toJson()]),
      );
  }

  print('\nApp Store readiness: $verdict');
  for (final c in _checks.where(
    (c) => c.status == Status.fail || c.status == Status.warn,
  )) {
    print(
      '  ${c.status == Status.fail ? 'FAIL' : 'WARN'}  [${c.area}] ${c.title}: ${c.detail.split('\n').first}',
    );
  }
  print('\nFull report: ${_rel(file.path)}');
  if (counts[Status.fail]! > 0 && !noFail) exitCode = 1;
}

// ------------------------------------------------------------------- utils

String _abs(String path) => File(path).isAbsolute ? path : '$_root/$path';

String? _read(String rel) {
  final f = File('$_root/$rel');
  return f.existsSync() ? f.readAsStringSync() : null;
}

/// Every value of a build setting in project.pbxproj (one per configuration).
List<String> _setting(String pbx, String key) => [
  for (final m in RegExp('\\b$key = ([^;]*);').allMatches(pbx))
    m.group(1)!.trim().replaceAll('"', ''),
];

String? _plistString(String plist, String key) => RegExp(
  '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
).firstMatch(plist)?.group(1);

List<String> _plistArray(String plist, String key) {
  final body = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>([\\s\\S]*?)</array>',
  ).firstMatch(plist)?.group(1);
  if (body == null) return const [];
  return [
    for (final m in RegExp(r'<string>([^<]*)</string>').allMatches(body))
      m.group(1)!,
  ];
}

bool _hasPackage(String pubspec, String name) =>
    RegExp('^\\s+$name:', multiLine: true).hasMatch(pubspec);

/// True when any Dart file under lib/ contains [text].
bool _libContains(String text) {
  final lib = Directory('$_root/lib');
  if (!lib.existsSync()) return false;
  return lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .any((f) => f.readAsStringSync().contains(text));
}

String _entitlements() {
  final dir = Directory('$_root/ios/Runner');
  if (!dir.existsSync()) return '';
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.entitlements'))
      .map((f) => f.readAsStringSync())
      .join('\n');
}

/// PNG color type 4 (grey + alpha) or 6 (RGBA) at byte 25 of the header.
bool _pngHasAlpha(File png) {
  final raf = png.openSync();
  try {
    final header = raf.readSync(26);
    if (header.length < 26) return false;
    return header[25] == 4 || header[25] == 6;
  } finally {
    raf.closeSync();
  }
}

bool _versionAtLeast(String version, String min) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final a = parts(version);
  final b = parts(min);
  for (var i = 0; i < b.length || i < a.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return true;
}

String _md5(File f) {
  try {
    if (Platform.isWindows) {
      final r = Process.runSync('certutil', ['-hashfile', f.path, 'MD5']);
      // Line 2 of the output is the hash (older Windows inserts spaces).
      final lines = '${r.stdout}'.split(RegExp(r'\r?\n'));
      return lines.length > 1
          ? lines[1].replaceAll(' ', '').trim().toLowerCase()
          : '';
    }
    final r = Process.runSync(
      Platform.isMacOS ? 'md5' : 'md5sum',
      Platform.isMacOS ? ['-q', f.path] : [f.path],
    );
    return '${r.stdout}'.trim().split(RegExp(r'\s+')).first;
  } on ProcessException {
    return '';
  }
}

String _rel(String path) => path.toLowerCase().startsWith(_root.toLowerCase())
    ? path.substring(_root.length + 1).replaceAll(r'\', '/')
    : path;
