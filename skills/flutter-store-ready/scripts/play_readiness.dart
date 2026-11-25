// Google Play release readiness audit.
//
//   dart run <skill>/scripts/play_readiness.dart [project_dir] [--aab <path>] [--last-version-code <n>]
//                                     [--report <path>] [--json <path>] [--no-fail] [--ci]
//
// Inspects the Android project (signing, keystore, ids, SDK levels, manifest,
// permissions, 16 KB support, built bundle) and writes a Markdown report.
// Exit code 1 when any check FAILS, so it can gate CI and release scripts.
//
// Secrets are never printed: passwords are only passed to keytool through
// environment variables, not through the command line.
//
// Uses only dart:io so it runs anywhere the Flutter SDK is installed.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Policy values. Re-check https://developer.android.com/google/play/requirements/target-sdk
/// every year: Play raises the bar each August 31.
const int requiredTargetSdk = 36; // new apps + updates since 2026-08-31
const int recommendedMinSdk = 24;
const List<int> minAgpFor16Kb = [8, 5, 1];

/// MD5 of Flutter's default launcher icon (mipmap-xxxhdpi), to detect apps
/// that would ship with the Flutter logo.
const Set<String> defaultIconMd5 = {'57838d52c318faff743130c3fcfae0c6'};

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

/// `--ci`: signing material cannot exist on a CI machine, so a missing
/// key.properties is reported as a warning instead of blocking.
bool _ci = false;

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  const valueFlags = {'--aab', '--last-version-code', '--report', '--json'};
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

  final reportPath = opt('--report') ?? 'build/reports/play_readiness.md';
  final jsonPath = opt('--json');
  final lastVersionCode = int.tryParse(opt('--last-version-code') ?? '');
  final aabPath =
      opt('--aab') ?? 'build/app/outputs/bundle/release/app-release.aab';

  _ci = args.contains('--ci');
  final android = Directory('$_root/android');
  if (args.contains('--manual-only')) {
    _manualChecks('');
    _finish(reportPath, jsonPath, args.contains('--no-fail'));
    return;
  }
  if (!android.existsSync()) {
    _add(
      'Project',
      'android/ folder',
      Status.fail,
      'android/ does not exist.',
      'Run `flutter create --platforms=android .` then `dart run tool/flutter_store_ready/harden_platforms.dart`.',
    );
    _finish(reportPath, jsonPath, args.contains('--no-fail'));
    return;
  }

  final gradle = _readGradle();
  final manifest = _read('android/app/src/main/AndroidManifest.xml') ?? '';
  final keyProps = _readProperties('android/key.properties');

  await _checkSigning(gradle, keyProps);
  _checkIdentity(gradle, manifest, lastVersionCode);
  _checkSdkLevels(gradle);
  _checkManifest(manifest);
  final merged = _mergedManifest();
  _checkPermissions(merged ?? manifest, merged: merged != null);
  _checkPluginsAndKeys(manifest, merged);
  _check16Kb(gradle);
  await _checkBundle(aabPath);
  _checkSecretsInRepo();
  _manualChecks(manifest);

  _finish(reportPath, jsonPath, args.contains('--no-fail'));
}

// ------------------------------------------------------------------ signing

