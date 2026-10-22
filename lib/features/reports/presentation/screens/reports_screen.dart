import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manufacturing Audits & Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh Reports',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(tasksStreamProvider);
              ref.invalidate(inventoryStreamProvider);
              ref.invalidate(productionOrdersStreamProvider);
              ref.invalidate(queriesStreamProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Executive Summary Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Facility Executive Summary',
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Org: $orgId',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.secondaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
          Text('Detailed Audit Reports & CSV Export', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickReportExportTile(
                  title: 'Production Orders',
                  subtitle: 'Throughput & Progress',
                  icon: Icons.precision_manufacturing_rounded,
                  color: AppColors.primary,
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
                  color: AppColors.secondary,
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
                  color: AppColors.info,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeReportScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 1: Shop-Floor Task Efficiency
          Text('Process Task Efficiency', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Task Completion Rate', style: AppTextStyles.labelMedium),
                    Text(
                      '$completedTasksCount / $totalTasksCount Completed (${(taskCompletionPct * 100).toStringAsFixed(0)}%)',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: taskCompletionPct,
                    minHeight: 10,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 10),

                Text('Stage Distribution', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
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
          Text('Production Orders Throughput', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReportCard(
                  title: 'Active Work Orders',
                  count: '$activeOrdersCount',
                  subtitle: 'In production & scheduled',
                  icon: Icons.precision_manufacturing_rounded,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportCard(
                  title: 'Completed Batches',
                  count: '$completedOrdersCount',
                  subtitle: 'Quality inspected & closed',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 3: Inventory Health & Replenishment
          Text('Inventory Stock Health', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          lowStockCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                          color: lowStockCount > 0 ? AppColors.error : AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lowStockCount > 0 ? '$lowStockCount Low Stock Alerts' : 'All Stock Balances Optimal',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: lowStockCount > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    Text('Total: $inventoryCount SKUs', style: AppTextStyles.labelSmall),
                  ],
                ),
                if (lowStockCount > 0) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('Items Requiring Procurement:', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
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
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.quantity.toStringAsFixed(1)} / min ${item.minStockLevel.toStringAsFixed(1)} ${item.unit}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
          Text('Live Shop-Floor Audit Log', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          _LiveAuditTrail(orgId: orgId),
          const SizedBox(height: 32),
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'No recent status updates logged yet.\nUpdates from operators will appear here automatically.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
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
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(worker, style: AppTextStyles.titleSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.secondaryDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notes, style: AppTextStyles.bodySmall),
                    ],
                    if (time != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}/${time.year}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted, fontSize: 10),
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
            style: AppTextStyles.titleLarge.copyWith(
              color: isAlert ? AppColors.warningLight : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.labelMedium),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: AppTextStyles.titleLarge.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.labelSmall.copyWith(
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

  const _QuickReportExportTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

