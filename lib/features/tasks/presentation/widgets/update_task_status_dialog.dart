import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';

/// Interactive modal allowing shop-floor operators to transition task status and log completion notes.
class UpdateTaskStatusDialog extends ConsumerStatefulWidget {
  final ProcessTask? initialTask;

  const UpdateTaskStatusDialog({
    super.key,
    this.initialTask,
  });

  static Future<void> show(BuildContext context, {ProcessTask? task}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateTaskStatusDialog(initialTask: task),
    );
  }

  @override
  ConsumerState<UpdateTaskStatusDialog> createState() => _UpdateTaskStatusDialogState();
}

class _UpdateTaskStatusDialogState extends ConsumerState<UpdateTaskStatusDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  ProcessTask? _selectedTask;
  String _selectedStatus = 'in_progress';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTask = widget.initialTask;
    if (_selectedTask != null) {
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
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'pending':
      default:
        return AppColors.accent;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'paused':
        return 'Paused / Blocked';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  Future<void> _submitUpdate() {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;

    if (orgId == null || orgId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cannot update task: Organization ID missing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return Future.value();
    }

    if (_selectedTask == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select an active task to update.'),
          backgroundColor: AppColors.error,
        ),
      );
      return Future.value();
    }

    setState(() => _isSubmitting = true);

    return ref.read(taskRepositoryProvider).updateTaskStatus(
      orgId: orgId,
      taskId: _selectedTask!.id,
      newStatus: _selectedStatus,
      workerName: user?.fullName ?? 'Worker',
      notes: _notesController.text.trim(),
    ).then((_) {
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
    }).catchError((err) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $err'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final allTasks = tasksAsync.value ?? [];

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.update_rounded, color: AppColors.secondary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Update Process Status', style: AppTextStyles.titleMedium),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.initialTask == null) ...[
                  const Text('Select Task / Work Order', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 6),
                  if (allTasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No tasks available in facility queue.', style: AppTextStyles.bodySmall),
                    )
                  else
                    DropdownButtonFormField<ProcessTask>(
                      initialValue: _selectedTask,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: allTasks.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(
                            '[${t.workOrder}] ${t.title}',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium,
                          ),
                        );
                      }).toList(),
                      onChanged: (task) {
                        if (task != null) {
                          setState(() {
                            _selectedTask = task;
                            _selectedStatus = task.status;
                            _notesController.text = task.notes;
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 16),
                ] else ...[
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
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
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
