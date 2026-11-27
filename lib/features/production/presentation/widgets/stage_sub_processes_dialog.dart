import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/data/models/sub_process_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';

/// Interactive modal allowing administrators to define operational sub-processes under
/// Stages 4 to 11 and assign them to individual technicians/operators.
/// Technicians can view their assigned sub-processes and update status when working.
class StageSubProcessesDialog extends ConsumerStatefulWidget {
  final ProductionOrder order;
  final OrderProcessModel process;

  const StageSubProcessesDialog({
    super.key,
    required this.order,
    required this.process,
  });

  @override
  ConsumerState<StageSubProcessesDialog> createState() => _StageSubProcessesDialogState();
}

class _StageSubProcessesDialogState extends ConsumerState<StageSubProcessesDialog> {
  bool _isCreating = false;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _qtyController = TextEditingController();

  String? _selectedEmployeeUid;
  String? _selectedEmployeeName;

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.order.targetQuantity > 0
        ? widget.order.targetQuantity.toInt().toString()
        : '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  List<String> _getStagePresetSuggestions(int sequence) {
    switch (sequence) {
      case 4: // M&G (Milling & Grinding)
        return ['Rough Milling', 'Finish Milling', 'Surface Grinding', 'Cylindrical Grinding', 'Deburring & Facing'];
      case 5: // DWG (Drawing)
        return ['2D Drawing Verification', '3D CAD Clearance Check', 'Critical Dimension Markup'];
      case 6: // Pillar / Bush / Button
        return ['Pillar Fitting & Sizing', 'Bush Pressing & Reaming', 'Guide Button Alignment'];
      case 7: // DRO
        return ['X/Y-Axis DRO Co-ordinates', 'Precision Center Boring', 'Hole Pitch Verification'];
      case 8: // ASY (Assembly)
        return ['Base Plate Sub-Assembly', 'Punch Holder Assembly', 'Die Retainer Fastening'];
      case 9: // VMC / HT
        return ['VMC Fixture Setup', 'VMC Rough Contouring', 'VMC High-Speed Finishing', 'Vacuum Heat Treatment'];
      case 10: // Machine / Drawing / VMC
        return ['Lathe Turning & Grooving', 'Keyway Slotting', 'Edge Chamfering & Tapping'];
      case 11: // W/C (Wire Cutting)
        return ['Wire EDM Path Setup', 'Die Plate Profile Wire Cut', 'Punch Insert Precision Cut'];
      default:
        return ['Initial Setup', 'Primary Machining', 'Secondary Operation', 'Quality Verification'];
    }
  }

  Future<void> _handleCreateSubProcess(String orgId) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a sub-process name.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final subProcess = SubProcessModel(
        id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
        orderId: widget.order.id,
        processId: widget.process.id,
        stageSequence: widget.process.sequence,
        stageName: widget.process.name,
        title: title,
        description: _descriptionController.text.trim(),
        assignedEmployeeUid: _selectedEmployeeUid ?? '',
        assignedEmployeeName: _selectedEmployeeName ?? 'Unassigned',
        targetQty: int.tryParse(_qtyController.text.trim()) ?? widget.order.targetQuantity.toInt(),
        status: (_selectedEmployeeUid != null && _selectedEmployeeUid!.isNotEmpty)
            ? 'ASSIGNED'
            : 'NOT_STARTED',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(productionRepositoryProvider).addSubProcess(
            orgId: orgId,
            orderId: widget.order.id,
            processId: widget.process.id,
            subProcess: subProcess,
          );

      ref.invalidate(orderProcessesStreamProvider(widget.order.id));
      ref.invalidate(employeeAssignedProcessesStreamProvider);

      setState(() {
        _isCreating = false;
        _isSaving = false;
        _titleController.clear();
        _descriptionController.clear();
        _selectedEmployeeUid = null;
        _selectedEmployeeName = null;
      });

      messenger.showSnackBar(
        SnackBar(content: Text('Sub-process "$title" created & assigned!')),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save sub-process: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleUpdateStatus(String orgId, SubProcessModel sp, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(productionRepositoryProvider).updateSubProcessStatus(
            orgId: orgId,
            orderId: widget.order.id,
            processId: widget.process.id,
            subProcessId: sp.id,
            newStatus: newStatus,
          );

      ref.invalidate(orderProcessesStreamProvider(widget.order.id));
      ref.invalidate(employeeAssignedProcessesStreamProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'IN_PROGRESS'
                ? 'Started work on "${sp.title}"'
                : 'Sub-process "${sp.title}" marked as COMPLETED!',
          ),
          backgroundColor: newStatus == 'IN_PROGRESS' ? const Color(0xFF0F766E) : Colors.green[800],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleDeleteSubProcess(String orgId, SubProcessModel sp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sub-Process?'),
        content: Text('Are you sure you want to remove sub-process "${sp.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(productionRepositoryProvider).deleteSubProcess(
            orgId: orgId,
            orderId: widget.order.id,
            processId: widget.process.id,
            subProcessId: sp.id,
          );

      ref.invalidate(orderProcessesStreamProvider(widget.order.id));
      ref.invalidate(employeeAssignedProcessesStreamProvider);

      messenger.showSnackBar(
        SnackBar(content: Text('Sub-process "${sp.title}" deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete sub-process: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF16A34A);
      case 'IN_PROGRESS':
        return const Color(0xFF0284C7);
      case 'ASSIGNED':
        return const Color(0xFF0F766E);
      case 'BLOCKED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;
    final isAdmin = user?.role.isAdmin ?? false;
    final orgId = user?.organizationId ?? 'org_unity_001';

    // Stream live processes to keep sub-processes real-time
    final processesAsync = ref.watch(orderProcessesStreamProvider(widget.order.id));
    final liveProcess = processesAsync.value?.firstWhere(
          (p) => p.id == widget.process.id,
          orElse: () => widget.process,
        ) ??
        widget.process;

    final subProcesses = liveProcess.subProcesses;
    final completedCount = subProcesses.where((sp) => sp.isCompleted).length;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = screenWidth < 650;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 32,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: min(780.0, screenHeight - 32),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Step ${liveProcess.sequence}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${liveProcess.name} — Sub-Processes',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.order.orderNumber} • ${widget.order.productName} • Target: ${widget.order.targetQuantity.toInt()} ${widget.order.unit}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Sub-process progress summary bar
            if (subProcesses.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                child: Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 18, color: const Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Text(
                      'Progress: $completedCount / ${subProcesses.length} Sub-Processes Completed',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '${((completedCount / subProcesses.length) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Action: Add Sub-Process Button or Inline Form
                    if (isAdmin) ...[
                      if (!_isCreating)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Operation Sub-Tasks',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Sub-Process', style: TextStyle(fontWeight: FontWeight.w700)),
                              onPressed: () => setState(() => _isCreating = true),
                            ),
                          ],
                        )
                      else
                        _buildAddSubProcessForm(context, orgId, isDark),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                    ],

                    // Sub-Processes List
                    if (subProcesses.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.account_tree_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            const Text(
                              'No Sub-Processes Defined Yet',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isAdmin
                                  ? 'Click "+ Add Sub-Process" above to break this manufacturing stage down into allocated technician operations.'
                                  : 'No sub-tasks currently defined for this stage.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subProcesses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final sp = subProcesses[i];
                          return _buildSubProcessCard(context, orgId, sp, isDark, isAdmin, user?.uid ?? '');
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Dialog Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSubProcessForm(BuildContext context, String orgId, bool isDark) {
    final theme = Theme.of(context);
    final suggestions = _getStagePresetSuggestions(widget.process.sequence);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.alt_route_rounded, size: 18, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  const Text('New Sub-Process Definition', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _isCreating = false),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets
          Text(
            'Quick Suggestions for Step ${widget.process.sequence} (${widget.process.name}):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions.map((preset) {
              return ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(preset, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _titleController.text = preset;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Sub-process title
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Sub-Process Name *',
              hintText: 'e.g. Rough Milling, Surface Grinding, Boring',
              isDense: true,
              prefixIcon: Icon(Icons.precision_manufacturing_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Assign Employee
          Consumer(
            builder: (context, ref, _) {
              final employeesAsync = ref.watch(employeesStreamProvider);
              final employees = employeesAsync.value ?? [];
              final activeEmployees = employees.where((e) => e.isActive).toList();

              return DropdownButtonFormField<String?>(
                initialValue: _selectedEmployeeUid,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assign to Technician / Operator',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  isDense: true,
                ),
                hint: const Text('Unassigned (Assign later)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Unassigned (Assign later)'),
                  ),
                  ...activeEmployees.map((e) => DropdownMenuItem<String?>(
                        value: e.uid,
                        child: Text('${e.fullName} (${e.role.value})'),
                      )),
                ],
                onChanged: (uid) {
                  setState(() {
                    _selectedEmployeeUid = uid;
                    if (uid != null) {
                      final emp = activeEmployees.firstWhere((e) => e.uid == uid);
                      _selectedEmployeeName = emp.fullName;
                    } else {
                      _selectedEmployeeName = null;
                    }
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Target Quantity & Description
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Qty (${widget.order.unit})',
                    isDense: true,
                    prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Specifications / Notes (Optional)',
                    hintText: 'e.g. tolerance ±0.02mm, spindle speed',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Submit & Cancel
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isCreating = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : () => _handleCreateSubProcess(orgId),
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Create & Assign Sub-Process'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubProcessCard(
    BuildContext context,
    String orgId,
    SubProcessModel sp,
    bool isDark,
    bool isAdmin,
    String currentUid,
  ) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(sp.status);
    final isAssignedToMe = sp.assignedEmployeeUid.trim() == currentUid.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: sp.isInProgress ? statusColor : theme.colorScheme.outlineVariant,
          width: sp.isInProgress ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.alt_route_rounded, size: 16, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sp.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (sp.description.isNotEmpty)
                      Text(
                        sp.description,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  sp.status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Assignment and Target info
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Assigned: ',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(
                sp.assignedEmployeeName.isNotEmpty ? sp.assignedEmployeeName : 'Unassigned',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sp.assignedEmployeeUid.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isAssignedToMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ],
              const Spacer(),
              if (sp.targetQty > 0)
                Text(
                  'Target: ${sp.targetQty} ${widget.order.unit}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),

          // Action buttons
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isAdmin)
                IconButton(
                  tooltip: 'Delete Sub-Process',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  onPressed: () => _handleDeleteSubProcess(orgId, sp),
                ),
              const Spacer(),

              // If unstarted / assigned: Start Working
              if (sp.isNotStarted || sp.status == 'ASSIGNED') ...[
                if (isAssignedToMe || isAdmin)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Start Working', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleUpdateStatus(orgId, sp, 'IN_PROGRESS'),
                  ),
              ] else if (sp.isInProgress) ...[
                if (isAssignedToMe || isAdmin)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Mark Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleUpdateStatus(orgId, sp, 'COMPLETED'),
                  ),
              ] else if (sp.isCompleted) ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text('Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
