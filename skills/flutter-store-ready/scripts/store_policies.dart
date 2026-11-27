// Loads annual store policy constants from store_policies.json next to the
// scripts, with built-in fallbacks when a standalone script copy runs without
// the JSON file.
//
// Only dart:convert and dart:io: runs without `pub get`.

import 'dart:convert';
import 'dart:io';

final class GooglePlayPolicies {
  const GooglePlayPolicies({
    required this.requiredTargetSdk,
    required this.requiredTargetSdkAndroidName,
    required this.requiredTargetSdkSince,
    required this.recommendedMinSdk,
    required this.minSupportedSdk,
    required this.minAgpFor16Kb,
    required this.minNdkFor16Kb,
    required this.minKeyValidityYears,
    required this.closedTestingSince,
    required this.closedTestingMinTesters,
    required this.closedTestingMinDays,
    required this.defaultIconMd5,
  });

  final int requiredTargetSdk;
  final String requiredTargetSdkAndroidName;
  final String requiredTargetSdkSince;
  final int recommendedMinSdk;
  final int minSupportedSdk;
  final List<int> minAgpFor16Kb;
  final int minNdkFor16Kb;
  final int minKeyValidityYears;
  final String closedTestingSince;
  final int closedTestingMinTesters;
  final int closedTestingMinDays;
  final Set<String> defaultIconMd5;

  static const fallback = GooglePlayPolicies(
    requiredTargetSdk: 36,
    requiredTargetSdkAndroidName: 'Android 16',
    requiredTargetSdkSince: '2026-08-31',
    recommendedMinSdk: 24,
    minSupportedSdk: 21,
    minAgpFor16Kb: [8, 5, 1],
    minNdkFor16Kb: 28,
    minKeyValidityYears: 25,
    closedTestingSince: '13 Nov 2023',
    closedTestingMinTesters: 12,
    closedTestingMinDays: 14,
    defaultIconMd5: {'57838d52c318faff743130c3fcfae0c6'},
  );
}

final class AppStorePolicies {
  const AppStorePolicies({
    required this.minDeploymentTarget,
    required this.minDeploymentTargetSince,
    required this.requiredXcode,
    required this.requiredXcodeSince,
    required this.nextDeploymentTarget,
    required this.nextDeadline,
    required this.nextRequirement,
    required this.defaultIconMd5,
  });

  final String minDeploymentTarget;
  final String minDeploymentTargetSince;
  final String requiredXcode;
  final String requiredXcodeSince;
  final String nextDeploymentTarget;
  final String nextDeadline;
  final String nextRequirement;
  final Set<String> defaultIconMd5;

  static const fallback = AppStorePolicies(
    minDeploymentTarget: '13.0',
    minDeploymentTargetSince: '2026-09-09',
    requiredXcode: 'Xcode 26 / iOS 26 SDK',
    requiredXcodeSince: '2026-04-28',
    nextDeploymentTarget: '15.0',
    nextDeadline: 'April 2027',
    nextRequirement:
        'From April 2027: built with the iOS 27 SDK, targeting iOS 15 or later',
    defaultIconMd5: {'c785f8932297af4acd5f5ccb7630f01c'},
  );
}

final class FlutterPolicies {
  const FlutterPolicies({required this.materialUiStandaloneSince});

  final List<int> materialUiStandaloneSince;

  static const fallback = FlutterPolicies(materialUiStandaloneSince: [3, 47]);
}

final class StorePolicies {
  const StorePolicies({
    required this.checkedDate,
    required this.googlePlay,
    required this.appStore,
    required this.flutter,
  });

  final String checkedDate;
  final GooglePlayPolicies googlePlay;
  final AppStorePolicies appStore;
  final FlutterPolicies flutter;

  static const fallback = StorePolicies(
    checkedDate: '2026-11-27',
    googlePlay: GooglePlayPolicies.fallback,
    appStore: AppStorePolicies.fallback,
    flutter: FlutterPolicies.fallback,
  );

