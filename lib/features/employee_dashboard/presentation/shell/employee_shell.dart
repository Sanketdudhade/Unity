import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employee_dashboard/presentation/providers/employee_dashboard_provider.dart';
import 'employee_sidebar.dart';
import 'employee_top_bar.dart';

/// Responsive enterprise application shell for the Employee Terminal.
/// Conforms to Section 4:
/// - Android Mobile (< 600px): Scaffold + Drawer + TopBar + Bottom NavigationBar.
/// - Android Tablet (600px - 1023px): Collapsed Rail + TopBar.
/// - Windows Desktop (>= 1024px): Persistent Collapsible Sidebar + Desktop Header.
class EmployeeShell extends ConsumerStatefulWidget {
  final Widget child;

  const EmployeeShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends ConsumerState<EmployeeShell> {
  bool _isCollapsed = false;

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final activeTab = ref.watch(employeeSelectedTabProvider);
    final metrics = ref.watch(employeeSummaryMetricsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Safety fallback: If an admin user opens this directly, render child without constraints
    if (user != null && user.role.isAdmin) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;
        final isTablet = width >= 600 && width < 1024;

        // 1. Mobile Layout (< 600px): Scaffold with Drawer, TopBar, and Bottom NavigationBar
        if (!isDesktop && !isTablet) {
          // In bottom bar, map 4 primary destinations (Overview, Station, Tasks, Materials).
          // If Tab 4 (Tickets) is active from drawer/shortcuts, bottom bar doesn't highlight or shows drawer.
          final bottomBarIndex = activeTab <= 3 ? activeTab : 0;

          return Scaffold(
            appBar: const EmployeeTopBar(showDrawerButton: true),
            drawer: const Drawer(
              child: EmployeeSidebar(
                isCollapsed: false,
                isDrawer: true,
              ),
            ),
            body: widget.child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: bottomBarIndex,
              onDestinationSelected: (index) {
                ref.read(employeeSelectedTabProvider.notifier).state = index;
              },
              backgroundColor: isDark ? const Color(0xFF152235) : Colors.white,
              indicatorColor: const Color(0xFF0F766E).withValues(alpha: 0.18),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF0F766E)),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: metrics.assignedStagesCount > 0,
                    label: Text('${metrics.assignedStagesCount}'),
                    child: const Icon(Icons.precision_manufacturing_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: metrics.assignedStagesCount > 0,
                    label: Text('${metrics.assignedStagesCount}'),
                    child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF0F766E)),
                  ),
                  label: 'Stages',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: metrics.activeTasksCount > 0,
                    label: Text('${metrics.activeTasksCount}'),
                    child: const Icon(Icons.assignment_ind_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: metrics.activeTasksCount > 0,
                    label: Text('${metrics.activeTasksCount}'),
                    child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF0F766E)),
                  ),
                  label: 'Tasks',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFF0F766E)),
                  label: 'Materials',
                ),
              ],
            ),
          );
        }

        // 2. Tablet Layout (600px - 1023px): Collapsed Rail + TopBar
        if (isTablet) {
          return Scaffold(
            body: Row(
              children: [
                const EmployeeSidebar(
                  isCollapsed: true,
                ),
                Expanded(
                  child: Column(
                    children: [
                      const EmployeeTopBar(
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
              EmployeeSidebar(
                isCollapsed: _isCollapsed,
                onToggleCollapse: _toggleCollapse,
              ),
              Expanded(
                child: Column(
                  children: [
                    const EmployeeTopBar(
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
      },
    );
  }
}
