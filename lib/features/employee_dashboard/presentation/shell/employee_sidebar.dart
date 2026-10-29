import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employee_dashboard/presentation/providers/employee_dashboard_provider.dart';

/// Navigation item model for employee terminal tabs.
class EmployeeNavItem {
  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String tooltip;

  const EmployeeNavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
  });
}

/// Modern Enterprise Sidebar for the Employee Workspace.
/// Supports full-width drawer on mobile, collapsed rail on tablet, and persistent collapsible mode on desktop.
class EmployeeSidebar extends ConsumerWidget {
  final bool isCollapsed;
  final bool isDrawer;
  final VoidCallback? onToggleCollapse;

  const EmployeeSidebar({
    super.key,
    this.isCollapsed = false,
    this.isDrawer = false,
    this.onToggleCollapse,
  });

  static const List<EmployeeNavItem> destinations = [
    EmployeeNavItem(
      index: 0,
      label: 'Terminal Overview',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      tooltip: 'Station shift overview & performance summary',
    ),
    EmployeeNavItem(
      index: 1,
      label: 'Station Queue',
      icon: Icons.precision_manufacturing_outlined,
      activeIcon: Icons.precision_manufacturing_rounded,
      tooltip: 'Active 17-stage manufacturing flow assigned to you',
    ),
    EmployeeNavItem(
      index: 2,
      label: 'My Tasks',
      icon: Icons.assignment_ind_outlined,
      activeIcon: Icons.assignment_ind_rounded,
      tooltip: 'Work order operations & status tracking',
    ),
    EmployeeNavItem(
      index: 3,
      label: 'Material Usage',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      tooltip: 'Log consumption & verify raw material balances',
    ),
    EmployeeNavItem(
      index: 4,
      label: 'Floor Tickets',
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_rounded,
      tooltip: 'Raise blocker tickets and maintenance requests',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;
    final activeTab = ref.watch(employeeSelectedTabProvider);
    final metrics = ref.watch(employeeSummaryMetricsProvider);

    final sidebarBg = isDark ? const Color(0xFF0E1728) : const Color(0xFF142238);
    final sidebarBorder = isDark ? const Color(0xFF1C2B41) : const Color(0xFF1E293B);

    final width = isDrawer
        ? 280.0
        : (isCollapsed ? 72.0 : 250.0);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(color: sidebarBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. Branding Header
            Container(
              height: 58,
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: sidebarBorder, width: 1)),
              ),
              child: isCollapsed
                  ? Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'U',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'UNITY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'EMPLOYEE TERMINAL',
                                style: TextStyle(
                                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.9),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onToggleCollapse != null && !isDrawer)
                          IconButton(
                            icon: const Icon(Icons.menu_open_rounded, color: Color(0xFFA6B6CB), size: 18),
                            tooltip: 'Collapse Sidebar',
                            visualDensity: VisualDensity.compact,
                            onPressed: onToggleCollapse,
                          ),
                      ],
                    ),
            ),

            // 2. Navigation Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                children: destinations.map((item) {
                  final isSelected = activeTab == item.index;

                  int badgeCount = 0;
                  if (item.index == 1) badgeCount = metrics.assignedStagesCount;
                  if (item.index == 2) badgeCount = metrics.activeTasksCount;
                  if (item.index == 4) badgeCount = metrics.openTicketsCount;

                  return _buildNavItem(
                    context: context,
                    ref: ref,
                    item: item,
                    isSelected: isSelected,
                    isCollapsed: isCollapsed,
                    badgeCount: badgeCount,
                    isDrawer: isDrawer,
                  );
                }).toList(),
              ),
            ),

            // 3. Bottom Expand / Collapse Toggle (for desktop collapsed mode)
            if (isCollapsed && onToggleCollapse != null && !isDrawer)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFA6B6CB), size: 14),
                  tooltip: 'Expand Sidebar',
                  onPressed: onToggleCollapse,
                ),
              ),

            // 4. Worker Identity & Station Footer
            Container(
              padding: EdgeInsets.all(isCollapsed ? 8 : 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: sidebarBorder, width: 1)),
                color: isDark ? const Color(0xFF090E19) : const Color(0xFF0F1A2C),
              ),
              child: isCollapsed
                  ? Tooltip(
                      message: '${user?.fullName ?? "Worker"} (${user?.role.value ?? "Employee"})\nClick to view profile',
                      child: InkWell(
                        onTap: () {
                          final router = GoRouter.of(context);
                          if (isDrawer) Navigator.of(context).pop();
                          router.push(RouteNames.profile);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF0F766E),
                            child: Text(
                              user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'W',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF0F766E),
                          child: Text(
                            user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'W',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user?.fullName ?? 'Shop Worker',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user?.role.value.toUpperCase() ?? 'EMPLOYEE',
                                      style: const TextStyle(
                                        color: Color(0xFF2DD4BF),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user?.organizationId ?? '',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Color(0xFFA6B6CB), size: 18),
                          tooltip: 'Account Settings & Profile',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final router = GoRouter.of(context);
                            if (isDrawer) Navigator.of(context).pop();
                            router.push(RouteNames.profile);
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required WidgetRef ref,
    required EmployeeNavItem item,
    required bool isSelected,
    required bool isCollapsed,
    required int badgeCount,
    required bool isDrawer,
  }) {
    final activeColor = const Color(0xFF2DD4BF);
    final inactiveColor = const Color(0xFFA6B6CB);
    final activeBg = const Color(0xFF0F766E).withValues(alpha: 0.25);

    final content = InkWell(
      onTap: () {
        ref.read(employeeSelectedTabProvider.notifier).state = item.index;
        if (isDrawer) {
          Navigator.of(context).pop();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 20,
              color: isSelected ? activeColor : inactiveColor,
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : inactiveColor,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFA6B6CB),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: item.label + (badgeCount > 0 ? ' ($badgeCount)' : ''),
          preferBelow: false,
          child: content,
        ),
      );
    }

    return content;
  }
}
