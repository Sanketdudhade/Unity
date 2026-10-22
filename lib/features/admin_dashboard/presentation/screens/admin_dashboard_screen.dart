import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';

/// Admin Dashboard: High-level overview and operations portal for managers.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final employeeCount = ref.watch(employeeCountProvider);
    final lowStockCount = ref.watch(lowStockCountProvider);
    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final activeProcessesCount = tasks.where((t) => t.isInProgress).length;
    final pendingTasksCount = tasks.where((t) => t.isPending || t.isPaused).length;

    if (user == null) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading administrator profile...'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            tooltip: 'View Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(RouteNames.profile),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Sign Out'),
                  content: const Text(
                    'Are you sure you want to end your administrative session?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref.read(authStateProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome & Organization Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.roleAdminBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AppColors.roleAdmin,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Welcome, ${user.fullName}',
                                  style: AppTextStyles.titleLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.roleAdminBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user.role.value,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.roleAdmin,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Organization: ${user.organizationId}',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // KPI / Metrics Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Operational Overview',
                    style: AppTextStyles.titleMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Live Cloud Metrics',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2x2 Metric Grid (Live employees and inventory metrics)
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricCard(
                    title: 'Total Employees',
                    value: '$employeeCount',
                    subtitle: 'Personnel',
                    icon: Icons.people_outline_rounded,
                    accentColor: AppColors.secondary,
                    isLive: true,
                  ),
                  _MetricCard(
                    title: 'Active Processes',
                    value: '$activeProcessesCount',
                    subtitle: activeProcessesCount > 0 ? 'In stages' : 'Station idle',
                    icon: Icons.precision_manufacturing_outlined,
                    accentColor: AppColors.info,
                    isLive: true,
                  ),
                  _MetricCard(
                    title: 'Pending Tasks',
                    value: '$pendingTasksCount',
                    subtitle: pendingTasksCount > 0 ? 'Awaiting action' : 'Optimal',
                    icon: Icons.assignment_outlined,
                    accentColor: AppColors.warning,
                    isLive: true,
                  ),
                  _MetricCard(
                    title: 'Low Stock Alerts',
                    value: '$lowStockCount',
                    subtitle: lowStockCount > 0 ? 'Requires Action' : 'Optimal',
                    icon: Icons.warning_amber_rounded,
                    accentColor: lowStockCount > 0 ? AppColors.error : AppColors.success,
                    isLive: true,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Quick-Access Management Modules
              Text('Management Modules', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ModuleTile(
                    title: 'Employees',
                    subtitle: 'Directory & roles',
                    icon: Icons.badge_outlined,
                    isSoon: false,
                    onTap: () => context.push(RouteNames.adminEmployees),
                  ),
                  _ModuleTile(
                    title: 'Products',
                    subtitle: 'Parts & drawings',
                    icon: Icons.category_outlined,
                    isSoon: false,
                    onTap: () => context.push(RouteNames.adminProducts),
                  ),
                  _ModuleTile(
                    title: 'Inventory',
                    subtitle: 'Stock & materials',
                    icon: Icons.warehouse_outlined,
                    isSoon: false,
                    onTap: () => context.push(RouteNames.adminInventory),
                  ),
                  _ModuleTile(
                    title: 'Production',
                    subtitle: 'Orders & batches',
                    icon: Icons.inventory_2_outlined,
                    isSoon: false,
                    onTap: () => context.push(RouteNames.adminProduction),
                  ),
                  _ModuleTile(
                    title: 'Processes',
                    subtitle: 'Workflows & stages',
                    icon: Icons.schema_outlined,
                    isSoon: false,
                    onTap: () => context.push(RouteNames.adminProcesses),
                  ),
                  _ModuleTile(
                    title: 'Queries',
                    subtitle: 'Shop-floor tickets',
                    icon: Icons.help_outline_rounded,
                    isSoon: false,
                    onTap: () => context.push(RouteNames.adminQueries),
                  ),
                  _ModuleTile(
                    title: 'Reports',
                    subtitle: 'Audits & metrics',
                    icon: Icons.insights_rounded,
                    isSoon: false,
                    onTap: () => context.push(RouteNames.adminReports),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isLive;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isLive ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isLive ? accentColor : AppColors.textMuted,
                  fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSoon;

  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isSoon = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSoon ? AppColors.border : AppColors.secondaryLight.withValues(alpha: 0.6),
            width: isSoon ? 1.0 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSoon ? AppColors.surfaceVariant : AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: isSoon ? AppColors.textMuted : AppColors.secondary),
                  ),
                if (isSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Soon',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Active',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

