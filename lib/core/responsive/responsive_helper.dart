import 'dart:math';
import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Helper utilities and BuildContext extensions for responsive layouts.
class ResponsiveHelper {
  /// Calculates optimal grid crossAxisCount directly from a [width].
  static int gridColumnsFromWidth(
    double width, {
    int smallMobile = 1,
    int mobile = 1,
    int tablet = 2,
    int smallDesktop = 3,
    int desktop = 4,
    int largeDesktop = 4,
  }) {
    return ResponsiveBreakpoints.valueFromWidth<int>(
      width: width,
      smallMobile: smallMobile,
      mobile: mobile,
      tablet: tablet,
      smallDesktop: smallDesktop,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }

  /// Calculates safe maximum dialog width directly from a [width].
  static double dialogMaxWidthFromWidth(
    double width, {
    double desktopMax = 640.0,
    double tabletMax = 560.0,
  }) {
    if (width < ResponsiveBreakpoints.mobileMax) {
      return max(280.0, width - 24.0);
    } else if (width < ResponsiveBreakpoints.tabletMax) {
      return min(tabletMax, width - 40.0);
    } else {
      return min(desktopMax, width - 64.0);
    }
  }

  /// Calculates optimal grid crossAxisCount based on screen breakpoint.
  static int gridColumns(
    BuildContext context, {
    int smallMobile = 1,
    int mobile = 1,
    int tablet = 2,
    int smallDesktop = 3,
    int desktop = 4,
    int largeDesktop = 4,
  }) {
    return ResponsiveBreakpoints.value<int>(
      context,
      smallMobile: smallMobile,
      mobile: mobile,
      tablet: tablet,
      smallDesktop: smallDesktop,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }

  /// Calculates safe maximum dialog width so dialogs never overflow mobile screens
  /// and don't stretch excessively across desktop displays.
  static double dialogMaxWidth(
    BuildContext context, {
    double desktopMax = 640.0,
    double tabletMax = 560.0,
  }) {
    final width = ResponsiveBreakpoints.screenWidth(context);
    if (width < ResponsiveBreakpoints.mobileMax) {
      return max(280.0, width - 24.0);
    } else if (width < ResponsiveBreakpoints.tabletMax) {
      return min(tabletMax, width - 40.0);
    } else {
      return min(desktopMax, width - 64.0);
    }
  }

  /// Calculates safe maximum dialog height to prevent vertical keyboard or viewport overflow.
  static double dialogMaxHeight(
    BuildContext context, {
    double ratio = 0.85,
    double absoluteMax = 800.0,
  }) {
    final height = ResponsiveBreakpoints.screenHeight(context);
    return min(absoluteMax, height * ratio);
  }

  /// Returns adaptive page padding based on screen size.
  static EdgeInsets pagePadding(BuildContext context) {
    return ResponsiveBreakpoints.value<EdgeInsets>(
      context,
      smallMobile: const EdgeInsets.all(8.0),
      mobile: const EdgeInsets.all(12.0),
      tablet: const EdgeInsets.all(16.0),
      smallDesktop: const EdgeInsets.all(20.0),
      desktop: const EdgeInsets.all(24.0),
      largeDesktop: const EdgeInsets.all(32.0),
    );
  }

  /// Returns true if the soft keyboard is currently open.
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom > 0;
  }
}

/// Extension on [BuildContext] for ergonomic responsive checks in build methods.
extension ResponsiveContext on BuildContext {
  /// Current screen width.
  double get screenWidth => ResponsiveBreakpoints.screenWidth(this);

  /// Current screen height.
  double get screenHeight => ResponsiveBreakpoints.screenHeight(this);

  /// Current device screen type.
  DeviceScreenType get deviceScreenType =>
      ResponsiveBreakpoints.getDeviceType(this);

  /// True if width < 360 px.
  bool get isSmallMobile => ResponsiveBreakpoints.isSmallMobile(this);

  /// True if 360 <= width < 600 px.
  bool get isStandardMobile => ResponsiveBreakpoints.isStandardMobile(this);

  /// True if width < 600 px (Any mobile phone).
  bool get isMobile => ResponsiveBreakpoints.isMobile(this);

  /// True if 600 <= width < 900 px (Tablet).
  bool get isTablet => ResponsiveBreakpoints.isTablet(this);

  /// True if 900 <= width < 1200 px (Small desktop / Laptop).
  bool get isSmallDesktop => ResponsiveBreakpoints.isSmallDesktop(this);

  /// True if width >= 900 px (Any desktop/laptop).
  bool get isDesktop => ResponsiveBreakpoints.isDesktop(this);

  /// True if width >= 1200 px (Full desktop).
  bool get isFullDesktop => ResponsiveBreakpoints.isFullDesktop(this);

  /// True if width >= 1600 px (Large desktop).
  bool get isLargeDesktop => ResponsiveBreakpoints.isLargeDesktop(this);

  /// True if soft keyboard is shown.
  bool get isKeyboardVisible => ResponsiveHelper.isKeyboardVisible(this);

  /// Responsive value selector on context.
  T responsiveValue<T>({
    T? smallMobile,
    required T mobile,
    T? tablet,
    T? smallDesktop,
    required T desktop,
    T? largeDesktop,
  }) {
    return ResponsiveBreakpoints.value<T>(
      this,
      smallMobile: smallMobile,
      mobile: mobile,
      tablet: tablet,
      smallDesktop: smallDesktop,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }
}
