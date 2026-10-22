import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/presentation/widgets/record_material_usage_dialog.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/production/presentation/widgets/process_stage_actions_dialog.dart';
import 'package:unity/features/process_queries/presentation/screens/raise_query_screen.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/tasks/presentation/widgets/process_task_card.dart';
import 'package:unity/features/tasks/presentation/widgets/update_task_status_dialog.dart';

/// Employee Dashboard: Shop-floor task portal for manufacturing workers.
class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading employee profile...'),
      );
    }

    final tasksAsync = ref.watch(tasksStreamProvider);
    final isLoadingTasks = tasksAsync.isLoading;
    final myTasks = ref.watch(myAssignedTasksProvider);
    final todaysTasks = ref.watch(todaysScheduleTasksProvider);
    final pendingTasks = ref.watch(pendingOrPausedTasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Production Terminal'),
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
                    'Are you sure you want to log off from this station?',
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
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tasksStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee Banner
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
                          color: AppColors.roleEmployeeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.engineering_rounded,
                          color: AppColors.roleEmployee,
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
                                    'Worker: ${user.fullName}',
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
                                    color: AppColors.roleEmployeeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    user.role.value,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.roleEmployee,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Facility Org: ${user.organizationId}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Floor Shortcuts
                Text('Shop-Floor Actions', style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FloorShortcutButton(
                        title: 'Update Status',
                        subtitle: 'Process progress',
                        icon: Icons.update_rounded,
                        color: AppColors.secondary,
                        onTap: () => UpdateTaskStatusDialog.show(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FloorShortcutButton(
                        title: 'Material Usage',
                        subtitle: 'Log consumption',
                        icon: Icons.inventory_rounded,
                        color: AppColors.accent,
                        onTap: () => RecordMaterialUsageDialog.show(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FloorShortcutButton(
                        title: 'Raise Ticket',
                        subtitle: 'Report blocker',
                        icon: Icons.help_outline_rounded,
                        color: AppColors.warning,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RaiseQueryScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Phase 3: Active Production Stages Assigned to Worker
                const _AssignedManufacturingStagesSection(),
                const SizedBox(height: 28),

                // My Assigned Tasks Section
                _TaskSectionCard(
                  title: 'My Assigned Tasks',
                  icon: Icons.assignment_ind_outlined,
                  tasks: myTasks,
                  isLoading: isLoadingTasks,
                  emptyMessage: 'No active tasks assigned to your station.\nSelect any task below to begin work.',
                ),
                const SizedBox(height: 24),

                // Today's Work Section
                _TaskSectionCard(
                  title: "Today's Work Schedule",
                  icon: Icons.today_rounded,
                  tasks: todaysTasks,
                  isLoading: isLoadingTasks,
                  emptyMessage: 'No operations currently scheduled for today.',
                ),
                const SizedBox(height: 24),

                // Pending / Paused Tasks Section
                _TaskSectionCard(
                  title: 'Pending / Paused Tasks',
                  icon: Icons.pending_actions_rounded,
                  tasks: pendingTasks,
                  isLoading: isLoadingTasks,
                  emptyMessage: 'No pending or paused operations requiring attention.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorShortcutButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FloorShortcutButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
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
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 12, color: color),
                      const SizedBox(width: 2),
                      Text(
                        'Active',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.titleSmall),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<ProcessTask> tasks;
  final bool isLoading;
  final String emptyMessage;

  const _TaskSectionCard({
    required this.title,
    required this.icon,
    required this.tasks,
    required this.isLoading,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tasks.isNotEmpty ? AppColors.secondary.withValues(alpha: 0.12) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tasks.length}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: tasks.isNotEmpty ? AppColors.secondaryDark : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading && tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ...tasks.map((task) => ProcessTaskCard(task: task)),
      ],
    );
  }
}

class _AssignedManufacturingStagesSection extends ConsumerWidget {
  const _AssignedManufacturingStagesSection();

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppColors.success;
      case 'IN_PROGRESS':
        return AppColors.info;
      case 'PENDING_APPROVAL':
        return AppColors.warning;
      case 'ASSIGNED':
        return AppColors.secondary;
      case 'BLOCKED':
      case 'REWORK_REQUIRED':
        return AppColors.error;
      case 'NOT_STARTED':
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignedProcessesAsync = ref.watch(employeeAssignedProcessesStreamProvider);
    final ordersAsync = ref.watch(productionOrdersStreamProvider);
    final orders = ordersAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.precision_manufacturing_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Manufacturing Station Queue', style: AppTextStyles.titleMedium),
            const Spacer(),
            assignedProcessesAsync.maybeWhen(
              data: (list) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: list.isNotEmpty ? AppColors.primaryLight : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${list.length} Stages',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: list.isNotEmpty ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        assignedProcessesAsync.when(
          loading: () => const LoadingWidget(message: 'Syncing assigned stages...'),
          error: (e, _) => Text('Error loading assigned stages: $e', style: AppTextStyles.bodySmall),
          data: (processes) {
            if (processes.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 36, color: AppColors.success),
                    const SizedBox(height: 8),
                    Text(
                      'All assigned stages up to date.',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Work orders will display here once assigned to your station by supervisor.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: processes.map((proc) {
                // Find matching order by proc.orderId or orderNumber
                final matchingOrder = orders.cast<ProductionOrder?>().firstWhere(
                  (o) => o != null && (o.id == proc.orderId || o.orderNumber == proc.orderId),
                  orElse: () => null,
                );

                final order = matchingOrder ?? ProductionOrder(
                  id: proc.orderId,
                  orderNumber: proc.orderId.isNotEmpty ? proc.orderId : 'WO-ACTIVE',
                  productName: 'Production Batch',
                  targetQuantity: proc.targetQty.toDouble(),
                  completedQuantity: proc.completedQty.toDouble(),
                  unit: 'PCS',
                  status: 'in_production',
                  priority: 'normal',
                  startDate: DateTime.now(),
                );

                final statusColor = _getStatusColor(proc.status);
                final pct = proc.targetQty > 0 ? (proc.completedQty / proc.targetQty).clamp(0.0, 1.0) : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: proc.status == 'REWORK_REQUIRED'
                          ? AppColors.error
                          : (proc.isInProgress ? AppColors.info : AppColors.border),
                      width: (proc.isInProgress || proc.status == 'REWORK_REQUIRED') ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Step ${proc.sequence}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              proc.name,
                              style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              proc.status.replaceAll('_', ' '),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Target Batch: ${order.orderNumber} • ${order.productName}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),

                      // Progress bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Units: ${proc.completedQty} / ${proc.targetQty} ${order.unit}',
                            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),

                      if (proc.status == 'REWORK_REQUIRED' && proc.reworkReason.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Rework: ${proc.reworkReason}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ProcessStageActionsDialog.show(
                              context,
                              order: order,
                              process: proc.orderId.isNotEmpty ? proc : proc.copyWith(orderId: order.id),
                              allStageStatuses: {proc.sequence: proc.status},
                            );
                          },
                          icon: const Icon(Icons.touch_app_rounded, size: 16),
                          label: const Text('Stage Actions & Output (+Units)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: AppTextStyles.labelSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

