import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/responsive/responsive.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'admin_sidebar.dart';
import 'admin_top_bar.dart';

/// Modern Enterprise Admin Shell wrapping all admin screens.
/// Conforms to Section A4 & Responsive Guidelines:
/// - Android Mobile (< 600 px): Scaffold with Drawer + TopBar.
/// - Tablet (600 - 899 px): Collapsed Rail + TopBar.
/// - Small Desktop (900 - 1199 px): Compact persistent sidebar with toggle.
/// - Desktop & Large Desktop (>= 1200 px): Persistent expanded sidebar with collapse toggle and max content width constraint.
class AdminShell extends ConsumerStatefulWidget {
  final String currentPath;
  final Widget child;

  const AdminShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _isCollapsed = false;

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;

    // Safety fallback: If non-admin user lands here, render child directly
    if (user != null && !user.role.isAdmin) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < ResponsiveBreakpoints.mobileMax;
        final isTablet = width >= ResponsiveBreakpoints.mobileMax &&
            width < ResponsiveBreakpoints.tabletMax;
        final isSmallDesktop = width >= ResponsiveBreakpoints.tabletMax &&
            width < ResponsiveBreakpoints.smallDesktopMax;

        // 1. Mobile Layout (< 600px): Scaffold with Drawer
        if (isMobile) {
          return Scaffold(
            appBar: AdminTopBar(
              currentPath: widget.currentPath,
              showDrawerButton: true,
            ),
            drawer: Drawer(
              child: AdminSidebar(
                currentPath: widget.currentPath,
                isCollapsed: false,
                isDrawer: true,
              ),
            ),
            body: SafeArea(
              child: widget.child,
            ),
          );
        }

        // 2. Tablet Layout (600px - 899px): Collapsed rail
        if (isTablet) {
          return Scaffold(
            body: Row(
              children: [
                AdminSidebar(
                  currentPath: widget.currentPath,
                  isCollapsed: true,
                ),
                Expanded(
                  child: Column(
                    children: [
                      AdminTopBar(
                        currentPath: widget.currentPath,
                        showDrawerButton: false,
                      ),
                      Expanded(
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // 3. Small Desktop (900px - 1199px) & Desktop (>= 1200px): Persistent Sidebar with collapse toggle
        final effectiveCollapsed = isSmallDesktop ? true : _isCollapsed;

        return Scaffold(
          body: Row(
            children: [
              AdminSidebar(
                currentPath: widget.currentPath,
                isCollapsed: effectiveCollapsed,
                onToggleCollapse: _toggleCollapse,
              ),
              Expanded(
                child: Column(
                  children: [
                    AdminTopBar(
                      currentPath: widget.currentPath,
                      showDrawerButton: false,
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: ResponsiveBreakpoints.maxContentWidth,
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