  static StorePolicies load([String? scriptsDir]) {
    final dir = scriptsDir ?? File.fromUri(Platform.script).parent.path;
    final file = File('$dir/store_policies.json');
    if (!file.existsSync()) return fallback;
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) return fallback;
      final root = raw.cast<String, Object?>();
      final play = _map(root['googlePlay']);
      final ios = _map(root['appStore']);
      final fl = _map(root['flutter']);
      const pf = GooglePlayPolicies.fallback;
      const af = AppStorePolicies.fallback;
      const ff = FlutterPolicies.fallback;
      return StorePolicies(
        checkedDate: _str(root['checkedDate'], fallback.checkedDate),
        googlePlay: GooglePlayPolicies(
          requiredTargetSdk: _int(
            play['requiredTargetSdk'],
            pf.requiredTargetSdk,
          ),
          requiredTargetSdkAndroidName: _str(
            play['requiredTargetSdkAndroidName'],
            pf.requiredTargetSdkAndroidName,
          ),
          requiredTargetSdkSince: _str(
            play['requiredTargetSdkSince'],
            pf.requiredTargetSdkSince,
          ),
          recommendedMinSdk: _int(
            play['recommendedMinSdk'],
            pf.recommendedMinSdk,
          ),
          minSupportedSdk: _int(play['minSupportedSdk'], pf.minSupportedSdk),
          minAgpFor16Kb: _intList(play['minAgpFor16Kb'], pf.minAgpFor16Kb),
          minNdkFor16Kb: _int(play['minNdkFor16Kb'], pf.minNdkFor16Kb),
          minKeyValidityYears: _int(
            play['minKeyValidityYears'],
            pf.minKeyValidityYears,
          ),
          closedTestingSince: _str(
            play['closedTestingSince'],
            pf.closedTestingSince,
          ),
          closedTestingMinTesters: _int(
            play['closedTestingMinTesters'],
            pf.closedTestingMinTesters,
          ),
          closedTestingMinDays: _int(
            play['closedTestingMinDays'],
            pf.closedTestingMinDays,
          ),
          defaultIconMd5: _strSet(play['defaultIconMd5'], pf.defaultIconMd5),
        ),
        appStore: AppStorePolicies(
          minDeploymentTarget: _str(
            ios['minDeploymentTarget'],
            af.minDeploymentTarget,
          ),
          minDeploymentTargetSince: _str(
            ios['minDeploymentTargetSince'],
            af.minDeploymentTargetSince,
          ),
          requiredXcode: _str(ios['requiredXcode'], af.requiredXcode),
          requiredXcodeSince: _str(
            ios['requiredXcodeSince'],
            af.requiredXcodeSince,
          ),
          nextDeploymentTarget: _str(
            ios['nextDeploymentTarget'],
            af.nextDeploymentTarget,
          ),
          nextDeadline: _str(ios['nextDeadline'], af.nextDeadline),
          nextRequirement: _str(ios['nextRequirement'], af.nextRequirement),
          defaultIconMd5: _strSet(ios['defaultIconMd5'], af.defaultIconMd5),
        ),
        flutter: FlutterPolicies(
          materialUiStandaloneSince: _intList(
            fl['materialUiStandaloneSince'],
            ff.materialUiStandaloneSince,
          ),
        ),
      );
    } on Object {
      return fallback;
    }
  }

  static Map<String, Object?> _map(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};

  static String _str(Object? v, String def) =>
      v is String && v.isNotEmpty ? v : def;

  static int _int(Object? v, int def) => v is int ? v : def;

  static List<int> _intList(Object? v, List<int> def) {
    if (v is! List) return def;
    final items = v.whereType<int>().toList();
    return items.isEmpty ? def : items;
  }

  static Set<String> _strSet(Object? v, Set<String> def) {
    if (v is! List) return def;
    final items = v.whereType<String>().where((s) => s.isNotEmpty).toSet();
    return items.isEmpty ? def : items;
  }
}
