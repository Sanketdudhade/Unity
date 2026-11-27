import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/employee_dashboard/presentation/providers/employee_dashboard_provider.dart';
import 'package:unity/features/employee_dashboard/presentation/widgets/assigned_stage_card.dart';
import 'package:unity/features/employee_dashboard/presentation/widgets/employee_metric_card.dart';
import 'package:unity/features/employee_dashboard/presentation/widgets/employee_welcome_header.dart';
import 'package:unity/features/inventory/presentation/widgets/record_material_usage_dialog.dart';
import 'package:unity/features/process_queries/presentation/screens/raise_query_screen.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/tasks/presentation/widgets/process_task_card.dart';
import 'package:unity/features/tasks/presentation/widgets/update_task_status_dialog.dart';

/// Overview tab conforming to Section 5: Welcome banner, 4 KPI cards, active spotlight, and station queue.
class EmployeeOverviewView extends ConsumerWidget {
  const EmployeeOverviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final metrics = ref.watch(employeeSummaryMetricsProvider);
    final stagesAsync = ref.watch(employeeAssignedProcessesStreamProvider);
    final ordersAsync = ref.watch(productionOrdersStreamProvider);
    final myTasks = ref.watch(myAssignedTasksProvider);
    final allTasksAsync = ref.watch(tasksStreamProvider);

    final orders = ordersAsync.value ?? [];
    final stages = stagesAsync.value ?? [];

    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);

    // Active spotlight stage (first IN_PROGRESS stage, or first assigned stage)
    OrderProcessModel? activeStage;
    for (final s in stages) {
      if (s.isInProgress) {
        activeStage = s;
        break;
      }
    }
    if (activeStage == null && stages.isNotEmpty) {
      activeStage = stages.firstWhere(
        (s) => s.status == 'ASSIGNED' || s.status == 'NOT_STARTED',
        orElse: () => stages.first,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tasksStreamProvider);
        ref.invalidate(employeeAssignedProcessesStreamProvider);
        ref.invalidate(productionOrdersStreamProvider);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Welcome & Shift Header
            EmployeeWelcomeHeader(
              onUpdateStatus: () => UpdateTaskStatusDialog.show(context),
              onLogMaterial: () => RecordMaterialUsageDialog.show(context),
              onRaiseTicket: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RaiseQueryScreen()),
                );
              },
            ),

            const SizedBox(height: 16),

            // 2. Performance Summary: 4 KPI Cards
            GridView.count(
              crossAxisCount: isSmallMobile ? 1 : (isMobile ? 2 : 4),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isSmallMobile ? 2.1 : (isMobile ? 1.35 : (isTablet ? 1.45 : 1.9)),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                EmployeeMetricCard(
                  title: 'Assigned Stages',
                  value: '${metrics.assignedStagesCount}',
                  subtitle: '${metrics.inProgressStagesCount} in progress now',
                  icon: Icons.precision_manufacturing_rounded,
                  accentColor: const Color(0xFF0F766E),
                  onTap: () => ref.read(employeeSelectedTabProvider.notifier).state = 1,
                  isLoading: stagesAsync.isLoading,
                ),
                EmployeeMetricCard(
                  title: 'Active Tasks',
                  value: '${metrics.activeTasksCount}',
                  subtitle: 'Shop-floor operations',
                  icon: Icons.play_arrow_rounded,
                  accentColor: const Color(0xFF2563EB),
                  onTap: () => ref.read(employeeSelectedTabProvider.notifier).state = 2,
                  isLoading: allTasksAsync.isLoading,
                ),
                EmployeeMetricCard(
                  title: 'Needs Attention',
                  value: '${metrics.pendingOrPausedCount}',
                  subtitle: 'Paused or blocked items',
                  icon: Icons.warning_amber_rounded,
                  accentColor: tokens.warning,
                  onTap: () {
                    ref.read(employeeTaskFilterProvider.notifier).state = 'Paused';
                    ref.read(employeeSelectedTabProvider.notifier).state = 2;
                  },
                  isLoading: allTasksAsync.isLoading,
                ),
                EmployeeMetricCard(
                  title: 'Completed',
                  value: '${metrics.completedTasksCount}',
                  subtitle: 'Operations signed off',
                  icon: Icons.check_circle_outline_rounded,
                  accentColor: tokens.success,
                  onTap: () {
                    ref.read(employeeTaskFilterProvider.notifier).state = 'Completed';
                    ref.read(employeeSelectedTabProvider.notifier).state = 2;
                  },
                  isLoading: allTasksAsync.isLoading,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Active Manufacturing Spotlight (if worker has an assigned stage)
            if (activeStage != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: activeStage.isInProgress ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CURRENT STATION FOCUS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => ref.read(employeeSelectedTabProvider.notifier).state = 1,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text('All Stages'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AssignedStageCard(
                stage: activeStage,
                order: orders.cast<ProductionOrder?>().firstWhere(
                      (o) => o != null && (o.id == activeStage!.orderId || o.orderNumber == activeStage.orderId),
                      orElse: () => null,
                    ),
              ),
              const SizedBox(height: 20),
            ],

            // 4. Manufacturing Station Queue (Assigned Stages List)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing_rounded, size: 18, color: Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    Text(
                      'Station Queue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: stages.isNotEmpty
                            ? const Color(0xFF0F766E).withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${stages.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: stages.isNotEmpty ? const Color(0xFF0F766E) : textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => ref.read(employeeSelectedTabProvider.notifier).state = 1,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            stagesAsync.when(
              loading: () => const LoadingWidget(message: 'Syncing assigned stages...'),
              error: (e, _) => Text('Error loading stages: $e', style: TextStyle(color: tokens.danger)),
              data: (list) {
                if (list.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF152235) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 36, color: tokens.success),
                        const SizedBox(height: 8),
                        Text(
                          'No stages assigned right now',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'When a production order is dispatched to your station, it will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                // Show top 3 stages
                return Column(
                  children: list.take(3).map((stage) {
                    final matchingOrder = orders.cast<ProductionOrder?>().firstWhere(
                          (o) => o != null && (o.id == stage.orderId || o.orderNumber == stage.orderId),
                          orElse: () => null,
                        );
                    return AssignedStageCard(stage: stage, order: matchingOrder);
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // 5. My Assigned Tasks Preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_ind_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned Floor Tasks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: myTasks.isNotEmpty
                            ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${myTasks.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: myTasks.isNotEmpty ? const Color(0xFF2563EB) : textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => ref.read(employeeSelectedTabProvider.notifier).state = 2,
                  child: const Text('View All Tasks'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (myTasks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF152235) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'No direct tasks assigned to your station. Active stages above provide your primary workflow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              )
            else
              Column(
                children: myTasks.take(3).map((task) => ProcessTaskCard(task: task)).toList(),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
