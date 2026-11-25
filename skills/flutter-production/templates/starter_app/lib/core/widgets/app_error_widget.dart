import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Replaces Flutter's red (debug) / grey (release) error box when a widget
/// throws during build. Users see a calm placeholder instead of a blank
/// screen; the error itself is already reported by FlutterError.onError.
///
/// Must not depend on Theme/Localizations: it can be built anywhere, even
/// outside MaterialApp.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({required this.details, super.key});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0x14FF0000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              kDebugMode ? details.exceptionAsString() : '⚠',
              textAlign: TextAlign.center,
              maxLines: kDebugMode ? 8 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFB00020), fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