Future<void> _checkSigning(String gradle, Map<String, String>? props) async {
  const area = 'Signing';
  if (props == null) {
    _add(
      area,
      'android/key.properties',
      _ci ? Status.warn : Status.fail,
      _ci
          ? 'Missing (expected on CI: the upload key lives on the release machine). Not checked: keystore, alias, passwords.'
          : 'Missing. Release builds would be signed with the debug key and Play rejects them.',
      'Create an upload key and android/key.properties (see GOOGLE-PLAY-RELEASE.md in the flutter-store-ready skill).',
    );
  } else {
    final missing = [
      'storeFile',
      'storePassword',
      'keyAlias',
      'keyPassword',
    ].where((k) => (props[k] ?? '').isEmpty).toList();
    _add(
      area,
      'key.properties fields',
      missing.isEmpty ? Status.pass : Status.fail,
      missing.isEmpty
          ? 'storeFile, storePassword, keyAlias, keyPassword are set.'
          : 'Missing: ${missing.join(', ')}',
    );
  }

  final usesKeyProps = gradle.contains('key.properties');
  // Only look at buildTypes: signingConfigs also has a `release { }` block.
  final buildTypesAt = gradle.indexOf('buildTypes');
  final buildTypes = buildTypesAt < 0 ? gradle : gradle.substring(buildTypesAt);
  final alwaysDebug =
      RegExp(
        // Kotlin: signingConfig = signingConfigs.getByName("debug")
        // Groovy: signingConfig signingConfigs.debug
        r'signingConfig\s*=?\s*signingConfigs\.(?:getByName\("debug"\)|debug)\s*$',
        multiLine: true,
      ).hasMatch(buildTypes) &&
      !buildTypes.contains('getByName("release")') &&
      !buildTypes.contains('signingConfigs.release');
  if (alwaysDebug || !usesKeyProps) {
    _add(
      area,
      'Release signingConfig',
      Status.fail,
      'The release build type is signed with the DEBUG key.',
      'Run `dart run tool/flutter_store_ready/harden_platforms.dart` or configure signingConfigs.release.',
    );
  } else {
    _add(
      area,
      'Release signingConfig',
      Status.pass,
      'Release uses signingConfigs "release" from key.properties.',
    );
  }

  if (props == null) return;
  // Java properties escape backslashes: C:\\keys\\upload.jks
  final storeFile = (props['storeFile'] ?? '').replaceAll(r'\\', r'\');
  // In Gradle, `file()` inside android/app resolves relative to android/app.
  final candidates = [
    File(storeFile),
    File('$_root/android/app/$storeFile'),
    File('$_root/android/$storeFile'),
  ];
  final keystore = candidates
      .where((f) => storeFile.isNotEmpty && f.existsSync())
      .firstOrNull;
  if (keystore == null) {
    _add(
      area,
      'Keystore file',
      Status.fail,
      'storeFile "$storeFile" not found (relative to android/app).',
      'Point storeFile to your upload keystore (.jks). Keep it OUTSIDE the repository.',
    );
    return;
  }
  final insideRepo = keystore.absolute.path.toLowerCase().startsWith(
    _root.toLowerCase(),
  );
  _add(
    area,
    'Keystore file',
    insideRepo ? Status.warn : Status.pass,
    insideRepo
        ? 'Found inside the project folder (${_rel(keystore.path)}). Easy to leak or delete.'
        : 'Found outside the repository.',
    insideRepo
        ? 'Move it outside the repo (e.g. ~/keys/) and back it up in a password manager.'
        : null,
  );

  await _inspectKeystore(keystore.path, props);
}

Future<void> _inspectKeystore(String path, Map<String, String> props) async {
  const area = 'Signing';
  final keytool = await _which('keytool');
  if (keytool == null) {
    _add(
      area,
      'Keystore contents',
      Status.warn,
      'keytool not found (install a JDK) - could not open the keystore.',
    );
    return;
  }
  final result = await Process.run(
    keytool,
    [
      '-list',
      '-v',
      '-keystore',
      path,
      '-alias',
      props['keyAlias'] ?? '',
      '-storepass:env',
      'PLAY_AUDIT_STOREPASS',
    ],
    environment: {'PLAY_AUDIT_STOREPASS': props['storePassword'] ?? ''},
  );
  final out = '${result.stdout}\n${result.stderr}';
  if (result.exitCode != 0) {
    final reason =
        out.contains('password was incorrect') ||
            out.contains('Keystore was tampered')
        ? 'storePassword is wrong.'
        : out.contains('does not exist')
        ? 'Alias "${props['keyAlias']}" does not exist in the keystore.'
        : 'keytool could not read the keystore.';
    _add(
      area,
      'Keystore contents',
      Status.fail,
      reason,
      'Fix key.properties so it matches the keystore.',
    );
    return;
  }
  final until = RegExp(r'until:\s*(.+)').firstMatch(out)?.group(1)?.trim();
  final owner =
      RegExp(r'Owner:\s*(.+)').firstMatch(out)?.group(1)?.trim() ?? '';
  final algo =
      RegExp(r'Signature algorithm name:\s*(\S+)').firstMatch(out)?.group(1) ??
      '?';
  final sha256 = RegExp(r'SHA256:\s*(\S+)').firstMatch(out)?.group(1) ?? '?';
  if (owner.contains('Android Debug')) {
    _add(
      area,
      'Upload key',
      Status.fail,
      'The keystore contains the Android DEBUG certificate.',
      'Generate a real upload key with keytool -genkeypair (GOOGLE-PLAY-RELEASE.md in the flutter-store-ready skill).',
    );
  } else {
    _add(
      area,
      'Upload key',
      Status.pass,
      'Alias "${props['keyAlias']}" OK. Algorithm $algo. SHA-256 $sha256. Valid until $until.\n'
          'Register this SHA-256 as the *upload* certificate if Play App Signing asks for it.',
    );
  }
  final year = int.tryParse(
    RegExp(r'(\d{4})\s*$').firstMatch(until ?? '')?.group(1) ?? '',
  );
  if (year != null && year < DateTime.now().year + 25) {
    _add(
      area,
      'Key validity',
      Status.warn,
      'Certificate expires in $year.',
      'Use -validity 10000 (≈27 years) when creating upload keys.',
    );
  }
}

// ----------------------------------------------------------------- identity

void _checkIdentity(String gradle, String manifest, int? lastVersionCode) {
  const area = 'App identity';
  final appId = RegExp(
    r'applicationId\s*=?\s*"([^"]+)"',
  ).firstMatch(gradle)?.group(1);
  if (appId == null) {
    _add(
      area,
      'applicationId',
      Status.fail,
      'Not found in android/app/build.gradle(.kts).',
    );
  } else if (appId.startsWith('com.example') ||
      appId.startsWith('com.android') ||
      appId.contains('flutter')) {
    _add(
      area,
      'applicationId',
      Status.fail,
      '"$appId" — Play rejects com.example.* and it can never be changed after release.',
      'Choose a permanent reverse-domain id you own, e.g. com.yourcompany.app (also update namespace and the Kotlin package).',
    );
  } else {
    _add(
      area,
      'applicationId',
      Status.pass,
      '"$appId" (permanent after first upload).',
    );
  }

  final pubspec = _read('pubspec.yaml') ?? '';
  final version = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (version == null) {
    _add(
      area,
      'Version',
      Status.fail,
      'pubspec.yaml has no valid `version: x.y.z+build`.',
    );
  } else {
    final code = int.tryParse(version.group(2) ?? '');
    if (code == null || code < 1) {
      _add(
        area,
        'versionCode',
        Status.fail,
        'Missing build number (+N) in pubspec version.',
      );
    } else if (lastVersionCode != null && code <= lastVersionCode) {
      _add(
        area,
        'versionCode',
        Status.fail,
        'versionCode $code is not greater than the last upload ($lastVersionCode).',
        'Bump the +N part of `version:` in pubspec.yaml.',
      );
    } else {
      _add(
        area,
        'versionCode',
        lastVersionCode == null ? Status.warn : Status.pass,
        'versionName ${version.group(1)}, versionCode $code.'
            '${lastVersionCode == null ? ' Must be higher than every previous upload (pass --last-version-code to verify).' : ''}',
      );
    }
    if (code != null && code > 2100000000) {
      _add(
        area,
        'versionCode range',
        Status.fail,
        'versionCode must be <= 2100000000.',
      );
    }
  }

  final label =
      RegExp(r'android:label="([^"]*)"').firstMatch(manifest)?.group(1) ?? '';
  final looksDefault = label.isEmpty || RegExp(r'^[a-z0-9_]+$').hasMatch(label);
  _add(
    area,
    'App name (android:label)',
    looksDefault ? Status.warn : Status.pass,
    looksDefault
        ? '"$label" looks like the package name, not a user-facing name.'
        : '"$label"',
    looksDefault
        ? 'Set android:label to the real app name (or a @string resource for localization).'
        : null,
  );
  if (RegExp(
    r'\b(beta|demo|test|dev|staging)\b',
    caseSensitive: false,
  ).hasMatch(label)) {
    _add(
      area,
      'App name is a release name',
      Status.warn,
      '"$label" contains a word that marks an unfinished build. Stores reject "beta" / "demo" / "test" apps on the production track.',
      'Use the final name (keep the dev label in a debug flavor only).',
    );
  }

  final icon = File(
    '$_root/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
  );
  if (icon.existsSync()) {
    final isDefault = defaultIconMd5.contains(_md5(icon));
    _add(
      area,
      'Launcher icon',
      isDefault ? Status.fail : Status.pass,
      isDefault ? 'Still the default Flutter icon.' : 'Custom icon present.',
      isDefault
          ? 'Generate icons (e.g. flutter_launcher_icons) incl. adaptive + monochrome.'
          : null,
    );
  }
}

// ---------------------------------------------------------------- SDK level

void _checkSdkLevels(String gradle) {
  const area = 'SDK levels';
  final flutterDefaults = _flutterGradleDefaults();
  int? resolve(String key, String flutterKey) {
    final m = RegExp('$key\\s*=?\\s*(\\S+)').firstMatch(gradle)?.group(1);
    if (m == null) return null;
    return int.tryParse(m) ??
        (m.contains('flutter.') ? flutterDefaults[flutterKey] : null);
  }

  final target = resolve('targetSdk(?:Version)?', 'targetSdkVersion');
  if (target == null) {
    _add(
      area,
      'targetSdk',
      Status.warn,
      'Could not resolve targetSdk (Flutter SDK not found to read its default).',
      'Ensure targetSdk >= $requiredTargetSdk (Android 16). Check with `flutter build appbundle` output or Play Console.',
    );
  } else {
    _add(
      area,
      'targetSdk',
      target >= requiredTargetSdk ? Status.pass : Status.fail,
      'targetSdk $target (Play requires >= $requiredTargetSdk for new apps and updates).',
      target >= requiredTargetSdk
          ? null
          : 'Set targetSdk = $requiredTargetSdk and test the Android 16 behavior changes.',
    );
  }
  final compile = resolve('compileSdk(?:Version)?', 'compileSdkVersion');
  if (compile != null && target != null && compile < target) {
    _add(
      area,
      'compileSdk',
      Status.fail,
      'compileSdk $compile < targetSdk $target.',
    );
  }
  final min = resolve('minSdk(?:Version)?', 'minSdkVersion');
  if (min != null) {
    _add(
      area,
      'minSdk',
      min >= 21 ? Status.pass : Status.warn,
      'minSdk $min${min < recommendedMinSdk ? ' (Flutter default is $recommendedMinSdk; older devices need extra testing)' : ''}.',
    );
  }
}

// ----------------------------------------------------------------- manifest

void _checkManifest(String manifest) {
  const area = 'Manifest & security';
  _add(
    area,
    'INTERNET permission (main manifest)',
    manifest.contains('android.permission.INTERNET')
        ? Status.pass
        : Status.fail,
    manifest.contains('android.permission.INTERNET')
        ? 'Present.'
        : 'Missing: the RELEASE build cannot reach the network (debug works, so this is often missed).',
    'Add <uses-permission android:name="android.permission.INTERNET"/> to app/src/main/AndroidManifest.xml.',
  );

  if (RegExp(r'android:debuggable="true"').hasMatch(manifest)) {
    _add(
      area,
      'debuggable',
      Status.fail,
      'android:debuggable="true" in the main manifest. Play rejects it.',
    );
  }
  final cleartext = RegExp(
    r'android:usesCleartextTraffic="true"',
  ).hasMatch(manifest);
  final nsc = manifest.contains('android:networkSecurityConfig');
  _add(
    area,
    'Cleartext HTTP',
    cleartext ? Status.fail : (nsc ? Status.pass : Status.warn),
    cleartext
        ? 'usesCleartextTraffic="true" allows unencrypted HTTP.'
        : (nsc
              ? 'Blocked via network security config.'
              : 'No network security config.'),
    cleartext || !nsc
        ? 'Run `dart run tool/flutter_store_ready/harden_platforms.dart`.'
        : null,
  );

  final backup = RegExp(r'android:allowBackup="false"').hasMatch(manifest);
  _add(
    area,
    'Backups',
    backup ? Status.pass : Status.warn,
    backup
        ? 'allowBackup="false".'
        : 'App data (incl. caches) can be copied by adb/cloud backup.',
    backup ? null : 'Set allowBackup="false" and add dataExtractionRules.',
  );

  // Components with intent filters must declare android:exported (API 31+).
  for (final m in RegExp(
    r'<(activity|service|receiver)\b([^>]*)>([\s\S]*?)</\1>',
  ).allMatches(manifest)) {
    if (m.group(3)!.contains('<intent-filter') &&
        !m.group(2)!.contains('android:exported')) {
      final name =
          RegExp(r'android:name="([^"]+)"').firstMatch(m.group(2)!)?.group(1) ??
          m.group(1);
      _add(
        area,
        'android:exported',
        Status.fail,
        '$name has an intent-filter but no android:exported.',
      );
    }
  }
}

void _checkPermissions(String manifest, {required bool merged}) {
  const area = 'Permissions & policy';
  // Permissions that need a Play Console declaration or are usually rejected.
  const sensitive = <String, String>{
    'READ_SMS':
        'SMS/Call Log policy: only default SMS/dialer apps. Declaration form required.',
    'SEND_SMS': 'SMS/Call Log policy: declaration form required.',
    'RECEIVE_SMS': 'SMS/Call Log policy: declaration form required.',
    'READ_CALL_LOG': 'SMS/Call Log policy: declaration form required.',
    'WRITE_CALL_LOG': 'SMS/Call Log policy: declaration form required.',
    'PROCESS_OUTGOING_CALLS': 'SMS/Call Log policy: declaration form required.',
    'QUERY_ALL_PACKAGES':
        'Package visibility policy: needs a core-use justification; prefer <queries>.',
    'MANAGE_EXTERNAL_STORAGE':
        'All files access: only for file managers/backup apps; declaration required.',
    'ACCESS_BACKGROUND_LOCATION':
        'Background location: declaration + video demo + prominent disclosure.',
    'REQUEST_INSTALL_PACKAGES':
        'Install packages: restricted use cases only; declaration required.',
    'READ_MEDIA_IMAGES':
        'Photo/video permissions policy: use the Android photo picker unless core use; declaration required.',
    'READ_MEDIA_VIDEO':
        'Photo/video permissions policy: use the photo picker unless core use; declaration required.',
    'USE_FULL_SCREEN_INTENT':
        'Only for calls/alarms; declaration required on Android 14+.',
    'USE_EXACT_ALARM':
        'Only for alarm/calendar apps; prefer SCHEDULE_EXACT_ALARM.',
    'SYSTEM_ALERT_WINDOW': 'Draw over other apps: heavily restricted, avoid.',
    'BIND_ACCESSIBILITY_SERVICE':
        'Accessibility API policy: declaration + prominent disclosure.',
    'READ_PHONE_STATE':
        'Device identifiers: do not use for advertising/analytics IDs.',
    'ACCESS_FINE_LOCATION':
        'Requires Data safety declaration and runtime-permission rationale.',
    'CAMERA':
        'Requires Data safety declaration and runtime-permission rationale.',
    'RECORD_AUDIO':
        'Requires Data safety declaration and runtime-permission rationale.',
  };
  final declared = RegExp(
    r'android\.permission\.([A-Z_]+)',
  ).allMatches(manifest).map((m) => m.group(1)!).toSet();
  final hits = declared.where(sensitive.containsKey).toList();
  if (hits.isEmpty) {
    _add(
      area,
      'Sensitive permissions (${merged ? 'merged release manifest' : 'main manifest'})',
      Status.pass,
      merged
          ? 'None in the manifest that ships (app + every plugin).'
          : 'None declared in the app manifest. Plugins can add more: build a release once (`flutter build appbundle`) and run this audit again to check the merged manifest.',
    );
  }
  for (final p in hits) {
    _add(
      area,
      p,
      Status.warn,
      sensitive[p]!,
      'Remove if not essential, otherwise complete the Play Console declaration.',
    );
  }
  for (final fgs in declared.where(
    (p) => p.startsWith('FOREGROUND_SERVICE_'),
  )) {
    _add(
      area,
      fgs,
      Status.warn,
      'Foreground service type: Play Console declaration + video required.',
    );
  }
}

// ---------------------------------------------------- plugins, keys, ids

/// The manifest Gradle really ships: the app's plus every plugin's. It only
/// exists after a release build.
String? _mergedManifest() {
  for (final dir in [
    'build/app/intermediates/merged_manifests/release',
    'build/app/intermediates/merged_manifest/release',
  ]) {
    final d = Directory('$_root/$dir');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('AndroidManifest.xml')) return f.readAsStringSync();
    }
  }
  return null;
}

