import 'package:flutter/widgets.dart';

abstract final class Breakpoints {
  /// Below this the poster grid drops to two columns.
  static const smallPhone = 340.0;

  /// From here up, pages use roomier tablet layouts.
  static const tablet = 700.0;

  /// From here up, navigation moves from the bottom bar to a side rail.
  static const rail = 840.0;

  /// Side rail plus its divider.
  static const railWidth = 101.0;
}

/// Screen-size helpers. Everything is derived from [MediaQuery], so the whole
/// UI follows the device: small phones, tablets, split-screen and desktop.
extension Responsive on BuildContext {
  Size get screen => MediaQuery.sizeOf(this);

  /// Wide enough for the side navigation rail.
  bool get hasRail => screen.width >= Breakpoints.rail;

  /// Width left for a tab's page once the side rail is taken out.
  double get pageWidth => screen.width - (hasRail ? Breakpoints.railWidth : 0);

  bool get isTablet => pageWidth >= Breakpoints.tablet;

  /// Design sizes are drawn for a 390pt-wide phone and scale gently with the
  /// screen, so small phones get tighter layouts and tablets roomier ones.
  double get scale => (screen.shortestSide / 390).clamp(0.85, 1.25);

  /// Scales a design dimension or font size to this screen.
  double rs(double value) => value * scale;

  /// Side padding for page content: 5% of the width, within sensible limits.
  double get gutter => (pageWidth * 0.05).clamp(16.0, 32.0);

  /// How much larger than normal the user's system font setting is.
  double get textScale => MediaQuery.textScalerOf(this).scale(14) / 14;
}
