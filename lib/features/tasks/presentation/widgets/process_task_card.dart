import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/presentation/widgets/record_material_usage_dialog.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/tasks/presentation/widgets/update_task_status_dialog.dart';

/// Modern Enterprise card displaying a shop-floor process task with live stage transitions.
/// Conforms to Section 3, 5C & 6: Full Dark & Light theme support with responsive actions.
class ProcessTaskCard extends ConsumerWidget {
  final ProcessTask task;

  const ProcessTaskCard({
    super.key,
    required this.task,
  });

  Color _getStatusColor(BuildContext context, String status) {
    final tokens = context.adminTokens;
    switch (status.toLowerCase()) {
      case 'in_progress':
        return const Color(0xFF2563EB);
      case 'paused':
        return tokens.warning;
      case 'completed':
        return tokens.success;
      case 'pending':
      default:
        return const Color(0xFF0F766E);
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'paused':
        return 'PAUSED';
      case 'completed':
        return 'COMPLETED';
      case 'pending':
      default:
        return 'PENDING';
    }
  }

  Future<void> _quickStatusTransition(BuildContext context, WidgetRef ref, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    final tokens = context.adminTokens;
    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;

    if (orgId == null || orgId.isEmpty) return;

    try {
      await ref.read(taskRepositoryProvider).updateTaskStatus(
        orgId: orgId,
        taskId: task.id,
        newStatus: newStatus,
        workerName: user?.fullName ?? 'Worker',
        notes: newStatus == 'in_progress' ? 'Resumed from terminal' : 'Marked completed on shop-floor',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Task [${task.workOrder}] marked as ${_formatStatusLabel(newStatus)}'),
          backgroundColor: newStatus == 'completed' ? tokens.success : const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: tokens.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    final cardBg = isDark ? const Color(0xFF152235) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);
    final statusColor = _getStatusColor(context, task.status);

    final isUrgent = task.priority.toLowerCase() == 'urgent';
    final isHigh = task.priority.toLowerCase() == 'high';

    final cardBorder = task.isInProgress
        ? statusColor.withValues(alpha: 0.6)
        : (isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBorder,
          width: task.isInProgress ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Work Order, Priority Badge, Status Badge (Responsive Wrap)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.workOrder,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (isUrgent || isHigh)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isUrgent ? tokens.danger : tokens.warning).withValues(alpha: isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUrgent ? 'URGENT' : 'HIGH PRIORITY',
                          style: TextStyle(
                            color: isUrgent ? tokens.danger : tokens.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatStatusLabel(task.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Task Title
            Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isMobile ? 14 : 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Stage and Assigned Info
            Row(
              children: [
                Icon(Icons.precision_manufacturing_outlined, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  flex: 3,
                  child: Text(
                    task.stage,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  flex: 2,
                  child: Text(
                    task.assignedToName.isNotEmpty ? task.assignedToName : 'Shop-Floor',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Notes if any
            if (task.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.notes,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => UpdateTaskStatusDialog.show(context, task: task),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Update Status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                    side: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => RecordMaterialUsageDialog.show(context, workOrder: task.workOrder),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Log Material'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    side: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!task.isInProgress && !task.isCompleted)
                  ElevatedButton.icon(
                    onPressed: () => _quickStatusTransition(context, ref, 'in_progress'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Start / Resume'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (task.isInProgress)
                  ElevatedButton.icon(
                    onPressed: () => _quickStatusTransition(context, ref, 'completed'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Mark Complete'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      backgroundColor: tokens.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
