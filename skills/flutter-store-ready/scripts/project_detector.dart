// Detects mobile project type (Flutter, Expo, React Native, Native Android,
// Native iOS) and normalizes paths, versions, permissions and SDK capabilities
// across ecosystems so store-readiness scripts run automatically on any
// mobile project.
//
// Only dart:convert and dart:io: runs without `pub get`.

import 'dart:convert';
import 'dart:io';

import 'dart_scanner.dart';

enum ProjectKind {
  flutter('Flutter'),
  expo('Expo'),
  reactNative('React Native'),
  nativeAndroid('Native Android'),
  nativeIos('Native iOS'),
  unknown('Unknown');

  const ProjectKind(this.label);
  final String label;
}

final class ProjectProfile {
  ProjectProfile._({
    required this.root,
    required this.kind,
    required this.name,
    required this.pubspec,
    required this.packageJson,
    required this.expoConfig,
    required this.gradleText,
    required this.podfileText,
    required this.androidRoot,
    required this.androidAppDir,
    required this.iosRoot,
    required this.iosAppDir,
    required this.infoPlistPath,
    required this.pbxprojPath,
  });

  final String root;
  final ProjectKind kind;
  final String name;
  final String pubspec;
  final Map<String, Object?> packageJson;
  final Map<String, Object?> expoConfig;
  final String gradleText;
  final String podfileText;

  /// Relative path to Android root (`android` for cross-platform, `.` for
  /// native Android), or `null` when no Android setup exists.
  final String? androidRoot;

  /// Relative path to the Android application module (`android/app` or `app`).
  final String? androidAppDir;

  /// Relative path to iOS root (`ios` or `.`), or `null`.
  final String? iosRoot;

  /// Relative path to the iOS app target directory (`ios/Runner`,
  /// `ios/MyApp`, `MyApp`), or `null`.
  final String? iosAppDir;

  /// Relative path to `Info.plist`, or `null`.
  final String? infoPlistPath;

  /// Relative path to `project.pbxproj`, or `null`.
  final String? pbxprojPath;

  bool get isFlutter => kind == ProjectKind.flutter;
  bool get isExpo => kind == ProjectKind.expo;
  bool get hasAndroid => androidAppDir != null || expoAndroid != null;
  bool get hasIos =>
      (infoPlistPath != null && pbxprojPath != null) || expoIos != null;

  Map<String, Object?>? get expoAndroid {
    final a = expoConfig['android'];
    return a is Map ? a.cast<String, Object?>() : null;
  }

  Map<String, Object?>? get expoIos {
    final i = expoConfig['ios'];
    return i is Map ? i.cast<String, Object?>() : null;
  }

