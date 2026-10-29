import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'admin_sidebar.dart';
import 'admin_top_bar.dart';

/// Modern Enterprise Admin Shell wrapping all admin screens.
/// Conforms to Section A4: Desktop fixed sidebar, tablet rail, mobile drawer.
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
        final isDesktop = width >= 1024;
        final isTablet = width >= 600 && width < 1024;

        // 1. Mobile Layout (< 600px): Scaffold with Drawer
        if (!isDesktop && !isTablet) {
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
            body: widget.child,
          );
        }

        // 2. Tablet Layout (600px - 1023px): Collapsed rail
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

        // 3. Desktop Layout (>= 1024px): Persistent Sidebar with collapse toggle
        return Scaffold(
          body: Row(
            children: [
              AdminSidebar(
                currentPath: widget.currentPath,
                isCollapsed: _isCollapsed,
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
                          constraints: const BoxConstraints(maxWidth: 1600),
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