void _checkPluginsAndKeys(String manifest, String? merged) {
  const area = 'Permissions & policy';
  final pubspec = _read('pubspec.yaml') ?? '';
  bool pkg(String name) =>
      RegExp('^\\s+$name:', multiLine: true).hasMatch(pubspec);
  Set<String> permissions(String xml) => RegExp(
    r'<uses-permission[^>]*android:name="([^"]+)"',
  ).allMatches(xml).map((m) => m.group(1)!).toSet();

  if (merged != null) {
    final added = permissions(merged).difference(permissions(manifest)).toList()
      ..sort();
    if (added.isNotEmpty) {
      _add(
        area,
        'Permissions added by plugins',
        Status.manual,
        'Not in your manifest but in the one that ships: ${added.map((p) => p.split('.').last).join(', ')}. Google reviews the shipped manifest.',
        'For each one: is the feature really used? If not, remove it with <uses-permission android:name="…" tools:node="remove"/>. If yes, cover it in the Data safety form.',
      );
    }
  }

  final adSdks = [
    'google_mobile_ads',
    'applovin_max',
    'unity_ads_plugin',
    'facebook_audience_network',
    'appsflyer_sdk',
    'adjust_sdk',
  ].where(pkg).toList();
  const adIdPermission = 'com.google.android.gms.permission.AD_ID';
  if (merged != null && merged.contains(adIdPermission)) {
    _add(
      area,
      'Advertising ID declaration',
      Status.manual,
      'The shipped manifest has the AD_ID permission${adSdks.isEmpty ? '' : ' (${adSdks.join(', ')})'}. In Play Console > App content > Advertising ID answer "Yes" and choose the purposes; the Data safety form must list "Device or other IDs". A mismatch blocks the release.',
    );
  } else if (merged != null && adSdks.isNotEmpty) {
    _add(
      area,
      'Advertising ID permission',
      Status.warn,
      'Ad / attribution SDK (${adSdks.join(', ')}) but the shipped manifest has no AD_ID permission: on Android 13+ the advertising ID is all zeros, which lowers ad revenue and breaks attribution.',
      'Add <uses-permission android:name="$adIdPermission"/> — unless the app is for children, where it must stay out.',
    );
  } else if (adSdks.isNotEmpty) {
    _add(
      area,
      'Advertising ID declaration',
      Status.manual,
      'Ad / attribution SDK (${adSdks.join(', ')}): answer the Advertising ID question in Play Console > App content to match what the shipped manifest declares (build a release and re-run this audit to check it).',
    );
  }

  if (pkg('google_maps_flutter') &&
      !(merged ?? manifest).contains('com.google.android.geo.API_KEY')) {
    _add(
      area,
      'Google Maps API key',
      Status.fail,
      'google_maps_flutter is installed but the manifest has no com.google.android.geo.API_KEY meta-data: the map stays blank.',
      'Add <meta-data android:name="com.google.android.geo.API_KEY" android:value="…"/> inside <application>.',
    );
  }

  final fingerprintUsers = [
    'google_sign_in',
    'google_maps_flutter',
    'firebase_auth',
    'firebase_app_check',
    'app_links',
    'uni_links',
  ].where(pkg).toList();
  if (fingerprintUsers.isNotEmpty) {
    _add(
      'Signing',
      'Release fingerprints registered with Google',
      Status.manual,
      'Used by ${fingerprintUsers.join(', ')}. Google Play re-signs the app with the *app signing key*, whose SHA-1 / SHA-256 differ from your upload key and from debug. '
          'Register all three where the service checks them: Firebase project settings, API key restrictions in Google Cloud (Maps), the OAuth client (Google sign-in), assetlinks.json (app links). '
          'Find the app signing fingerprints in Play Console > Test and release > App integrity.',
      'Typical symptom when one is missing: works in debug, then a grey map, a failed Google sign-in or links opening the browser in the store build.',
    );
  }

  final payments = [
    'flutter_stripe',
    'stripe_payment',
    'razorpay_flutter',
    'flutter_paypal',
    'iyzico',
  ].where(pkg).toList();
  if (payments.isNotEmpty &&
      !pkg('in_app_purchase') &&
      !pkg('purchases_flutter')) {
    _add(
      area,
      'Payments',
      Status.manual,
      'Payment SDK (${payments.join(', ')}) without Google Play Billing. Fine for physical goods and real-world services; digital content, subscriptions and feature unlocks must use Play Billing (regional exceptions exist).',
    );
  }
}

