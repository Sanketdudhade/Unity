import 'package:flutter/material.dart';

/// Screen categorization according to UNITY Manufacturing Logical-Pixel Breakpoints.
///
/// | Device Type     | Breakpoint Range       |
/// |-----------------|------------------------|
/// | Small Mobile    | Below 360 px           |
/// | Standard Mobile | 360 – 599 px           |
/// | Tablet          | 600 – 899 px           |
/// | Small Desktop   | 900 – 1199 px          |
/// | Desktop         | 1200 – 1599 px         |
/// | Large Desktop   | 1600 px and above      |
enum DeviceScreenType {
  smallMobile,
  standardMobile,
  tablet,
  smallDesktop,
  desktop,
  largeDesktop,
}

/// Centralized Responsive Breakpoint definitions and helper checks.
class ResponsiveBreakpoints {
  // Breakpoint limits in logical pixels
  static const double smallMobileMax = 360.0;
  static const double mobileMax = 600.0;
  static const double tabletMax = 900.0;
  static const double smallDesktopMax = 1200.0;
  static const double desktopMax = 1600.0;

  // Maximum content width constraints for ultra-wide monitors
  static const double maxContentWidth = 1600.0;
  static const double standardContentWidth = 1200.0;

  /// Returns the [DeviceScreenType] corresponding to the given [width].
  static DeviceScreenType fromWidth(double width) {
    if (width < smallMobileMax) {
      return DeviceScreenType.smallMobile;
    } else if (width < mobileMax) {
      return DeviceScreenType.standardMobile;
    } else if (width < tabletMax) {
      return DeviceScreenType.tablet;
    } else if (width < smallDesktopMax) {
      return DeviceScreenType.smallDesktop;
    } else if (width < desktopMax) {
      return DeviceScreenType.desktop;
    } else {
      return DeviceScreenType.largeDesktop;
    }
  }

  /// Returns the [DeviceScreenType] from the current [BuildContext].
  static DeviceScreenType getDeviceType(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  /// Whether a given [width] is less than 360 px (Small Mobile).
  static bool isSmallMobileWidth(double width) => width < smallMobileMax;

  /// Whether a given [width] is below 600 px (Any mobile phone).
  static bool isMobileWidth(double width) => width < mobileMax;

  /// Whether a given [width] is between 600 px and 899 px (Tablet).
  static bool isTabletWidth(double width) => width >= mobileMax && width < tabletMax;

  /// Whether a given [width] is between 900 px and 1199 px (Small Desktop).
  static bool isSmallDesktopWidth(double width) => width >= tabletMax && width < smallDesktopMax;

  /// Whether a given [width] is between 1200 px and 1599 px (Desktop).
  static bool isDesktopWidth(double width) => width >= smallDesktopMax && width < desktopMax;

  /// Whether a given [width] is 1600 px and above (Large Desktop).
  static bool isLargeDesktopWidth(double width) => width >= desktopMax;

  /// Whether the screen width is less than 360 px (Small Mobile).
  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < smallMobileMax;

  /// Whether the screen width is between 360 px and 599 px (Standard Mobile).
  static bool isStandardMobile(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= smallMobileMax && width < mobileMax;
  }

  /// Whether the screen width is below 600 px (Any mobile phone: Small or Standard).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  /// Whether the screen width is between 600 px and 899 px (Tablet).
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMax && width < tabletMax;
  }

  /// Whether the screen width is between 900 px and 1199 px (Small Desktop / Laptop).
  static bool isSmallDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletMax && width < smallDesktopMax;
  }

  /// Whether the screen width is between 1200 px and 1599 px (Standard Desktop).
  static bool isStandardDesktop(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= smallDesktopMax && width < desktopMax;
  }

  /// Whether the screen width is 900 px or greater (Any desktop/laptop).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  /// Whether the screen width is 1200 px or greater (Full-sized desktop).
  static bool isFullDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= smallDesktopMax;

  /// Whether the screen width is 1600 px or above (Large Desktop / Ultrawide).
  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMax;

  /// Shortcut for screen width.
  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Shortcut for screen height.
  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Shortcut for screen orientation.
  static Orientation orientation(BuildContext context) =>
      MediaQuery.orientationOf(context);

  /// Resolves an adaptive value directly from a given [width].
  static T valueFromWidth<T>({
    required double width,
    T? smallMobile,
    required T mobile,
    T? tablet,
    T? smallDesktop,
    required T desktop,
    T? largeDesktop,
  }) {
    if (width >= desktopMax) {
      return largeDesktop ?? desktop;
    } else if (width >= smallDesktopMax) {
      return desktop;
    } else if (width >= tabletMax) {
      return smallDesktop ?? desktop;
    } else if (width >= mobileMax) {
      return tablet ?? desktop;
    } else if (width < smallMobileMax && smallMobile != null) {
      return smallMobile;
    } else {
      return mobile;
    }
  }

  /// Resolves an adaptive value according to the current screen breakpoint.
  static T value<T>(
    BuildContext context, {
    T? smallMobile,
    required T mobile,
    T? tablet,
    T? smallDesktop,
    required T desktop,
    T? largeDesktop,
  }) {
    return valueFromWidth<T>(
      width: MediaQuery.sizeOf(context).width,
      smallMobile: smallMobile,
      mobile: mobile,
      tablet: tablet,
      smallDesktop: smallDesktop,
      desktop: desktop,
      largeDesktop: largeDesktop,
    );
  }
}
