import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/production/presentation/widgets/process_stage_actions_dialog.dart';
import 'package:unity/features/tasks/presentation/widgets/update_task_status_dialog.dart';

/// Modern Enterprise card representing an assigned manufacturing process stage.
/// Conforms to Section 5D & 5E: Clear representation of steps, progress, rework, and one-touch actions.
class AssignedStageCard extends ConsumerWidget {
  final OrderProcessModel stage;
  final ProductionOrder? order;

  const AssignedStageCard({
    super.key,
    required this.stage,
    this.order,
  });

  Color _getStatusColor(BuildContext context, String status) {
    final tokens = context.adminTokens;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return tokens.success;
      case 'IN_PROGRESS':
        return tokens.info;
      case 'PENDING_APPROVAL':
        return tokens.warning;
      case 'ASSIGNED':
        return const Color(0xFF0F766E);
      case 'BLOCKED':
      case 'REWORK_REQUIRED':
        return tokens.danger;
      case 'NOT_STARTED':
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final user = ref.watch(authStateProvider).user;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    final cardBg = isDark ? const Color(0xFF152235) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);
    final statusColor = _getStatusColor(context, stage.status);

    final isRework = stage.status == 'REWORK_REQUIRED';
    final isInProgress = stage.isInProgress;

    final cardBorder = isRework
        ? tokens.danger
        : (isInProgress
            ? statusColor.withValues(alpha: 0.6)
            : (isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)));

    final targetOrder = order ??
        ProductionOrder(
          id: stage.orderId,
          orderNumber: stage.orderId.isNotEmpty ? stage.orderId : 'WO-ACTIVE',
          productName: 'Production Batch',
          targetQuantity: stage.targetQty.toDouble(),
          completedQuantity: stage.completedQty.toDouble(),
          unit: 'PCS',
          status: 'in_production',
          priority: 'normal',
          startDate: DateTime.now(),
        );

    final pct = stage.targetQty > 0
        ? (stage.completedQty / stage.targetQty).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorder,
          width: (isInProgress || isRework) ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Step Sequence, Stage Title, and Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Step ${stage.sequence}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stage.name,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  stage.status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 2. Order Number & Product Info
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 14, color: textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${targetOrder.orderNumber} • ${targetOrder.productName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Output Progress: Completed vs Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: ${stage.completedQty} / ${stage.targetQty} ${targetOrder.unit}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
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
              backgroundColor: isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          // 4. Rework Alert Banner
          if (isRework && stage.reworkReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.danger.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: tokens.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rework Required: ${stage.reworkReason}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 5. Action Buttons Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (stage.isNotStarted || stage.status == 'ASSIGNED')
                ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(productionRepositoryProvider).updateProcessStatus(
                        orgId: user?.organizationId ?? '',
                        orderId: stage.orderId.isNotEmpty ? stage.orderId : targetOrder.id,
                        processId: stage.id,
                        newStatus: 'IN_PROGRESS',
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Started work on Step ${stage.sequence}: ${stage.name}'),
                          backgroundColor: tokens.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Cannot start stage: $e'),
                          backgroundColor: tokens.danger,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Start Working'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                )
              else if (stage.status == 'BLOCKED')
                ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(productionRepositoryProvider).updateProcessStatus(
                        orgId: user?.organizationId ?? '',
                        orderId: stage.orderId.isNotEmpty ? stage.orderId : targetOrder.id,
                        processId: stage.id,
                        newStatus: 'IN_PROGRESS',
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Resumed work on Step ${stage.sequence}: ${stage.name}'),
                          backgroundColor: tokens.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Cannot resume: $e'),
                          backgroundColor: tokens.danger,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Resume Working'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                )
              else if (isInProgress)
                OutlinedButton.icon(
                  onPressed: () => UpdateTaskStatusDialog.show(context, stage: stage),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Update Status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                    side: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),

              ElevatedButton.icon(
                onPressed: () {
                  ProcessStageActionsDialog.show(
                    context,
                    order: targetOrder,
                    process: stage.orderId.isNotEmpty ? stage : stage.copyWith(orderId: targetOrder.id),
                    allStageStatuses: {stage.sequence: stage.status},
                  );
                },
                icon: const Icon(Icons.touch_app_rounded, size: 16),
                label: const Text('Stage Actions & Output (+Units)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E2B41) : const Color(0xFF142238),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