// ------------------------------------------------------------------- 16 KB

void _check16Kb(String gradle) {
  const area = '16 KB page size';
  final settings =
      _read('android/settings.gradle.kts') ??
      _read('android/settings.gradle') ??
      '';
  final agp = RegExp(
    r'''com\.android\.application["']?\)?\s*version\s*["']([0-9.]+)''',
  ).firstMatch(settings)?.group(1);
  if (agp == null) {
    _add(
      area,
      'Android Gradle Plugin',
      Status.warn,
      'AGP version not found in settings.gradle(.kts).',
    );
  } else {
    final ok = _versionAtLeast(agp, minAgpFor16Kb);
    _add(
      area,
      'Android Gradle Plugin',
      ok ? Status.pass : Status.fail,
      'AGP $agp${ok ? '' : ' (needs >= ${minAgpFor16Kb.join('.')} to align native libraries for 16 KB devices)'}.',
      ok
          ? null
          : 'Upgrade AGP (and Flutter) — required for apps targeting Android 15+.',
    );
  }
  final ndk = RegExp(r'ndkVersion\s*=\s*"(\d+)').firstMatch(gradle)?.group(1);
  if (ndk != null && (int.tryParse(ndk) ?? 0) < 28) {
    _add(
      area,
      'NDK',
      Status.warn,
      'NDK r$ndk: r28+ builds 16 KB-aligned by default.',
      'Use ndkVersion = flutter.ndkVersion.',
    );
  }
  _add(
    area,
    'Plugin native libraries',
    Status.manual,
    'Every plugin with .so files must be 16 KB aligned.',
    'After uploading, open Play Console > App bundle explorer > "Memory page size" — it must say compliant.',
  );
}

