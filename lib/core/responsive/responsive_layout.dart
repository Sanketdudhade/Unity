import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Reusable layout widget that renders different widgets based on active breakpoint.
class ResponsiveLayout extends StatelessWidget {
  /// Widget displayed on mobile devices (< 600 px).
  final Widget mobile;

  /// Optional widget displayed specifically on small mobile devices (< 360 px).
  final Widget? smallMobile;

  /// Optional widget displayed on tablet devices (600 – 899 px).
  final Widget? tablet;

  /// Optional widget displayed on small desktop devices (900 – 1199 px).
  final Widget? smallDesktop;

  /// Widget displayed on desktop devices (>= 1200 px or >= 900 px if smallDesktop omitted).
  final Widget desktop;

  /// Optional widget displayed on large desktop displays (>= 1600 px).
  final Widget? largeDesktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.smallMobile,
    this.tablet,
    this.smallDesktop,
    required this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= ResponsiveBreakpoints.desktopMax && largeDesktop != null) {
          return largeDesktop!;
        } else if (width >= ResponsiveBreakpoints.smallDesktopMax) {
          return desktop;
        } else if (width >= ResponsiveBreakpoints.tabletMax) {
          return smallDesktop ?? desktop;
        } else if (width >= ResponsiveBreakpoints.mobileMax) {
          return tablet ?? desktop;
        } else if (width < ResponsiveBreakpoints.smallMobileMax && smallMobile != null) {
          return smallMobile!;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// A container that centers its content on wide screens and constrains max width
/// while providing adaptive horizontal/vertical margins.
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
          horizontal: isDesk ? 24.0 : (isTab ? 16.0 : 12.0),
          vertical: isDesk ? 20.0 : 12.0,
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

/// Automatically switches between a [Row] and [Column] based on screen width.
class ResponsiveRowColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment columnMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final double spacing;
  final double runSpacing;
  final bool? forceColumn;

  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 12.0,
    this.runSpacing = 12.0,
    this.forceColumn,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final shouldColumn = forceColumn ?? isMobile;

    if (shouldColumn) {
      final spacedChildren = <Widget>[];
      for (int i = 0; i < children.length; i++) {
        spacedChildren.add(children[i]);
        if (i < children.length - 1 && spacing > 0) {
          spacedChildren.add(SizedBox(height: spacing));
        }
      }
      return Column(
        mainAxisAlignment: columnMainAxisAlignment,
        crossAxisAlignment: columnCrossAxisAlignment,
        children: spacedChildren,
      );
    } else {
      final spacedChildren = <Widget>[];
      for (int i = 0; i < children.length; i++) {
        spacedChildren.add(children[i]);
        if (i < children.length - 1 && spacing > 0) {
          spacedChildren.add(SizedBox(width: spacing));
        }
      }
      return Row(
        mainAxisAlignment: rowMainAxisAlignment,
        crossAxisAlignment: rowCrossAxisAlignment,
        children: spacedChildren,
      );
    }
  }
}
