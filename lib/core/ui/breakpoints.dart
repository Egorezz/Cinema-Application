import 'package:flutter/widgets.dart';

/// Width thresholds of the adaptive layout.
abstract final class Breakpoints {
  /// Width >= [tabletMin] is a tablet layout.
  static const double tabletMin = 600;

  /// Width >= [desktopMin] is a desktop layout.
  static const double desktopMin = 1024;
}

enum ScreenSize {
  mobile,
  tablet,
  desktop;

  static ScreenSize fromWidth(double width) {
    if (width < Breakpoints.tabletMin) return ScreenSize.mobile;
    if (width < Breakpoints.desktopMin) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }
}

extension ScreenSizeX on BuildContext {
  ScreenSize get screenSize =>
      ScreenSize.fromWidth(MediaQuery.sizeOf(this).width);
}