  static ProjectProfile detect(String rootPath) {
    final root = Directory(rootPath).resolveSymbolicLinksSync();
    final hasPubspec = File('$root/pubspec.yaml').existsSync();
    final pubspec = hasPubspec ? combinedWorkspacePubspec(root) : '';

    final pkgJson = _readJsonMap('$root/package.json');
    final allNpmDeps = <String, Object?>{
      ..._asMap(pkgJson['dependencies']),
      ..._asMap(pkgJson['devDependencies']),
    };

    final appJson = _readJsonMap('$root/app.json');
    final expoObj = appJson['expo'] is Map
        ? _asMap(appJson['expo'])
        : (allNpmDeps.containsKey('expo')
              ? appJson
              : const <String, Object?>{});

    // Resolve Android layout (`android/app` vs root `app`).
    String? androidRoot;
    String? androidAppDir;
    if (Directory('$root/android/app').existsSync() ||
        Directory('$root/android').existsSync()) {
      androidRoot = 'android';
      if (Directory('$root/android/app').existsSync()) {
        androidAppDir = 'android/app';
      }
    } else if (_fileExists(root, 'app/build.gradle.kts') ||
        _fileExists(root, 'app/build.gradle')) {
      androidRoot = '.';
      androidAppDir = 'app';
    }

    // Resolve iOS layout (`ios/Runner` vs `ios/<App>` vs `<App>`).
    final (iosRoot, iosAppDir, plistRel, pbxRel) = _resolveIosLayout(root);

    final ProjectKind kind;
    if (hasPubspec &&
        RegExp(r'^\s*flutter\s*:', multiLine: true).hasMatch(pubspec)) {
      kind = ProjectKind.flutter;
    } else if (allNpmDeps.containsKey('expo') || expoObj.isNotEmpty) {
      kind = ProjectKind.expo;
    } else if (allNpmDeps.containsKey('react-native')) {
      kind = ProjectKind.reactNative;
    } else if (androidAppDir != null) {
      kind = ProjectKind.nativeAndroid;
    } else if (pbxRel != null) {
      kind = ProjectKind.nativeIos;
    } else if (hasPubspec) {
      kind = ProjectKind.flutter;
    } else {
      kind = ProjectKind.unknown;
    }

    final gradleBuf = StringBuffer();
    for (final rel in [
      if (androidAppDir != null) ...[
        '$androidAppDir/build.gradle.kts',
        '$androidAppDir/build.gradle',
      ],
      if (androidRoot != null) ...[
        '${_join(androidRoot, 'gradle/libs.versions.toml')}',
      ],
    ]) {
      final f = File('$root/$rel');
      if (f.existsSync()) gradleBuf.writeln(f.readAsStringSync());
    }

    final podBuf = StringBuffer();
    for (final rel in [
      if (iosRoot != null) _join(iosRoot, 'Podfile'),
      if (pbxRel != null) pbxRel,
    ]) {
      final f = File('$root/$rel');
      if (f.existsSync()) podBuf.writeln(f.readAsStringSync());
    }

    final rootPubspecText = hasPubspec
        ? File('$root/pubspec.yaml').readAsStringSync()
        : '';
    final name =
        RegExp(
          r'^name:\s*(\S+)',
          multiLine: true,
        ).firstMatch(rootPubspecText)?.group(1) ??
        _asString(expoObj['slug']) ??
        _asString(expoObj['name']) ??
        _asString(pkgJson['name']) ??
        root.split(RegExp(r'[\\/]')).last;

    return ProjectProfile._(
      root: root,
      kind: kind,
      name: name,
      pubspec: pubspec,
      packageJson: pkgJson,
      expoConfig: expoObj,
      gradleText: gradleBuf.toString(),
      podfileText: podBuf.toString(),
      androidRoot: androidRoot,
      androidAppDir: androidAppDir,
      iosRoot: iosRoot,
      iosAppDir: iosAppDir,
      infoPlistPath: plistRel,
      pbxprojPath: pbxRel,
    );
  }

  static (String?, String?, String?, String?) _resolveIosLayout(String root) {
    // 1. Standard Flutter layout (`ios/Runner`)
    if (_fileExists(root, 'ios/Runner/Info.plist') &&
        _fileExists(root, 'ios/Runner.xcodeproj/project.pbxproj')) {
      return (
        'ios',
        'ios/Runner',
        'ios/Runner/Info.plist',
        'ios/Runner.xcodeproj/project.pbxproj',
      );
    }
    // 2. React Native / custom iOS subfolder (`ios/<App>.xcodeproj`)
    for (final base in ['ios', '.']) {
      final dir = Directory(base == '.' ? root : '$root/$base');
      if (!dir.existsSync()) continue;
      final xcodeprojs = dir
          .listSync()
          .whereType<Directory>()
          .where(
            (d) =>
                d.path.endsWith('.xcodeproj') &&
                !d.path.contains('Pods.xcodeproj'),
          )
          .toList();
      if (xcodeprojs.isEmpty) continue;
      final projDir = xcodeprojs.first;
      final projFile = '${projDir.path}/project.pbxproj';
      if (!File(projFile).existsSync()) continue;
      final projName = projDir.path
          .split(RegExp(r'[\\/]'))
          .last
          .replaceAll('.xcodeproj', '');
      final pbxRel = _relPath(root, projFile);

      // Candidate Info.plist locations: `<base>/<projName>/Info.plist` or any
      // non-Pods, non-Tests Info.plist inside `<base>/`.
      final directPlist = _join(base, '$projName/Info.plist');
      if (_fileExists(root, directPlist)) {
        return (base, _join(base, projName), directPlist, pbxRel);
      }
      final foundPlist = dir.listSync(recursive: true).whereType<File>().where((
        f,
      ) {
        final r = _relPath(root, f.path);
        return r.endsWith('/Info.plist') &&
            !r.contains('/Pods/') &&
            !r.contains('/build/') &&
            !r.contains('Tests/') &&
            !r.contains('.xcframework/');
      }).firstOrNull;
      if (foundPlist != null) {
        final plistRel = _relPath(root, foundPlist.path);
        final appDir = plistRel.substring(0, plistRel.lastIndexOf('/'));
        return (base, appDir, plistRel, pbxRel);
      }
      return (base, base, null, pbxRel);
    }
    if (Directory('$root/ios').existsSync()) {
      return ('ios', 'ios/Runner', null, null);
    }
    return (null, null, null, null);
  }