// ------------------------------------------------------------------ bundle

Future<void> _checkBundle(String aabPath) async {
  const area = 'Release bundle';
  final aab = File(_abs(aabPath));
  if (!aab.existsSync()) {
    _add(
      area,
      'App bundle (.aab)',
      Status.warn,
      'Not built yet ($aabPath).',
      'flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=config/prod.json',
    );
    return;
  }
  final mb = aab.lengthSync() / (1024 * 1024);
  _add(
    area,
    'App bundle (.aab)',
    Status.pass,
    '${_rel(aab.path)} (${mb.toStringAsFixed(1)} MB).',
  );
  final keytool = await _which('keytool');
  if (keytool == null) return;
  final r = await Process.run(keytool, ['-printcert', '-jarfile', aab.path]);
  final out = '${r.stdout}';
  if (out.trim().isEmpty || out.contains('Not a signed jar')) {
    _add(area, 'Bundle signature', Status.fail, 'The bundle is not signed.');
  } else if (out.contains('CN=Android Debug')) {
    _add(
      area,
      'Bundle signature',
      Status.fail,
      'Signed with the DEBUG certificate. Play Console will reject it.',
      'Create android/key.properties and rebuild.',
    );
  } else {
    final owner = RegExp(r'Owner:\s*(.+)').firstMatch(out)?.group(1)?.trim();
    _add(area, 'Bundle signature', Status.pass, 'Signed by: $owner');
  }
  if (!Directory('$_root/build/symbols').existsSync()) {
    _add(
      area,
      'Obfuscation symbols',
      Status.warn,
      'build/symbols not found.',
      'Build with --obfuscate --split-debug-info=build/symbols and keep the symbols privately to decode crash stack traces.',
    );
  }
}

