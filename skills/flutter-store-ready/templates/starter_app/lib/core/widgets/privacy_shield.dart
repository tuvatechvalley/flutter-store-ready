import 'dart:ui';

import 'package:material_ui/material_ui.dart';

/// Hides app content when the app is not in the foreground, so the
/// recent-apps switcher does not show balances, messages or personal data.
///
/// On Android, also consider FLAG_SECURE (see tool/flutter_store_ready/harden_platforms.dart
/// `--secure-screens`) to block screenshots/screen recording entirely.
class PrivacyShield extends StatefulWidget {
  const PrivacyShield({required this.child, super.key, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield> {
  late final AppLifecycleListener _listener;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onStateChange: _onStateChange);
  }

  void _onStateChange(AppLifecycleState state) {
    final obscure = state != AppLifecycleState.resumed;
    if (obscure != _obscured && mounted) setState(() => _obscured = obscure);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      children: [
        widget.child,
        if (_obscured)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: const Center(child: Icon(Icons.lock_outline, size: 48)),
              ),
            ),
          ),
      ],
    );
  }
}
