import 'package:flutter/widgets.dart';

/// Large-text rules for the whole app.
///
/// * Body text follows the user's system font size up to [maxScaleFactor]
///   (iOS "Larger Accessibility Sizes" reach ~3.1x, Android 14+ reaches 2x
///   with nonlinear scaling). On top of that the user can pick an in-app
///   text size in Settings.
/// * Navigation chrome (bottom bar, rail, app bar title) is capped at
///   [maxChromeScaleFactor], like iOS tab bars and Material's NavigationBar:
///   labels stay readable via tooltips / long-press instead of breaking the
///   bar.
/// * Layout breakpoints use the *effective* width (width ÷ text scale), so a
///   tablet with 2x text gets the roomier phone layout instead of cramped
///   columns. See `WindowSize.of`.
abstract final class TextScaling {
  static const double maxScaleFactor = 3;
  static const double maxChromeScaleFactor = 1.3;

  /// In-app text size choices (multiplied with the system setting).
  static const List<double> appScaleOptions = [1, 1.15, 1.3, 1.5];

  /// Effective scale for 14sp body text. Works with nonlinear scalers,
  /// unlike the deprecated `textScaleFactor`.
  static double factorOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) / 14;

  /// System scaler × in-app factor, capped at [maxScaleFactor].
  static TextScaler combine(TextScaler system, double appFactor) =>
      MultipliedTextScaler(
        system,
        appFactor,
      ).clamp(maxScaleFactor: maxScaleFactor);
}

/// Multiplies another [TextScaler] without losing its nonlinear curve.
final class MultipliedTextScaler extends TextScaler {
  const MultipliedTextScaler(this.base, this.factor) : assert(factor > 0);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  @Deprecated('Use scale() instead.')
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is MultipliedTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);

  @override
  String toString() => '$base × $factor';
}
