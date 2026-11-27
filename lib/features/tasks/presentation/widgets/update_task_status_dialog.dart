import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';

/// Interactive modal allowing shop-floor operators to transition process stage/task status and log progress notes.
class UpdateTaskStatusDialog extends ConsumerStatefulWidget {
  final ProcessTask? initialTask;
  final OrderProcessModel? initialStage;

  const UpdateTaskStatusDialog({
    super.key,
    this.initialTask,
    this.initialStage,
  });

  static Future<void> show(
    BuildContext context, {
    ProcessTask? task,
    OrderProcessModel? stage,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateTaskStatusDialog(initialTask: task, initialStage: stage),
    );
  }

  @override
  ConsumerState<UpdateTaskStatusDialog> createState() => _UpdateTaskStatusDialogState();
}

class _UpdateTaskStatusDialogState extends ConsumerState<UpdateTaskStatusDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  ProcessTask? _selectedTask;
  OrderProcessModel? _selectedStage;
  String _selectedStatus = 'in_progress';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTask = widget.initialTask;
    _selectedStage = widget.initialStage;

    if (_selectedStage != null) {
      _selectedStatus = _selectedStage!.status.toLowerCase();
      _notesController.text = _selectedStage!.notes;
    } else if (_selectedTask != null) {
      _selectedStatus = _selectedTask!.status;
      _notesController.text = _selectedTask!.notes;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return AppColors.info;
      case 'paused':
      case 'blocked':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'pending':
      case 'pending_approval':
      case 'assigned':
      case 'not_started':
      default:
        return AppColors.accent;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'paused':
      case 'blocked':
        return 'Paused / Blocked';
      case 'completed':
        return 'Completed';
      case 'pending':
      case 'pending_approval':
        return 'Pending Approval / Sign-off';
      case 'assigned':
        return 'Assigned';
      case 'not_started':
        return 'Not Started';
      default:
        return status;
    }
  }

  Future<void> _submitUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;

    if (orgId == null || orgId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cannot update status: Organization ID missing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTask == null && _selectedStage == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select an active stage or task to update.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_selectedStage != null) {
        final upper = _selectedStatus.toUpperCase();
        final mappedStatus = upper == 'PAUSED'
            ? 'BLOCKED'
            : (upper == 'PENDING' ? 'PENDING_APPROVAL' : upper);

        await ref.read(productionRepositoryProvider).updateProcessStatus(
              orgId: orgId,
              orderId: _selectedStage!.orderId,
              processId: _selectedStage!.id,
              newStatus: mappedStatus,
              notes: _notesController.text.trim(),
            );

        if (mounted) {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Stage Step ${_selectedStage!.sequence} (${_selectedStage!.name}) updated to ${_formatStatusLabel(_selectedStatus)}.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else if (_selectedTask != null) {
        await ref.read(taskRepositoryProvider).updateTaskStatus(
              orgId: orgId,
              taskId: _selectedTask!.id,
              newStatus: _selectedStatus,
              workerName: user?.fullName ?? 'Worker',
              notes: _notesController.text.trim(),
            );

        if (mounted) {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Task [${_selectedTask!.workOrder}] updated to ${_formatStatusLabel(_selectedStatus)}.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update: $err'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final allTasks = tasksAsync.value ?? [];
    final assignedStagesAsync = ref.watch(employeeAssignedProcessesStreamProvider);
    final assignedStages = assignedStagesAsync.value ?? [];
    final orders = ref.watch(productionOrdersStreamProvider).value ?? [];

    final hasStages = assignedStages.isNotEmpty;
    final hasTasks = allTasks.isNotEmpty;

    // If task was passed, check if it maps to an active stage
    if (_selectedStage == null && _selectedTask != null) {
      final matchingStage = assignedStages.cast<OrderProcessModel?>().firstWhere(
            (s) => s != null && (s.id == _selectedTask!.id || s.name == _selectedTask!.stage),
            orElse: () => null,
          );
      if (matchingStage != null) {
        _selectedStage = matchingStage;
        _selectedTask = null;
        _selectedStatus = _selectedStage!.status.toLowerCase();
        _notesController.text = _selectedStage!.notes;
      }
    }

    // Auto-select first stage if nothing selected yet
    if (_selectedStage == null && _selectedTask == null && widget.initialStage == null && widget.initialTask == null) {
      if (hasStages) {
        _selectedStage = assignedStages.first;
        _selectedStatus = _selectedStage!.status.toLowerCase();
        _notesController.text = _selectedStage!.notes;
      } else if (hasTasks) {
        _selectedTask = allTasks.first;
        _selectedStatus = _selectedTask!.status;
        _notesController.text = _selectedTask!.notes;
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.update_rounded, color: Color(0xFF0F766E), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update Process Working Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.initialTask == null && widget.initialStage == null) ...[
                  const Text('Select Assigned Stage or Task', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  if (!hasStages && !hasTasks)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No active stages or tasks currently assigned to your station queue.', style: AppTextStyles.bodySmall),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStage != null
                          ? 'stage_${_selectedStage!.id}'
                          : (_selectedTask != null ? 'task_${_selectedTask!.id}' : null),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        ...assignedStages.map((s) {
                          final matchingOrder = orders.cast<ProductionOrder?>().firstWhere(
                            (o) => o != null && (o.id == s.orderId || o.orderNumber == s.orderId),
                            orElse: () => null,
                          );
                          final orderLabel = matchingOrder?.orderNumber ?? s.orderId;
                          return DropdownMenuItem<String>(
                            value: 'stage_${s.id}',
                            child: Text(
                              '[Stage ${s.sequence}] ${s.name} ($orderLabel)',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          );
                        }),
                        ...allTasks.map((t) {
                          return DropdownMenuItem<String>(
                            value: 'task_${t.id}',
                            child: Text(
                              '[Task] [${t.workOrder}] ${t.title}',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          if (val.startsWith('stage_')) {
                            final id = val.replaceFirst('stage_', '');
                            _selectedStage = assignedStages.firstWhere((s) => s.id == id);
                            _selectedTask = null;
                            _selectedStatus = _selectedStage!.status.toLowerCase();
                            _notesController.text = _selectedStage!.notes;
                          } else if (val.startsWith('task_')) {
                            final id = val.replaceFirst('task_', '');
                            _selectedTask = allTasks.firstWhere((t) => t.id == id);
                            _selectedStage = null;
                            _selectedStatus = _selectedTask!.status;
                            _notesController.text = _selectedTask!.notes;
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                ] else if (widget.initialStage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Stage Step ${widget.initialStage!.sequence}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(widget.initialStage!.status).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatStatusLabel(widget.initialStage!.status),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: _getStatusColor(widget.initialStage!.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(widget.initialStage!.name, style: AppTextStyles.titleSmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (widget.initialTask != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.initialTask!.workOrder,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(widget.initialTask!.status).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatStatusLabel(widget.initialTask!.status),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: _getStatusColor(widget.initialTask!.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(widget.initialTask!.title, style: AppTextStyles.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Stage: ${widget.initialTask!.stage}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text('New Stage Status', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChipOption(
                      label: 'In Progress',
                      value: 'in_progress',
                      isSelected: _selectedStatus == 'in_progress',
                      color: AppColors.info,
                      icon: Icons.play_arrow_rounded,
                      onTap: () => setState(() => _selectedStatus = 'in_progress'),
                    ),
                    _StatusChipOption(
                      label: 'Paused',
                      value: 'paused',
                      isSelected: _selectedStatus == 'paused',
                      color: AppColors.warning,
                      icon: Icons.pause_rounded,
                      onTap: () => setState(() => _selectedStatus = 'paused'),
                    ),
                    _StatusChipOption(
                      label: 'Completed',
                      value: 'completed',
                      isSelected: _selectedStatus == 'completed',
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                      onTap: () => setState(() => _selectedStatus = 'completed'),
                    ),
                    _StatusChipOption(
                      label: 'Pending',
                      value: 'pending',
                      isSelected: _selectedStatus == 'pending',
                      color: AppColors.accent,
                      icon: Icons.schedule_rounded,
                      onTap: () => setState(() => _selectedStatus = 'pending'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                const Text('Progress Log / Worker Notes', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Cut 50 brackets; tolerance verified +/- 0.02mm',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update Status'),
        ),
      ],
    );
  }
}

class _StatusChipOption extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatusChipOption({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
