import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/process_update_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';

/// Modal dialog providing interactive workflow actions and daily update logging for a manufacturing stage.
class ProcessStageActionsDialog extends ConsumerStatefulWidget {
  final ProductionOrder order;
  final OrderProcessModel process;
  final Map<int, String> allStageStatuses;

  const ProcessStageActionsDialog({
    super.key,
    required this.order,
    required this.process,
    required this.allStageStatuses,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductionOrder order,
    required OrderProcessModel process,
    required Map<int, String> allStageStatuses,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProcessStageActionsDialog(
        order: order,
        process: process,
        allStageStatuses: allStageStatuses,
      ),
    );
  }

  @override
  ConsumerState<ProcessStageActionsDialog> createState() => _ProcessStageActionsDialogState();
}

class _ProcessStageActionsDialogState extends ConsumerState<ProcessStageActionsDialog> {
  bool _isSaving = false;
  bool _showLogOutputForm = false;
  bool _showBlockerForm = false;

  String get _effectiveOrderId =>
      widget.process.orderId.isNotEmpty ? widget.process.orderId : widget.order.id;

  final TextEditingController _deltaQtyController = TextEditingController(text: '0');
  final TextEditingController _hoursSpentController = TextEditingController(text: '4.0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _blockerReasonController = TextEditingController();

  @override
  void dispose() {
    _deltaQtyController.dispose();
    _hoursSpentController.dispose();
    _notesController.dispose();
    _blockerReasonController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF16A34A); // Done (Green)
      case 'IN_PROGRESS':
      case 'PENDING_APPROVAL':
        return const Color(0xFFD97706); // Working (Amber)
      case 'BLOCKED':
      case 'REWORK_REQUIRED':
        return AppColors.error;
      case 'ASSIGNED':
      case 'NOT_STARTED':
      default:
        return const Color(0xFF64748B); // Pending (Slate)
    }
  }

  void _showChangeOperatorDialog(
    BuildContext context,
    String orgId,
    List<AppUserModel> activeEmployees,
  ) {
    String? selectedUid = widget.process.assignedEmployeeUid.isNotEmpty ? widget.process.assignedEmployeeUid : null;
    String selectedName = widget.process.assignedEmployeeName.isNotEmpty ? widget.process.assignedEmployeeName : 'Unassigned';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Assign Stage Operator', style: AppTextStyles.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select accountable employee for Step ${widget.process.sequence}: ${widget.process.name}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: selectedUid != null && activeEmployees.any((e) => e.uid == selectedUid) ? selectedUid : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assigned Operator',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_pin_rounded),
                ),
                hint: const Text('Unassigned', overflow: TextOverflow.ellipsis),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Unassigned', overflow: TextOverflow.ellipsis)),
                  ...activeEmployees.map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.uid,
                      child: Text('${e.fullName} (${e.role.value})', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (uid) {
                  setDialogState(() {
                    selectedUid = uid;
                    if (uid != null) {
                      selectedName = activeEmployees.firstWhere((e) => e.uid == uid).fullName;
                    } else {
                      selectedName = 'Unassigned';
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(productionRepositoryProvider).assignEmployeeToProcess(
                      orgId: orgId,
                      orderId: _effectiveOrderId,
                      processId: widget.process.id,
                      employeeUid: selectedUid ?? '',
                      employeeName: selectedName,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stage operator updated to $selectedName!'),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
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
    final isAdmin = user?.role.isAdmin ?? false;

    final currentUid = user?.uid.trim() ?? '';
    final assignedUid = widget.process.assignedEmployeeUid.trim();
    final currentName = (user?.fullName ?? '').trim().toLowerCase();
    final assignedName = widget.process.assignedEmployeeName.trim().toLowerCase();

    final isAssignedToMe = (currentUid.isNotEmpty && currentUid == assignedUid) ||
        (currentName.isNotEmpty && assignedName.isNotEmpty && currentName == assignedName);
    final canPerformActions = isAdmin || isAssignedToMe || assignedUid.isEmpty;

    // Real-time sibling stage status lookup from Firestore so prerequisite checks never fail falsely
    final allProcessesAsync = ref.watch(orderProcessesStreamProvider(_effectiveOrderId));
    final Map<int, String> resolvedStatuses = Map.from(widget.allStageStatuses);
    if (allProcessesAsync.hasValue && allProcessesAsync.value != null) {
      for (final p in allProcessesAsync.value!) {
        resolvedStatuses[p.sequence] = p.status;
      }
    }

    final isUnlocked = widget.process.isUnlocked(resolvedStatuses);
    final statusColor = _getStatusColor(widget.process.status);
    final updatesAsync = ref.watch(processUpdatesStreamProvider((
      orderId: _effectiveOrderId,
      processId: widget.process.id,
    )));

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Step ${widget.process.sequence}',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.process.name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${widget.order.orderNumber} • ${widget.order.productName}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              widget.process.status.replaceAll('_', ' '),
              style: AppTextStyles.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sequential Lock Status Banner
              if (!isUnlocked)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'STAGE LOCKED: Cannot advance until prerequisite Step(s) ${widget.process.dependsOnStepSequence.join(', ')} are completed and approved.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Rework Reason Banner
              if (widget.process.status == 'REWORK_REQUIRED' &&
                  widget.process.reworkReason.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.assignment_return_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SUPERVISOR REWORK REQUIRED',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.process.reworkReason,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Metric Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Batch Progress', style: AppTextStyles.titleSmall),
                        Text(
                          '${widget.process.completedQty} / ${widget.process.targetQty} ${widget.order.unit}',
                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.process.targetQty > 0
                            ? (widget.process.completedQty / widget.process.targetQty).clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 8,
                        backgroundColor: AppColors.borderSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final employeesAsync = ref.watch(employeesStreamProvider);
                            final employees = employeesAsync.value ?? [];
                            final activeEmployees = employees.where((e) => e.isActive).toList();

                            if (!isAdmin) {
                              return Text(
                                'Assigned: ${widget.process.assignedEmployeeName.isNotEmpty ? widget.process.assignedEmployeeName : "Unassigned"}',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              );
                            }

                            return InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => _showChangeOperatorDialog(context, orgId, activeEmployees),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_pin_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Operator: ${widget.process.assignedEmployeeName.isNotEmpty ? widget.process.assignedEmployeeName : "Unassigned"}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                                ],
                              ),
                            );
                          },
                        ),
                        if (widget.process.dueAt != null)
                          Text(
                            'Due: ${FactoryDateUtils.formatFactoryDate(widget.process.dueAt!)}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Station Actions Section
              Text('Station Actions', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),

              if (!canPerformActions) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Station actions are reserved for the assigned operator (${widget.process.assignedEmployeeName.isNotEmpty ? widget.process.assignedEmployeeName : "Unassigned"}) or administrators.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Informational Status Banners for finished or waiting stages
                if (widget.process.isCompleted) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stage Operations Completed',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'All work and quality checks for this stage are signed off and verified.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (widget.process.status == 'PENDING_APPROVAL') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Awaiting Supervisor Approval',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stage has been submitted for review. Awaiting quality sign-off to unlock the next manufacturing stage.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 1. Start Stage Button
                    if (widget.process.isNotStarted || widget.process.status == 'ASSIGNED') ...[
                      ElevatedButton.icon(
                        onPressed: (!isUnlocked || _isSaving)
                            ? null
                            : () => _handleTransitionStatus('IN_PROGRESS'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Start Operation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (isAdmin && isUnlocked)
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : () => _handleAdminApprove(orgId, user!),
                          icon: const Icon(Icons.verified_rounded, size: 18),
                          label: const Text('Direct Sign-off'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.success,
                          ),
                        ),
                    ],

                    // 2. Active Stage Buttons (IN_PROGRESS or REWORK_REQUIRED)
                    if (widget.process.isInProgress || widget.process.status == 'REWORK_REQUIRED') ...[
                      ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => setState(() {
                                  _showLogOutputForm = !_showLogOutputForm;
                                  _showBlockerForm = false;
                                }),
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: Text(_showLogOutputForm ? 'Hide Log Form' : 'Log Output (+Qty)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => setState(() {
                                  _showBlockerForm = !_showBlockerForm;
                                  _showLogOutputForm = false;
                                }),
                        icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                        label: Text(_showBlockerForm ? 'Hide Form' : 'Report Blocker'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _handleSubmitForApproval(),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Submit Sign-off'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (isAdmin)
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _handleAdminApprove(orgId, user!),
                          icon: const Icon(Icons.verified_rounded, size: 18),
                          label: const Text('Direct Sign-off'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],

                    // 3. Pending Approval Actions
                    if (widget.process.status == 'PENDING_APPROVAL') ...[
                      ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => setState(() {
                                  _showLogOutputForm = !_showLogOutputForm;
                                  _showBlockerForm = false;
                                }),
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: Text(_showLogOutputForm ? 'Hide Form' : 'Add Note / Remark'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : () => _handleTransitionStatus('IN_PROGRESS'),
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Return to In Progress'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                      if (isAdmin) ...[
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _handleAdminApprove(orgId, user!),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text('Approve Stage'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : () => _showRejectDialog(orgId, user!),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Request Rework'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      ],
                    ],

                    // 4. Completed Stage Actions
                    if (widget.process.isCompleted) ...[
                      ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => setState(() {
                                  _showLogOutputForm = !_showLogOutputForm;
                                  _showBlockerForm = false;
                                }),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: Text(_showLogOutputForm ? 'Hide Form' : 'Log Output / Note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (isAdmin) ...[
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _confirmReopenStage,
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text('Reopen Stage'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : () => _showRejectDialog(orgId, user!),
                          icon: const Icon(Icons.assignment_return_outlined, size: 18),
                          label: const Text('Request Rework'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      ],
                    ],

                    // 5. Resume from Blocked
                    if (widget.process.status == 'BLOCKED')
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _handleTransitionStatus('IN_PROGRESS'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Clear Blocker & Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inline Log Output Form
                if (_showLogOutputForm)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.process.isCompleted ? 'Log Audit Entry / Remarks' : 'Log Daily Output',
                          style: AppTextStyles.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _deltaQtyController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Produced Today *',
                                  suffixText: widget.order.unit,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _hoursSpentController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Hours Spent',
                                  suffixText: 'hrs',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Daily Progress Notes / Station Remarks',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _showLogOutputForm = false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveDailyUpdate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: _isSaving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(widget.process.isCompleted ? 'Save Audit Entry' : 'Save Output Entry'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Inline Blocker Form
                if (_showBlockerForm)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report Station Blocker', style: AppTextStyles.titleSmall.copyWith(color: AppColors.error)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _blockerReasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Reason for hold/blocker *',
                            hintText: 'e.g. Tooling wear, raw material delay, power interruption',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _showBlockerForm = false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveBlockerUpdate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                              ),
                              child: _isSaving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Halt & Mark Blocked'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Admin Sign-off & Quality Inspection Actions
              if (isAdmin) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text('Supervisor / Quality Sign-off', style: AppTextStyles.titleSmall),
                const SizedBox(height: 8),

                if (widget.process.isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.successLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Quality sign-off verified. Stage marked complete and approved.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (widget.process.status == 'PENDING_APPROVAL') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.rate_review_rounded, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stage submitted by operator. Awaiting your approval to unlock the next manufacturing stage.',
                            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _handleAdminApprove(orgId, user!),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text('Approve Stage'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : () => _showRejectDialog(orgId, user!),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Request Rework'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Assign/Reassign Employee dropdown
                _EmployeeAssignRow(
                  orgId: orgId,
                  orderId: _effectiveOrderId,
                  processId: widget.process.id,
                  currentAssignedUid: widget.process.assignedEmployeeUid,
                  currentAssignedName: widget.process.assignedEmployeeName,
                  isAdmin: isAdmin,
                ),
                const SizedBox(height: 16),
              ],

              // Daily Updates Audit Stream
              const Divider(),
              const SizedBox(height: 8),
              Text('Stage Daily Logs & Audit Trail', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),

              updatesAsync.when(
                loading: () => const LoadingWidget(message: 'Loading updates...'),
                error: (e, _) => Text('Error loading updates: $e', style: AppTextStyles.bodySmall),
                data: (updates) {
                  if (updates.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: Text(
                        'No daily updates logged for this stage yet.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < updates.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        () {
                          final u = updates[i];
                          final isRework = u.hasBlocker;

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isRework ? AppColors.errorLight.withValues(alpha: 0.15) : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isRework ? AppColors.error.withValues(alpha: 0.3) : AppColors.border,
                              ),
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
                                          isRework ? Icons.warning_amber_rounded : Icons.verified_rounded,
                                          size: 16,
                                          color: isRework ? AppColors.error : AppColors.secondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          u.actorName,
                                          style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                    if (u.deltaCompletedQty > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+${u.deltaCompletedQty} ${widget.order.unit}',
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (u.notes.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(u.notes, style: AppTextStyles.bodySmall),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (u.hoursSpent != null && u.hoursSpent! > 0)
                                      Text(
                                        'Hours: ${u.hoursSpent} hrs',
                                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    if (u.createdAt != null)
                                      Text(
                                        FactoryDateUtils.formatFactoryDate(u.createdAt!),
                                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }(),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _handleTransitionStatus(String newStatus) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      await ref.read(productionRepositoryProvider).updateProcessStatus(
            orgId: user.organizationId,
            orderId: _effectiveOrderId,
            processId: widget.process.id,
            newStatus: newStatus,
          );
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Stage status updated to $newStatus'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _saveDailyUpdate() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final delta = int.tryParse(_deltaQtyController.text.trim()) ?? 0;
    final hours = double.tryParse(_hoursSpentController.text.trim());
    final notes = _notesController.text.trim();

    if (delta <= 0 && notes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please specify units produced or progress notes.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final update = ProcessUpdateModel(
        id: '',
        actorUid: user.uid,
        actorName: user.fullName,
        deltaCompletedQty: delta,
        hoursSpent: hours,
        notes: notes,
      );

      await ref.read(productionRepositoryProvider).logProcessUpdate(
            orgId: user.organizationId,
            orderId: _effectiveOrderId,
            processId: widget.process.id,
            update: update,
          );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _showLogOutputForm = false;
          _deltaQtyController.text = '0';
          _notesController.clear();
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Logged output: +$delta ${widget.order.unit}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error logging update: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _saveBlockerUpdate() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final reason = _blockerReasonController.text.trim();

    if (reason.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Blocker reason is required when halting station.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final update = ProcessUpdateModel(
        id: '',
        actorUid: user.uid,
        actorName: user.fullName,
        deltaCompletedQty: 0,
        blockerReason: reason,
        notes: 'Hold/Blocker: $reason',
      );

      await ref.read(productionRepositoryProvider).logProcessUpdate(
            orgId: user.organizationId,
            orderId: _effectiveOrderId,
            processId: widget.process.id,
            update: update,
            transitionStatus: 'BLOCKED',
          );

      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Stage marked BLOCKED: $reason'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error marking blocker: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleSubmitForApproval() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Stage for Sign-off'),
        content: Text(
          'Confirm submission for "${widget.process.name}". Supervisor will review and approve to unlock the next manufacturing stage.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('Submit for Review'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleTransitionStatus('PENDING_APPROVAL');
    }
  }

  Future<void> _confirmReopenStage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Stage'),
        content: Text(
          'Reopen Step ${widget.process.sequence}: "${widget.process.name}"?\n\nThis will reset the stage to IN_PROGRESS so further work, units, or remarks can be logged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Reopen to In Progress'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleTransitionStatus('IN_PROGRESS');
    }
  }

  Future<void> _handleAdminApprove(String orgId, dynamic user) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);

    try {
      await ref.read(productionRepositoryProvider).approveProcessStage(
            orgId: orgId,
            orderId: _effectiveOrderId,
            processId: widget.process.id,
            adminUid: user.uid,
            adminName: user.fullName,
            approvalNotes: 'Quality inspection verified. Stage approved.',
          );

      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Step ${widget.process.sequence} (${widget.process.name}) approved & completed!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error approving stage: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showRejectDialog(String orgId, dynamic user) async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Stage Rework'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter specific rework instructions or defects for the operator to correct:'),
            const SizedBox(height: 10),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Defect / Rework Instructions *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Send for Rework'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      setState(() => _isSaving = true);
      try {
        await ref.read(productionRepositoryProvider).rejectProcessStageForRework(
              orgId: orgId,
              orderId: _effectiveOrderId,
              processId: widget.process.id,
              adminUid: user.uid,
              adminName: user.fullName,
              reworkReason: reasonController.text.trim(),
            );
        if (mounted) {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Step ${widget.process.sequence} flagged for rework.'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _EmployeeAssignRow extends ConsumerWidget {
  final String orgId;
  final String orderId;
  final String processId;
  final String currentAssignedUid;
  final String currentAssignedName;
  final bool isAdmin;

  const _EmployeeAssignRow({
    required this.orgId,
    required this.orderId,
    required this.processId,
    required this.currentAssignedUid,
    required this.currentAssignedName,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (!isAdmin) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Assigned Operator: ',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
            ),
            Expanded(
              child: Text(
                currentAssignedName.isNotEmpty
                    ? currentAssignedName
                    : (currentAssignedUid.isNotEmpty ? currentAssignedUid : 'Unassigned (Shop-Floor Team)'),
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: currentAssignedName.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return employeesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, stack) => const SizedBox.shrink(),
      data: (employees) {
        final activeEmployees = employees.where((e) => e.isActive).toList();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Stage Operator Assignment (Admin Control)',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: currentAssignedUid.isNotEmpty &&
                        activeEmployees.any((e) => e.uid == currentAssignedUid)
                    ? currentAssignedUid
                    : '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Accountable Technician / Operator',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Unassigned (Shop-Floor Team)', overflow: TextOverflow.ellipsis)),
                  ...activeEmployees.map((e) => DropdownMenuItem(
                        value: e.uid,
                        child: Text('${e.fullName} (${e.role.value})', overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (val) async {
                  if (val == null) return;
                  final emp = activeEmployees.where((e) => e.uid == val).firstOrNull;
                  try {
                    await ref.read(productionRepositoryProvider).assignEmployeeToProcess(
                          orgId: orgId,
                          orderId: orderId,
                          processId: processId,
                          employeeUid: val,
                          employeeName: emp?.fullName ?? 'Unassigned',
                        );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          val.isNotEmpty
                              ? 'Assigned Stage to ${emp?.fullName ?? "Operator"}'
                              : 'Stage marked as Unassigned',
                        ),
                        backgroundColor: AppColors.secondary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to assign: $e'), backgroundColor: AppColors.error),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
