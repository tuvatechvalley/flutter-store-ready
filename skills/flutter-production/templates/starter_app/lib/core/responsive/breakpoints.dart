import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'text_scaling.dart';

/// Material 3 window size classes, based on the *available width* (not the
/// device type): a tablet in split-screen is "compact", a phone in landscape
/// can be "medium".
///
/// The width is divided by the user's text scale, so large text gets the
/// layout that has room for it (2x text on a 1024dp tablet → phone layout).
enum WindowSize {
  compact, // < 600: phones portrait
  medium, // 600–839: large phones landscape, small tablets, foldables
  expanded; // >= 840: tablets, desktops

  static WindowSize fromWidth(double width) {
    if (width < 600) return WindowSize.compact;
    if (width < 840) return WindowSize.medium;
    return WindowSize.expanded;
  }

  static WindowSize of(BuildContext context) => fromWidth(
    MediaQuery.sizeOf(context).width /
        math.max(1, TextScaling.factorOf(context)),
  );

  bool get isCompact => this == WindowSize.compact;
}

abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal page padding grows with the window.
  static double page(WindowSize size) => switch (size) {
    WindowSize.compact => md,
    WindowSize.medium => lg,
    WindowSize.expanded => xl,
  };

  /// Readable line length: content never stretches across a 13" tablet.
  static const double maxContentWidth = 720;
  static const double maxFormWidth = 440;
}

/// Centers content and caps its width. Use for every page body.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    required this.child,
    super.key,
    this.maxWidth = Insets.maxContentWidth,
    this.padding = true,
  });

  final Widget child;
  final double maxWidth;
  final bool padding;

  @override
  Widget build(BuildContext context) {
    final horizontal = padding ? Insets.page(WindowSize.of(context)) : 0.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: child,
        ),
      ),
    );
  }
}