  /// Cross-ecosystem dependency/SDK table mapped by canonical capability ID.
  static const Map<String, List<String>> _ecosystemPackages = {
    'google_mobile_ads': [
      'google_mobile_ads',
      'react-native-google-mobile-ads',
      'expo-ads-admob',
      'play-services-ads',
      'Google-Mobile-Ads-SDK',
    ],
    'applovin_max': [
      'applovin_max',
      'react-native-applovin-max',
      'AppLovinSDK',
    ],
    'unity_ads_plugin': ['unity_ads_plugin', 'react-native-unity-ads'],
    'facebook_audience_network': [
      'facebook_audience_network',
      'react-native-fbads',
      'FBAudienceNetwork',
    ],
    'facebook_app_events': [
      'facebook_app_events',
      'react-native-fbsdk-next',
      'FBSDKCoreKit',
    ],
    'appsflyer_sdk': [
      'appsflyer_sdk',
      'react-native-appsflyer',
      'AppsFlyerFramework',
    ],
    'adjust_sdk': ['adjust_sdk', 'react-native-adjust', 'Adjust'],
    'branch_flutter_sdk': [
      'branch_flutter_sdk',
      'react-native-branch',
      'expo-branch',
    ],
    'firebase_core': [
      'firebase_core',
      '@react-native-firebase/app',
      'firebase-common',
      'FirebaseCore',
    ],
    'firebase_analytics': [
      'firebase_analytics',
      '@react-native-firebase/analytics',
      'expo-firebase-analytics',
      'firebase-analytics',
      'FirebaseAnalytics',
    ],
    'firebase_crashlytics': [
      'firebase_crashlytics',
      '@react-native-firebase/crashlytics',
      'firebase-crashlytics',
      'FirebaseCrashlytics',
    ],
    'sentry_flutter': [
      'sentry_flutter',
      '@sentry/react-native',
      'sentry-expo',
      'sentry-android',
      'Sentry',
    ],
    'firebase_messaging': [
      'firebase_messaging',
      '@react-native-firebase/messaging',
      'expo-notifications',
      'firebase-messaging',
      'FirebaseMessaging',
    ],
    'onesignal_flutter': [
      'onesignal_flutter',
      'react-native-onesignal',
      'onesignal-expo-plugin',
      'OneSignal',
    ],
    'firebase_auth': [
      'firebase_auth',
      '@react-native-firebase/auth',
      'firebase-auth',
      'FirebaseAuth',
    ],
    'google_sign_in': [
      'google_sign_in',
      '@react-native-google-signin/google-signin',
      'expo-auth-session',
      'play-services-auth',
      'GoogleSignIn',
    ],
    'flutter_facebook_auth': [
      'flutter_facebook_auth',
      'flutter_login_facebook',
      'react-native-fbsdk-next',
      'FBSDKLoginKit',
    ],
    'sign_in_with_apple': [
      'sign_in_with_apple',
      'expo-apple-authentication',
      '@invertase/react-native-apple-authentication',
    ],
    'google_maps_flutter': [
      'google_maps_flutter',
      'react-native-maps',
      'play-services-maps',
      'GoogleMaps',
    ],
    'in_app_purchase': [
      'in_app_purchase',
      'flutter_inapp_purchase',
      'react-native-iap',
      'expo-in-app-purchases',
      'com.android.billingclient:billing',
    ],
    'purchases_flutter': [
      'purchases_flutter',
      'react-native-purchases',
      'purchases-ios',
      'RevenueCat',
    ],
    'flutter_stripe': [
      'flutter_stripe',
      'stripe_payment',
      '@stripe/stripe-react-native',
      'stripe-android',
      'StripePaymentSheet',
    ],
    'razorpay_flutter': ['razorpay_flutter', 'react-native-razorpay'],
    'flutter_paypal': ['flutter_paypal', 'react-native-paypal'],
    'iyzico': ['iyzico'],
    'camera': [
      'camera',
      'expo-camera',
      'react-native-vision-camera',
      'react-native-camera',
    ],
    'mobile_scanner': [
      'mobile_scanner',
      'qr_code_scanner',
      'expo-barcode-scanner',
    ],
    'image_picker': [
      'image_picker',
      'expo-image-picker',
      'react-native-image-picker',
    ],
    'geolocator': [
      'geolocator',
      'location',
      'expo-location',
      'react-native-geolocation-service',
      '@react-native-community/geolocation',
    ],
    'record': [
      'record',
      'flutter_sound',
      'expo-av',
      'expo-audio',
      'react-native-audio-recorder-player',
    ],
    'local_auth': [
      'local_auth',
      'expo-local-authentication',
      'react-native-biometrics',
    ],
    'flutter_contacts': [
      'flutter_contacts',
      'contacts_service',
      'expo-contacts',
      'react-native-contacts',
    ],
    'flutter_blue_plus': [
      'flutter_blue_plus',
      'flutter_reactive_ble',
      'react-native-ble-plx',
    ],
    'app_tracking_transparency': [
      'app_tracking_transparency',
      'expo-tracking-transparency',
      'react-native-tracking-transparency',
    ],
    'health': ['health', 'react-native-health', 'react-native-health-connect'],
    'nfc_manager': ['nfc_manager', 'react-native-nfc-manager'],
  };

