import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/production/presentation/screens/production_details_screen.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';
import '../widgets/status_chip.dart';

/// Modern Enterprise Admin Dashboard: High-density operational overview.
/// Replaces oversized empty cards with live manufacturing metrics, active work orders,
/// low stock alerts, and shop-floor task assignments conforming to Section A5.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;

    if (user == null) {
      return const LoadingWidget(message: 'Loading administrator profile...');
    }

    // Existing live data providers
    final employeeCount = ref.watch(employeeCountProvider);
    final lowStockCount = ref.watch(lowStockCountProvider);
    final lowStockBalances = ref.watch(lowStockBalancesStreamProvider).value ?? [];
    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final orders = ref.watch(productionOrdersStreamProvider).value ?? [];

    final activeProcessesCount = tasks.where((t) => t.isInProgress).length;
    final pendingTasksCount = tasks.where((t) => t.isPending || t.isPaused).length;

    // Filter in-flight production orders
    final activeOrders = orders.where((o) => o.isInProduction || o.isScheduled).toList();
    final inProdCount = orders.where((o) => o.isInProduction).length;
    final schedCount = orders.where((o) => o.isScheduled).length;
    final compCount = orders.where((o) => o.isCompleted).length;
    final onHoldCount = orders.where((o) => o.isOnHold).length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tasksStreamProvider);
        ref.invalidate(productionOrdersStreamProvider);
        ref.invalidate(lowStockBalancesStreamProvider);
        ref.invalidate(employeeCountProvider);
      },
      child: LayoutBuilder(
        builder: (context, screenConstraints) {
          final isMobile = screenConstraints.maxWidth < 600;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------------------
                // SECTION 1: COMPACT CONTEXT HEADER (Responsive)
                // -------------------------------------------------------------
                Builder(
                  builder: (context) {
                    final titleBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Welcome back, ${user.fullName}',
                              style: TextStyle(
                                fontSize: isMobile ? 19 : 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LIVE OPERATIONS',
                                style: TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time production tracking, safety stock levels, and personnel operations.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    );

                    final actionsBlock = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Refresh Feed'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            ref.invalidate(tasksStreamProvider);
                            ref.invalidate(productionOrdersStreamProvider);
                            ref.invalidate(lowStockBalancesStreamProvider);
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Launch Work Order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => context.push(RouteNames.adminProduction),
                        ),
                      ],
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 12),
                          actionsBlock,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 16),
                        actionsBlock,
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // SECTION 2: LIVE KPI TILES (Real data, tabular figures)
                // -------------------------------------------------------------
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    final isMedium = constraints.maxWidth >= 550 && constraints.maxWidth < 900;

                    return GridView.count(
                      crossAxisCount: isWide ? 4 : (isMedium ? 2 : 1),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.75 : (isMedium ? 1.85 : 2.1),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        MetricCard(
                          title: 'Total Personnel',
                          value: '$employeeCount',
                          subtitle: 'Active roster & station roles',
                          icon: Icons.people_outline_rounded,
                          accentColor: const Color(0xFF0F766E),
                          onTap: () => context.push(RouteNames.adminEmployees),
                        ),
                        MetricCard(
                          title: 'Active Processes',
                          value: '$activeProcessesCount',
                          subtitle: activeProcessesCount > 0 ? '$activeProcessesCount running on floor' : 'Stations idle',
                          icon: Icons.precision_manufacturing_rounded,
                          accentColor: const Color(0xFF1D4ED8),
                          onTap: () => context.push(RouteNames.adminProduction),
                        ),
                        MetricCard(
                          title: 'Pending Tasks',
                          value: '$pendingTasksCount',
                          subtitle: pendingTasksCount > 0 ? 'Awaiting technician action' : 'All tasks cleared',
                          icon: Icons.assignment_outlined,
                          accentColor: const Color(0xFFB45309),
                          onTap: () => context.push(RouteNames.adminProduction),
                        ),
                        MetricCard(
                          title: 'Low Stock Alerts',
                          value: '$lowStockCount',
                          subtitle: lowStockCount > 0 ? '$lowStockCount items below safety minimum' : 'All materials optimal',
                          icon: Icons.warning_amber_rounded,
                          accentColor: lowStockCount > 0 ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                          onTap: () => context.push(RouteNames.adminInventory),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // SECTION 4: PRODUCTION STATUS DISTRIBUTION PILLS
                // -------------------------------------------------------------
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF152235) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Builder(
                    builder: (context) {
                      final pills = Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StatusCountPill(
                            label: 'In Production',
                            count: inProdCount,
                            color: const Color(0xFF1D4ED8),
                            icon: Icons.precision_manufacturing_rounded,
                          ),
                          _StatusCountPill(
                            label: 'Scheduled',
                            count: schedCount,
                            color: const Color(0xFFB45309),
                            icon: Icons.schedule_rounded,
                          ),
                          _StatusCountPill(
                            label: 'Completed',
                            count: compCount,
                            color: const Color(0xFF15803D),
                            icon: Icons.check_circle_rounded,
                          ),
                          if (onHoldCount > 0)
                            _StatusCountPill(
                              label: 'On Hold',
                              count: onHoldCount,
                              color: const Color(0xFFB91C1C),
                              icon: Icons.pause_circle_rounded,
                            ),
                        ],
                      );

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Pipeline Status:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            pills,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Text(
                            'Order Pipeline Status:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: pills),
                        ],
                      );
                    },
                  ),
                ),

            const SizedBox(height: 24),

            // -------------------------------------------------------------
            // SECTION 3: ACTION-REQUIRED ZONE (2/3 Work Orders, 1/3 Alerts)
            // -------------------------------------------------------------
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;

                if (!isWide) {
                  return Column(
                    children: [
                      _buildActiveWorkOrdersSection(context, ref, activeOrders),
                      const SizedBox(height: 24),
                      _buildUrgentStockAlertsSection(context, lowStockBalances),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left 2/3: Active Work Orders & Progress
                    Expanded(
                      flex: 65,
                      child: _buildActiveWorkOrdersSection(context, ref, activeOrders),
                    ),
                    const SizedBox(width: 20),
                    // Right 1/3: Low Stock Alerts
                    Expanded(
                      flex: 35,
                      child: _buildUrgentStockAlertsSection(context, lowStockBalances),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // -------------------------------------------------------------
            // SECTION 5: RECENT PROCESS UPDATES & FLOOR TASKS
            // -------------------------------------------------------------
            SectionCard(
              title: 'Floor Operations & Recent Tasks',
              subtitle: 'Active assignments distributed across manufacturing workstations',
              trailing: TextButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('View All in Production'),
                onPressed: () => context.push(RouteNames.adminProduction),
              ),
              child: tasks.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.assignment_outlined,
                      title: 'No operations currently dispatched',
                      description: 'Launch a work order in Production to assign 17-stage manufacturing tasks.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tasks.take(6).length,
                      separatorBuilder: (_, _) => Divider(
                        color: isDark ? const Color(0xFF304155) : const Color(0xFFF1F5F9),
                        height: 16,
                      ),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _buildTaskRow(context, task, isDark);
                      },
                    ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      );
    },
  ),
);
  }

  Widget _buildActiveWorkOrdersSection(
    BuildContext context,
    WidgetRef ref,
    List<ProductionOrder> activeOrders,
  ) {
    return SectionCard(
      title: 'In-Flight Work Orders & Batches',
      subtitle: '${activeOrders.length} active production orders currently in execution',
      trailing: TextButton.icon(
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('All Orders'),
        onPressed: () => context.push(RouteNames.adminProduction),
      ),
      child: activeOrders.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.inventory_2_outlined,
              title: 'No active production orders',
              description: 'All work orders are completed or none have been launched yet.',
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeOrders.take(5).length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = activeOrders[index];
                return _buildOrderCard(context, ref, order);
              },
            ),
    );
  }

  void _showAssignStagesModal(BuildContext context, WidgetRef ref, ProductionOrder order) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final orgId = ref.read(authStateProvider).user?.organizationId ?? '';

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF132A26) : const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assignment_ind_rounded, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign Stages to Employees',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${order.orderNumber} • ${order.productName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: Consumer(
                builder: (context, ref, _) {
                  final processesAsync = ref.watch(orderProcessesStreamProvider(order.id));
                  final employeesAsync = ref.watch(employeesStreamProvider);

                  if (processesAsync.isLoading || employeesAsync.isLoading) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  if (processesAsync.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading stages: ${processesAsync.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 13)),
                    );
                  }

                  final processes = processesAsync.value ?? [];
                  final employees = employeesAsync.value ?? [];
                  final activeEmployees = employees.where((e) => e.isActive).toList();

                  // Deduplicate active employees by uid to avoid duplicate DropdownMenuItems
                  final uniqueEmployees = <String, AppUserModel>{};
                  for (final emp in activeEmployees) {
                    if (emp.uid.isNotEmpty) {
                      uniqueEmployees[emp.uid] = emp;
                    }
                  }

                  if (processes.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_clear_outlined, size: 36, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            'No stages snapshotted for this work order yet.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await ref.read(productionRepositoryProvider).initializeStagesForOrder(
                                      orgId: orgId,
                                      orderId: order.id,
                                    );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Initialized default 17 manufacturing stages for order.'),
                                    backgroundColor: Color(0xFF0F766E),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed to initialize: $e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                            icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                            label: const Text('Initialize 17 Stages Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF132A26).withValues(alpha: 0.5) : const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Assign shop-floor technicians to each stage. Once assigned, employees can view the stage on their dashboard and update working status.',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sequential Stages (${processes.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 380,
                        child: ListView.separated(
                          itemCount: processes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final proc = processes[index];
                            final hasAssigned = proc.assignedEmployeeUid.isNotEmpty;
                            final selectedUid = hasAssigned && uniqueEmployees.containsKey(proc.assignedEmployeeUid)
                                ? proc.assignedEmployeeUid
                                : null;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: hasAssigned
                                      ? (isDark ? const Color(0xFF2DD4BF).withValues(alpha: 0.4) : const Color(0xFF0F766E).withValues(alpha: 0.4))
                                      : theme.colorScheme.outline,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Step ${proc.sequence}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFF042F2E) : Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          proc.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      StatusChip(
                                        label: proc.status.replaceAll('_', ' '),
                                        variant: proc.isCompleted
                                            ? StatusVariant.success
                                            : (proc.isInProgress ? StatusVariant.info : StatusVariant.neutral),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String?>(
                                    key: ValueKey('assign_${proc.id}_$selectedUid'),
                                    initialValue: selectedUid,
                                    isDense: true,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Assigned Operator',
                                      prefixIcon: const Icon(Icons.person_outline, size: 16),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    hint: const Text('Unassigned (Shop-Floor Team)', style: TextStyle(fontSize: 12)),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Unassigned (Shop-Floor Team)', style: TextStyle(fontSize: 12)),
                                      ),
                                      ...uniqueEmployees.values.map(
                                        (emp) => DropdownMenuItem<String?>(
                                          value: emp.uid,
                                          child: Text(
                                            '${emp.fullName} (${emp.role.value})',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (newSelectedUid) async {
                                      final emp = newSelectedUid != null ? uniqueEmployees[newSelectedUid] : null;
                                      final newUid = newSelectedUid ?? '';
                                      final newName = emp?.fullName ?? 'Unassigned';

                                      try {
                                        await ref.read(productionRepositoryProvider).assignEmployeeToProcess(
                                              orgId: orgId,
                                              orderId: order.id,
                                              processId: proc.id,
                                              employeeUid: newUid,
                                              employeeName: newName,
                                            );
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              newUid.isNotEmpty
                                                  ? 'Step ${proc.sequence} (${proc.name}) assigned to $newName'
                                                  : 'Step ${proc.sequence} marked Unassigned',
                                            ),
                                            backgroundColor: const Color(0xFF0F766E),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to assign: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductionDetailsScreen(order: order),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Open 17 Stages Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                  foregroundColor: isDark ? const Color(0xFF042F2E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, ProductionOrder order) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pct = order.progressPercentage;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductionDetailsScreen(order: order),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2B41).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip.fromStatus(order.status),
                const SizedBox(width: 8),
                Text(
                  order.orderNumber,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.completedQuantity.toStringAsFixed(0)} / ${order.targetQuantity.toStringAsFixed(0)} ${order.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.productName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100.0).clamp(0.0, 1.0),
                      backgroundColor: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        order.isInProduction
                            ? const Color(0xFF0F766E)
                            : const Color(0xFFB45309),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAssignStagesModal(context, ref, order),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                  label: const Text('Assign Stages'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProductionDetailsScreen(order: order),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('17 Stages Details'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentStockAlertsSection(
    BuildContext context,
    List<StockBalanceModel> lowStockBalances,
  ) {
    return SectionCard(
      title: 'Urgent Stock Alerts',
      subtitle: '${lowStockBalances.length} materials below safety threshold',
      trailing: TextButton.icon(
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('Inventory'),
        onPressed: () => context.push(RouteNames.adminInventory),
      ),
      child: lowStockBalances.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.check_circle_outline_rounded,
              title: 'Stock levels optimal',
              description: 'No inventory items are currently below minimum safety levels.',
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lowStockBalances.take(5).length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final balance = lowStockBalances[index];
                return _buildAlertCard(context, balance);
              },
            ),
    );
  }

  Widget _buildAlertCard(BuildContext context, StockBalanceModel balance) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFB91C1C).withValues(alpha: 0.12)
            : const Color(0xFFFEE2E2).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? const Color(0xFFB91C1C).withValues(alpha: 0.4)
              : const Color(0xFFFCA5A5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  balance.materialSku,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Min: ${balance.formattedMinimumStock} ${balance.unit}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            balance.materialName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available: ${balance.formattedAvailable} ${balance.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB91C1C),
                ),
              ),
              Text(
                balance.locationName,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, ProcessTask task, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1C2B41)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 16,
              color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Order: ${task.workOrder} • Stage: ${task.stage}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.assignedToName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          StatusChip.fromStatus(task.status),
        ],
      ),
    );
  }
}

class _StatusCountPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatusCountPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
