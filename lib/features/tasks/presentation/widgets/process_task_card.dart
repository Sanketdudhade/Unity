import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/presentation/widgets/record_material_usage_dialog.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/tasks/presentation/widgets/update_task_status_dialog.dart';

/// Industrial card displaying a shop-floor process task with live stage transitions.
class ProcessTaskCard extends ConsumerWidget {
  final ProcessTask task;

  const ProcessTaskCard({
    super.key,
    required this.task,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return AppColors.info;
      case 'paused':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'pending':
      default:
        return AppColors.secondary;
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
          backgroundColor: newStatus == 'completed' ? AppColors.success : AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(task.status);
    final isUrgent = task.priority.toLowerCase() == 'urgent';
    final isHigh = task.priority.toLowerCase() == 'high';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isInProgress ? AppColors.info.withValues(alpha: 0.5) : AppColors.border,
          width: task.isInProgress ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Work Order, Priority Badge, Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.workOrder,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isUrgent || isHigh) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isUrgent ? AppColors.errorLight : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isUrgent ? 'URGENT' : 'HIGH PRIORITY',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isUrgent ? AppColors.error : AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
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
                        style: AppTextStyles.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
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
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Stage and Assigned Info
            Row(
              children: [
                const Icon(Icons.precision_manufacturing_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  task.stage,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  task.assignedToName.isNotEmpty ? task.assignedToName : 'Shop-Floor',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.notes,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: AppTextStyles.labelSmall,
                    foregroundColor: AppColors.secondaryDark,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => RecordMaterialUsageDialog.show(context, workOrder: task.workOrder),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Log Material'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: AppTextStyles.labelSmall,
                    foregroundColor: AppColors.accentDark,
                  ),
                ),
                if (!task.isInProgress && !task.isCompleted)
                  ElevatedButton.icon(
                    onPressed: () => _quickStatusTransition(context, ref, 'in_progress'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Start / Resume'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: AppTextStyles.labelSmall,
                      backgroundColor: AppColors.info,
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
                      textStyle: AppTextStyles.labelSmall,
                      backgroundColor: AppColors.success,
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
