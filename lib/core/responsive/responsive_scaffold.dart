import 'package:flutter/material.dart';
import 'responsive_breakpoints.dart';

/// Adaptive scaffold supporting mobile, tablet, and desktop layouts.
/// Provides unified SafeArea, keyboard inset management, and drawer/sidebar handling.
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? drawer;
  final Widget? sidebar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final double maxBodyWidth;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.drawer,
    this.sidebar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.maxBodyWidth = ResponsiveBreakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Mobile Layout: standard Scaffold with Drawer & optional BottomBar
    if (isMobile || sidebar == null) {
      return Scaffold(
        appBar: appBar,
        drawer: drawer,
        body: SafeArea(
          child: body,
        ),
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      );
    }

    // Tablet / Desktop Layout with Persistent Sidebar
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Row(
        children: [
          sidebar!,
          Expanded(
            child: Column(
              children: [
                ?appBar,
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxBodyWidth),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
