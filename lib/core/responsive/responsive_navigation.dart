import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Navigation mode based on the current breakpoint and viewport constraint.
enum ResponsiveNavigationMode {
  /// Mobile Drawer (< 600 px).
  drawer,

  /// Compact Navigation Rail for tablets (600 – 899 px).
  rail,

  /// Collapsed Sidebar for small desktop screens (900 – 1199 px).
  collapsedSidebar,

  /// Standard Expanded Sidebar for desktop screens (>= 1200 px).
  sidebar,
}

/// Helper to resolve the correct navigation display mode according to breakpoints.
class ResponsiveNavigation {
  static ResponsiveNavigationMode getMode(BuildContext context) {
    final width = ResponsiveBreakpoints.screenWidth(context);
    if (width < ResponsiveBreakpoints.mobileMax) {
      return ResponsiveNavigationMode.drawer;
    } else if (width < ResponsiveBreakpoints.tabletMax) {
      return ResponsiveNavigationMode.rail;
    } else if (width < ResponsiveBreakpoints.smallDesktopMax) {
      return ResponsiveNavigationMode.collapsedSidebar;
    } else {
      return ResponsiveNavigationMode.sidebar;
    }
  }

  /// Whether current navigation should be a drawer.
  static bool isDrawer(BuildContext context) =>
      ResponsiveBreakpoints.isMobile(context);

  /// Whether navigation should be rail or collapsed sidebar.
  static bool isCompact(BuildContext context) {
    final width = ResponsiveBreakpoints.screenWidth(context);
    return width >= ResponsiveBreakpoints.mobileMax &&
        width < ResponsiveBreakpoints.smallDesktopMax;
  }
}