  /// Returns the actual installed package name matching [canonicalOrExact], or
  /// `null` when absent. Preserves exact Flutter package names for Flutter
  /// projects so report wording stays identical.
  String? matchedPackage(String canonicalOrExact) {
    final candidates =
        _ecosystemPackages[canonicalOrExact] ?? [canonicalOrExact];
    final npmDeps = <String, Object?>{
      ..._asMap(packageJson['dependencies']),
      ..._asMap(packageJson['devDependencies']),
    };
    for (final c in candidates) {
      final esc = RegExp.escape(c);
      // A Flutter project declares every plugin in pubspec.yaml; its Gradle
      // and Podfile text only mirror them (and contain words such as
      // `IllegalArgumentException`, which hides "gal").
      if (pubspec.isNotEmpty) {
        if (RegExp('^\\s+$esc:', multiLine: true).hasMatch(pubspec)) return c;
        continue;
      }
      if (npmDeps.containsKey(c)) return c;
      // Gradle: only a dependency coordinate — "group:artifact[:version]".
      if (gradleText.isNotEmpty &&
          RegExp('''["'][\\w.\\-]+:$esc(?:["':])''').hasMatch(gradleText)) {
        return c;
      }
      // CocoaPods: `pod 'Name'` in the Podfile or `- Name (` in Podfile.lock.
      if (podfileText.isNotEmpty &&
          RegExp(
            '''(?:\\bpod\\s+["']$esc(?:/[^"']*)?["'])|(?:^\\s*-\\s+"?$esc(?:/\\S*?)?"?\\s+\\()''',
            multiLine: true,
          ).hasMatch(podfileText)) {
        return c;
      }
    }
    return null;
  }

  bool hasPackage(String canonicalOrExact) =>
      matchedPackage(canonicalOrExact) != null;

  List<String> matchedPackages(Iterable<String> canonicalNames) {
    final found = <String>{};
    for (final name in canonicalNames) {
      final m = matchedPackage(name);
      if (m != null) found.add(m);
    }
    return found.toList();
  }

  /// True when [relDir] exists on disk and is ignored by git (typical for
  /// `android/` and `ios/` generated by `expo prebuild`).
  bool isGitIgnored(String relDir) {
    if (!Directory('$root/$relDir').existsSync()) return false;
    try {
      final r = Process.runSync('git', [
        'check-ignore',
        '-q',
        relDir,
      ], workingDirectory: root);
      return r.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  static bool _fileExists(String root, String rel) =>
      File('$root/$rel').existsSync();

  static String _join(String base, String child) =>
      base == '.' ? child : '$base/$child';

  static String _relPath(String root, String fullPath) =>
      fullPath.substring(root.length + 1).replaceAll(r'\', '/');

  static Map<String, Object?> _readJsonMap(String path) {
    final f = File(path);
    if (!f.existsSync()) return const {};
    try {
      final decoded = jsonDecode(f.readAsStringSync());
      return decoded is Map ? decoded.cast<String, Object?>() : const {};
    } on Object {
      return const {};
    }
  }

  static Map<String, Object?> _asMap(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};

  static String? _asString(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;
}
