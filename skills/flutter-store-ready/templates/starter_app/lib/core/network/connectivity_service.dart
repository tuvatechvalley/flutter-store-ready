import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device has *a* network interface.
///
/// This does not guarantee internet access (captive portals, dead Wi-Fi).
/// It is a UX hint only; the real source of truth is request failures.
abstract interface class ConnectivityService {
  Stream<bool> watchOnline();
}

final class PlusConnectivityService implements ConnectivityService {
  PlusConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> watchOnline() async* {
    yield _isOnline(await _connectivity.checkConnectivity());
    yield* _connectivity.onConnectivityChanged.map(_isOnline).distinct();
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}

/// Always online; used by tests and the mock backend.
final class AlwaysOnlineConnectivityService implements ConnectivityService {
  const AlwaysOnlineConnectivityService();

  @override
  Stream<bool> watchOnline() => Stream.value(true);
}
