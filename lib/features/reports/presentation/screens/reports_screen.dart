import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/core/widgets/responsive_layout.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/admin_page_header.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/process_queries/presentation/providers/query_providers.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/reports/presentation/screens/employee_report_screen.dart';
import 'package:unity/features/reports/presentation/screens/inventory_report_screen.dart';
import 'package:unity/features/reports/presentation/screens/production_report_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';

    final employeeCount = ref.watch(employeeCountProvider);
    final inventoryCount = ref.watch(inventoryCountProvider);
    final lowStockCount = ref.watch(lowStockCountProvider);
    final activeOrdersCount = ref.watch(activeProductionOrdersCountProvider);
    final completedOrdersCount = ref.watch(completedProductionOrdersCountProvider);
    final openQueriesCount = ref.watch(openQueriesCountProvider);

    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final materials = ref.watch(inventoryStreamProvider).value ?? [];

    final completedTasksCount = tasks.where((t) => t.isCompleted).length;
    final totalTasksCount = tasks.length;
    final taskCompletionPct = totalTasksCount > 0 ? (completedTasksCount / totalTasksCount) : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Page Header
          AdminPageHeader(
            title: 'Manufacturing Audits & Reports',
            subtitle: 'Operational analytics, executive summaries, live audit trail, and exportable reports',
            icon: Icons.analytics_outlined,
            trailing: OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(tasksStreamProvider);
                ref.invalidate(inventoryStreamProvider);
                ref.invalidate(productionOrdersStreamProvider);
                ref.invalidate(queriesStreamProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // 2. Report Content
          Expanded(
            child: ResponsiveContainer(
              scrollable: true,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Executive Summary Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF0F2B26), const Color(0xFF133A33)]
                              : [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2DD4BF).withValues(alpha: 0.3) : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Text(
                                'Facility Executive Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Org: $orgId',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _ExecutiveStat(label: 'Workforce', value: '$employeeCount'),
                              _ExecutiveStat(label: 'Materials', value: '$inventoryCount'),
                              _ExecutiveStat(label: 'Active Orders', value: '$activeOrdersCount'),
                              _ExecutiveStat(label: 'Open Tickets', value: '$openQueriesCount', isAlert: openQueriesCount > 0),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Detailed Audit Reports & CSV Export Section
                    Text(
                      'Detailed Audit Reports & CSV Export',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 480;
                        if (isMobile) {
                          return Column(
                            children: [
                              _QuickReportExportTile(
                                title: 'Production Orders',
                                subtitle: 'Throughput & Progress',
                                icon: Icons.precision_manufacturing_rounded,
                                color: theme.colorScheme.primary,
                                isHorizontal: true,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProductionReportScreen()),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              _QuickReportExportTile(
                                title: 'Inventory Balances',
                                subtitle: 'Safety Stock & SKUs',
                                icon: Icons.inventory_2_rounded,
                                color: tokens.warning,
                                isHorizontal: true,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const InventoryReportScreen()),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              _QuickReportExportTile(
                                title: 'Workforce Staff',
                                subtitle: 'Roles & Directory',
                                icon: Icons.people_rounded,
                                color: tokens.info,
                                isHorizontal: true,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EmployeeReportScreen()),
                                  );
                                },
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _QuickReportExportTile(
                                title: 'Production Orders',
                                subtitle: 'Throughput & Progress',
                                icon: Icons.precision_manufacturing_rounded,
                                color: theme.colorScheme.primary,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProductionReportScreen()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickReportExportTile(
                                title: 'Inventory Balances',
                                subtitle: 'Safety Stock & SKUs',
                                icon: Icons.inventory_2_rounded,
                                color: tokens.warning,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const InventoryReportScreen()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickReportExportTile(
                                title: 'Workforce Staff',
                                subtitle: 'Roles & Directory',
                                icon: Icons.people_rounded,
                                color: tokens.info,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EmployeeReportScreen()),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Section 1: Shop-Floor Task Efficiency
                    Text(
                      'Process Task Efficiency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Task Completion Rate',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '$completedTasksCount / $totalTasksCount Completed (${(taskCompletionPct * 100).toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: taskCompletionPct,
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 10),

                          Text(
                            'Stage Distribution',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StageBadge(label: 'Cutting & Forming', count: tasks.where((t) => t.stage.contains('Cutting')).length),
                              _StageBadge(label: 'CNC Machining', count: tasks.where((t) => t.stage.contains('Machining')).length),
                              _StageBadge(label: 'Welding', count: tasks.where((t) => t.stage.contains('Welding')).length),
                              _StageBadge(label: 'Assembly', count: tasks.where((t) => t.stage.contains('Assembly')).length),
                              _StageBadge(label: 'Inspection', count: tasks.where((t) => t.stage.contains('Inspection')).length),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Production Orders Throughput
                    Text(
                      'Production Orders Throughput',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ReportCard(
                            title: 'Active Work Orders',
                            count: '$activeOrdersCount',
                            subtitle: 'In production & scheduled',
                            icon: Icons.precision_manufacturing_rounded,
                            color: tokens.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ReportCard(
                            title: 'Completed Batches',
                            count: '$completedOrdersCount',
                            subtitle: 'Quality inspected & closed',
                            icon: Icons.check_circle_rounded,
                            color: tokens.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section 3: Inventory Stock Health
                    Text(
                      'Inventory Stock Health',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    lowStockCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                    color: lowStockCount > 0 ? tokens.danger : tokens.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    lowStockCount > 0 ? '$lowStockCount Low Stock Alerts' : 'All Stock Balances Optimal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: lowStockCount > 0 ? tokens.danger : tokens.success,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Total: $inventoryCount SKUs',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          if (lowStockCount > 0) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'Items Requiring Procurement:',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            ...materials.where((m) => m.isLowStock).map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '[${item.sku}] ${item.name}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    StatusChip(
                                      label: '${item.quantity.toStringAsFixed(1)} / min ${item.minStockLevel.toStringAsFixed(1)} ${item.unit}',
                                      variant: StatusVariant.error,
                                      icon: Icons.warning_amber_rounded,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 4: Live Activity & Audit Trail
                    Text(
                      'Live Shop-Floor Audit Log',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LiveAuditTrail(orgId: orgId),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveAuditTrail extends ConsumerWidget {
  final String orgId;

  const _LiveAuditTrail({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orgId.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final firestore = ref.watch(firestoreProvider);
    final updatesStream = firestore
        .collection(FirestorePaths.statusUpdatesCollection(orgId))
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: updatesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Center(
              child: Text(
                'No recent status updates logged yet.\nUpdates from operators will appear here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: theme.colorScheme.outline),
            itemBuilder: (context, index) {
              final data = (docs[index].data() as Map<String, dynamic>?) ?? {};
              final worker = data['workerName'] as String? ?? 'Operator';
              final status = data['newStatus'] as String? ?? 'updated';
              final notes = data['notes'] as String? ?? '';
              final timeVal = data['timestamp'];
              DateTime? time;
              if (timeVal is Timestamp) time = timeVal.toDate();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: tokens.primarySoft,
                  child: Icon(Icons.history_rounded, size: 18, color: theme.colorScheme.primary),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        worker,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: status.toUpperCase(),
                      variant: StatusVariant.neutral,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (time != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}/${time.year}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ExecutiveStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isAlert;

  const _ExecutiveStat({
    required this.label,
    required this.value,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isAlert ? const Color(0xFFFBBF24) : Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String count;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ReportCard({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  final String label;
  final int count;

  const _StageBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1728) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReportExportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isHorizontal;

  const _QuickReportExportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: isHorizontal
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}
