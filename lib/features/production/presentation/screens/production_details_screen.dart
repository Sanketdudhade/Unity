import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/production/presentation/widgets/process_stage_actions_dialog.dart';

class ProductionDetailsScreen extends ConsumerStatefulWidget {
  final ProductionOrder order;

  const ProductionDetailsScreen({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<ProductionDetailsScreen> createState() => _ProductionDetailsScreenState();
}

class _ProductionDetailsScreenState extends ConsumerState<ProductionDetailsScreen> {
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

  void _showAssignEmployeeDialog(BuildContext context, String orgId, OrderProcessModel process) {
    final messenger = ScaffoldMessenger.of(context);
    final employees = ref.read(employeesStreamProvider).value ?? [];
    String? selectedUid = process.assignedEmployeeUid.isNotEmpty ? process.assignedEmployeeUid : null;
    String selectedName = process.assignedEmployeeName;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign Operator: ${process.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step ${process.sequence} of ${widget.order.orderNumber}', style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedUid,
                decoration: const InputDecoration(
                  labelText: 'Select Accountable Employee *',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Choose team member...'),
                items: employees.map((emp) {
                  return DropdownMenuItem(
                    value: emp.uid,
                    child: Text('${emp.fullName} (${emp.role.value})'),
                  );
                }).toList(),
                onChanged: (uid) {
                  if (uid != null) {
                    final match = employees.firstWhere((e) => e.uid == uid);
                    setDialogState(() {
                      selectedUid = uid;
                      selectedName = match.fullName;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving || selectedUid == null
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(productionRepositoryProvider).assignEmployeeToProcess(
                          orgId: orgId,
                          orderId: widget.order.id,
                          processId: process.id,
                          employeeUid: selectedUid!,
                          employeeName: selectedName,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Assigned $selectedName to ${process.name}.'),
                              backgroundColor: AppColors.secondary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Assign Operator'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';
    final processesAsync = ref.watch(orderProcessesStreamProvider(widget.order.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.order.orderNumber),
      ),
      body: processesAsync.when(
        loading: () => const LoadingWidget(message: 'Loading process workflow...'),
        error: (err, _) => Center(
          child: Text('Error loading processes: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (processes) {
          final stepStatusMap = {for (final p in processes) p.sequence: p.status};
          final completedCount = processes.where((p) => p.isCompleted).length;
          final totalCount = processes.length;
          final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
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
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.order.orderNumber,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.order.priority.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.secondaryDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Target: ${widget.order.targetQuantity.toStringAsFixed(0)} ${widget.order.unit}',
                          style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(widget.order.productName, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 8),
                    if (widget.order.dueDate != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.event_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${FactoryDateUtils.formatFactoryDate(widget.order.dueDate)} (IST)',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Workflow Progress', style: AppTextStyles.labelSmall),
                        Text(
                          '$completedCount / $totalCount Stages (${(progressRatio * 100).toStringAsFixed(0)}%)',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Sequential Manufacturing Stages', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Later stages remain locked until prerequisite stages are approved and completed.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              if (processes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text('No stages snapshotted for this work order.'),
                  ),
                )
              else
                ...processes.map((proc) {
                  final isUnlocked = proc.isUnlocked(stepStatusMap);
                  final statusColor = _getStatusColor(proc.status);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ProcessStageActionsDialog.show(
                        context,
                        order: widget.order,
                        process: proc,
                        allStageStatuses: stepStatusMap,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                      color: isUnlocked ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: proc.isInProgress
                            ? AppColors.info
                            : (isUnlocked ? AppColors.border : AppColors.borderSubtle),
                        width: proc.isInProgress ? 1.5 : 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Step ${proc.sequence}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  proc.name,
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: isUnlocked ? AppColors.textPrimary : AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isUnlocked && proc.isNotStarted) ...[
                                      const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      isUnlocked ? proc.status : 'LOCKED',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: isUnlocked ? statusColor : AppColors.textMuted,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Operator: ${proc.assignedEmployeeName}',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                              if (proc.dependsOnStepSequence.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.link_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Prerequisite: Step ${proc.dependsOnStepSequence.join(", ")}',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ],
                          ),

                          if (!isUnlocked) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Locked: Prerequisite Step ${proc.dependsOnStepSequence.join(", ")} must be approved first.',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],

                          if (proc.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Notes: ${proc.notes}', style: AppTextStyles.bodySmall),
                          ],

                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showAssignEmployeeDialog(context, orgId, proc),
                                icon: const Icon(Icons.person_add_alt_1_outlined, size: 14),
                                label: const Text('Assign'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: AppTextStyles.labelSmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ProcessStageActionsDialog.show(
                                    context,
                                    order: widget.order,
                                    process: proc,
                                    allStageStatuses: stepStatusMap,
                                  );
                                },
                                icon: const Icon(Icons.touch_app_outlined, size: 14),
                                label: const Text('Actions & Logs'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: AppTextStyles.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
