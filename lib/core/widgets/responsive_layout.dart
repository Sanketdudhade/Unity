import 'package:flutter/material.dart';

/// Standard responsive breakpoints for handheld, tablet, and desktop/laptop devices.
class ResponsiveBreakpoints {
  static const double mobileMax = 650;
  static const double tabletMax = 1024;
  static const double maxContentWidth = 1240;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMax && width < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Returns responsive value based on active device breakpoint.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletMax) {
      return desktop;
    } else if (width >= mobileMax) {
      return tablet ?? desktop;
    } else {
      return mobile;
    }
  }
}

/// Centers content with a standard maximum desktop/laptop width constraint
/// and adaptive horizontal/vertical margins.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
    this.padding,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDesk = ResponsiveBreakpoints.isDesktop(context);
    final isTab = ResponsiveBreakpoints.isTablet(context);

    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: isDesk ? 32.0 : (isTab ? 24.0 : 16.0),
          vertical: isDesk ? 24.0 : 16.0,
        );

    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: content,
      );
    }

    return content;
  }
}