// ----------------------------------------------------------------- secrets

void _checkSecretsInRepo() {
  const area = 'Secrets';
  final git = Process.runSync('git', ['ls-files'], workingDirectory: _root);
  if (git.exitCode != 0) {
    _add(
      area,
      'Tracked secrets',
      Status.warn,
      'Not a git repository; could not check tracked files.',
    );
    return;
  }
  final tracked = const LineSplitter().convert('${git.stdout}');
  final leaked = tracked
      .where(
        (f) =>
            f.endsWith('key.properties') ||
            f.endsWith('.jks') ||
            f.endsWith('.keystore') ||
            f.endsWith('.p12') ||
            f.endsWith('.pem') ||
            f.endsWith('google-services.json.secret') ||
            RegExp(r'(^|/)\.env(\.|$)').hasMatch(f) ||
            f.endsWith('.local.json') ||
            f == 'config/prod.json',
      )
      .toList();
  _add(
    area,
    'Keystore / key.properties not in git',
    leaked.isEmpty ? Status.pass : Status.fail,
    leaked.isEmpty
        ? 'No signing secrets are tracked.'
        : 'Tracked secret files: ${leaked.join(', ')}',
    leaked.isEmpty
        ? null
        : 'git rm --cached <file>, add to .gitignore, and ROTATE the key/passwords (history keeps them).',
  );
  final notIgnored = [
    for (final path in ['android/key.properties', 'android/upload.jks'])
      if (Process.runSync('git', [
            'check-ignore',
            '-q',
            path,
          ], workingDirectory: _root).exitCode !=
          0)
        path,
  ];
  if (notIgnored.isNotEmpty) {
    _add(
      area,
      '.gitignore',
      Status.warn,
      'Not git-ignored: ${notIgnored.join(', ')} (a keystore placed there would be committed by `git add .`).',
      'Run `dart run tool/flutter_store_ready/harden_platforms.dart`.',
    );
  }
}

