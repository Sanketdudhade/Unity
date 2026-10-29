import 'package:flutter/material.dart';
import 'package:unity/app/router/route_names.dart';

/// Single navigation destination in the Admin Modern Enterprise shell.
class AdminNavDestination {
  final String title;
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String group;
  final bool hasBadge;

  const AdminNavDestination({
    required this.title,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.group,
    this.hasBadge = false,
  });

  static const List<AdminNavDestination> all = [
    // Overview Group
    AdminNavDestination(
      title: 'Dashboard',
      route: RouteNames.adminDashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      group: 'Overview',
    ),

    // Operations Group
    AdminNavDestination(
      title: 'Production & Batches',
      route: RouteNames.adminProduction,
      icon: Icons.precision_manufacturing_outlined,
      selectedIcon: Icons.precision_manufacturing_rounded,
      group: 'Operations',
    ),
    AdminNavDestination(
      title: 'Materials & Stock',
      route: RouteNames.adminInventory,
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse_rounded,
      group: 'Operations',
      hasBadge: true,
    ),

    // Management Group
    AdminNavDestination(
      title: 'Product Catalog',
      route: RouteNames.adminProducts,
      icon: Icons.category_outlined,
      selectedIcon: Icons.category_rounded,
      group: 'Management',
    ),
    AdminNavDestination(
      title: 'Personnel & Staff',
      route: RouteNames.adminEmployees,
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
      group: 'Management',
    ),

    // Insights Group
    AdminNavDestination(
      title: 'Floor Queries',
      route: RouteNames.adminQueries,
      icon: Icons.help_outline_rounded,
      selectedIcon: Icons.help_rounded,
      group: 'Insights',
    ),
    AdminNavDestination(
      title: 'Reports & Audits',
      route: RouteNames.adminReports,
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      group: 'Insights',
    ),
  ];

  static String getPageTitle(String location) {
    if (location.startsWith(RouteNames.adminDashboard)) return 'Production Overview';
    if (location.startsWith(RouteNames.adminProduction)) return 'Production & Batches';
    if (location.startsWith(RouteNames.adminInventory)) return 'Materials & Stock Master';
    if (location.startsWith(RouteNames.adminProducts)) return 'Product Catalog & Parts';
    if (location.startsWith(RouteNames.adminEmployees)) return 'Personnel & Roles';
    if (location.startsWith(RouteNames.adminQueries)) return 'Shop-Floor Queries';
    if (location.startsWith(RouteNames.adminReports)) return 'Operational Reports & Audits';
    if (location.startsWith(RouteNames.profile)) return 'Administrator Profile';
    return 'Admin Console';
  }
}