// ------------------------------------------------------------------ manual

void _manualChecks(String manifest) {
  const area = 'Play Console (manual)';
  void m(String title, String detail) =>
      _add(area, title, Status.manual, detail);
  m(
    'Play App Signing',
    'Enrolled (default for new apps). Upload key ≠ app signing key; keep the upload key backed up.',
  );
  m(
    'Privacy policy',
    'Public HTTPS URL in Store listing and inside the app (Settings/About).',
  );
  m(
    'Data safety form',
    'Declare every data type collected by you AND SDKs (e.g. Sentry crash data, device ids).',
  );
  m(
    'Account deletion',
    'If users can create accounts: in-app deletion path + public web deletion URL in the Data safety form.',
  );
  m(
    'Content rating & target audience',
    'Complete the questionnaire; children in audience triggers the Families policy.',
  );
  m('Ads declaration', 'Declare whether the app contains ads.');
  m(
    'Closed testing (new personal accounts)',
    'Personal accounts created after 13 Nov 2023: closed test with >= 12 testers opted in for 14 continuous days before production access.',
  );
  m(
    'Store listing assets',
    '512x512 icon, 1024x500 feature graphic, >= 2 phone screenshots (+ 7"/10" tablet screenshots for tablet visibility).',
  );
  m(
    'Pre-launch report',
    'Upload to internal testing first; fix crashes/accessibility/security issues it reports.',
  );
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
      : '✅ READY (complete the MANUAL items in Play Console).';

  final b = StringBuffer()
    ..writeln('# Google Play readiness report')
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
    ..writeln();
  String? currentArea;
  final ordered = [..._checks]
    ..sort((a, b) => _areaOrder(a).compareTo(_areaOrder(b)));
  for (final c in ordered) {
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

  print('\nGoogle Play readiness: $verdict');
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

int _areaOrder(Check c) => const [
  'Signing',
  'App identity',
  'SDK levels',
  'Manifest & security',
  'Permissions & policy',
  '16 KB page size',
  'Release bundle',
  'Secrets',
  'Play Console (manual)',
].indexOf(c.area);

// ------------------------------------------------------------------- utils

/// Absolute paths (POSIX and Windows drive paths) are used as they are;
/// everything else is relative to the project root.
String _abs(String path) => File(path).isAbsolute ? path : '$_root/$path';

String? _read(String rel) {
  final f = File('$_root/$rel');
  return f.existsSync() ? f.readAsStringSync() : null;
}

String _readGradle() =>
    _read('android/app/build.gradle.kts') ??
    _read('android/app/build.gradle') ??
    '';

Map<String, String>? _readProperties(String rel) {
  final text = _read(rel);
  if (text == null) return null;
  final map = <String, String>{};
  for (final line in const LineSplitter().convert(text)) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#') || !t.contains('=')) continue;
    final i = t.indexOf('=');
    map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
  }
  return map;
}

Map<String, int> _flutterGradleDefaults() {
  final flutterBin = _whichSync('flutter');
  final roots = [
    Platform.environment['FLUTTER_ROOT'],
    if (flutterBin != null)
      File(
        flutterBin,
      ).resolveSymbolicLinksSync().replaceAll(RegExp(r'/bin/flutter$'), ''),
  ].whereType<String>();
  for (final root in roots) {
    final f = File(
      '$root/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt',
    );
    if (!f.existsSync()) continue;
    final text = f.readAsStringSync();
    return {
      for (final m in RegExp(
        r'val (\w+SdkVersion): Int = (\d+)',
      ).allMatches(text))
        m.group(1)!: int.parse(m.group(2)!),
    };
  }
  return const {};
}

bool _versionAtLeast(String version, List<int> min) {
  final parts = version.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < min.length; i++) {
    final v = i < parts.length ? parts[i] : 0;
    if (v != min[i]) return v > min[i];
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

Future<String?> _which(String cmd) async => _whichSync(cmd);

String? _whichSync(String cmd) {
  if (cmd == 'keytool') {
    final exe = Platform.isWindows ? 'keytool.exe' : 'keytool';
    final candidates = [
      if (Platform.environment['JAVA_HOME'] case final home?) '$home/bin/$exe',
      // Android Studio's bundled JDK.
      if (Platform.isWindows) ...[
        r'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
        '${Platform.environment['LOCALAPPDATA']}\\Programs\\Android Studio\\jbr\\bin\\keytool.exe',
      ],
      if (Platform.isMacOS)
        '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool',
      if (Platform.isLinux) '/opt/android-studio/jbr/bin/keytool',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
  }
  try {
    final r = Process.runSync(Platform.isWindows ? 'where' : 'which', [cmd]);
    if (r.exitCode != 0) return null;
    final path = '${r.stdout}'.trim().split(RegExp(r'\r?\n')).first.trim();
    return path.isEmpty ? null : path;
  } on ProcessException {
    return null;
  }
}

String _rel(String path) => path.toLowerCase().startsWith(_root.toLowerCase())
    ? path.substring(_root.length + 1).replaceAll(r'\', '/')
    : path;
