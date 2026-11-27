import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/core/widgets/responsive_layout.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/processes/presentation/widgets/unity_process_flow_chart_widget.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/data/models/production_workflows.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/production/presentation/widgets/process_stage_actions_dialog.dart';
import 'package:unity/features/production/presentation/widgets/stage_sub_processes_dialog.dart';
import 'package:unity/features/production/presentation/widgets/jobwork_po_dialog.dart';
import 'package:unity/features/bom/presentation/providers/bom_providers.dart';
import 'package:unity/features/bom/presentation/widgets/bom_import_dialog.dart';
import 'package:unity/features/bom/presentation/widgets/product_bom_viewer_sheet.dart';
import 'package:unity/features/bom/presentation/widgets/stage_bom_inventory_dialog.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/products/presentation/providers/product_providers.dart';

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

  void _showAssignEmployeeDialog(BuildContext context, String orgId, OrderProcessModel process) {
    final messenger = ScaffoldMessenger.of(context);
    String? selectedUid = process.assignedEmployeeUid.isNotEmpty ? process.assignedEmployeeUid : null;
    String selectedName = process.assignedEmployeeName.isNotEmpty ? process.assignedEmployeeName : 'Unassigned';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Stage Operator', style: AppTextStyles.titleMedium),
                    Text(
                      'Step ${process.sequence}: ${process.name}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Consumer(
            builder: (context, ref, _) {
              final employeesAsync = ref.watch(employeesStreamProvider);

              return employeesAsync.when(
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error loading employees: $e', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                ),
                data: (employees) {
                  final activeEmployees = employees.where((e) => e.isActive).toList();
                  final validInitialUid = selectedUid != null && activeEmployees.any((e) => e.uid == selectedUid)
                      ? selectedUid
                      : null;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select the shop-floor technician or operator accountable for completing Stage ${process.sequence} (${process.name}).',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        initialValue: validInitialUid,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Operator *',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Unassigned (Shop-Floor Team)', overflow: TextOverflow.ellipsis),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned (Shop-Floor Team)', overflow: TextOverflow.ellipsis),
                          ),
                          ...activeEmployees.map((emp) {
                            return DropdownMenuItem<String?>(
                              value: emp.uid,
                              child: Text('${emp.fullName} (${emp.role.value})', overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: isSaving
                            ? null
                            : (uid) {
                                setDialogState(() {
                                  selectedUid = uid;
                                  if (uid != null) {
                                    final match = activeEmployees.firstWhere((e) => e.uid == uid);
                                    selectedName = match.fullName;
                                  } else {
                                    selectedName = 'Unassigned';
                                  }
                                });
                              },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(productionRepositoryProvider).assignEmployeeToProcess(
                              orgId: orgId,
                              orderId: widget.order.id,
                              processId: process.id,
                              employeeUid: selectedUid ?? '',
                              employeeName: selectedName,
                            );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                selectedUid != null
                                    ? 'Assigned $selectedName to Stage ${process.sequence} (${process.name}).'
                                    : 'Cleared operator assignment for Stage ${process.sequence}.',
                              ),
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
              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
              label: Text(selectedUid == null ? 'Clear Assignment' : 'Confirm Operator'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignAllStagesDialog(
    BuildContext context,
    String orgId,
    List<OrderProcessModel> currentProcesses,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If order has no stages initialized yet, initialize them first
    if (currentProcesses.isEmpty) {
      try {
        await ref.read(productionRepositoryProvider).initializeStagesForOrder(
              orgId: orgId,
              orderId: widget.order.id,
            );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to initialize stages: $e'), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    if (!context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final screenWidth = MediaQuery.sizeOf(context).width;
      final screenHeight = MediaQuery.sizeOf(context).height;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF0F766E), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Operators to Stages', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(
                        '${widget.order.orderNumber} • ${widget.order.productName}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(540.0, screenWidth - 32),
              ),
              child: SizedBox(
                width: double.maxFinite,
                child: Consumer(
                builder: (context, ref, _) {
                  final liveStagesAsync = ref.watch(orderProcessesStreamProvider(widget.order.id));
                  final employeesAsync = ref.watch(employeesStreamProvider);

                  return employeesAsync.when(
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (e, _) => Text('Error loading employees: $e', style: const TextStyle(color: AppColors.error)),
                    data: (employees) {
                      final activeEmployees = employees.where((e) => e.isActive).toList();
                      final uniqueEmployees = <String, AppUserModel>{};
                      for (final emp in activeEmployees) {
                        if (emp.uid.isNotEmpty) {
                          uniqueEmployees[emp.uid] = emp;
                        }
                      }

                      final stages = liveStagesAsync.value ?? currentProcesses;

                      if (stages.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Initializing stages... Please wait a moment.'),
                        );
                      }

                      return SizedBox(
                        height: min(400.0, screenHeight * 0.45),
                        child: ListView.separated(
                          itemCount: stages.length,
                          separatorBuilder: (_, _) => const Divider(height: 12),
                          itemBuilder: (context, index) {
                            final stage = stages[index];
                            final currentUid = stage.assignedEmployeeUid.isNotEmpty ? stage.assignedEmployeeUid : null;
                            final selectedUid = currentUid != null && uniqueEmployees.containsKey(currentUid)
                                ? currentUid
                                : null;

                            return Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${stage.sequence}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stage.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        stage.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _getStatusColor(stage.status),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 5,
                                  child: DropdownButtonFormField<String?>(
                                    key: ValueKey('stage_${stage.id}_$selectedUid'),
                                    initialValue: selectedUid,
                                    isDense: true,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    hint: const Text('Unassigned', style: TextStyle(fontSize: 11)),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Unassigned', style: TextStyle(fontSize: 11)),
                                      ),
                                      ...uniqueEmployees.values.map(
                                        (emp) => DropdownMenuItem<String?>(
                                          value: emp.uid,
                                          child: Text(emp.fullName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                    ],
                                    onChanged: (newUid) async {
                                      final empName = newUid != null && uniqueEmployees.containsKey(newUid)
                                          ? uniqueEmployees[newUid]!.fullName
                                          : 'Unassigned';
                                      await ref.read(productionRepositoryProvider).assignEmployeeToProcess(
                                            orgId: orgId,
                                            orderId: widget.order.id,
                                            processId: stage.id,
                                            employeeUid: newUid ?? '',
                                            employeeName: empName,
                                          );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showStageActionOrAssignSheet(
    BuildContext context,
    String orgId,
    OrderProcessModel process,
    Map<int, String> allStageStatuses,
  ) {
    final theme = Theme.of(context);
    final user = ref.read(authStateProvider).user;
    final isAdmin = user?.role.isAdmin ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Step ${process.sequence}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(process.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        'Status: ${process.status} • Assigned: ${process.assignedEmployeeName.isNotEmpty ? process.assignedEmployeeName : "Unassigned"}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),

            if (isAdmin)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0F766E), size: 20),
                ),
                title: const Text('Assign / Change Employee for this Stage', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  process.assignedEmployeeName.isNotEmpty && process.assignedEmployeeName != 'Unassigned'
                      ? 'Currently assigned to ${process.assignedEmployeeName}'
                      : 'Not assigned to any operator',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAssignEmployeeDialog(context, orgId, process);
                },
              ),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.precision_manufacturing_rounded, color: AppColors.secondary, size: 20),
              ),
              title: const Text('Stage Operations & Daily Output', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Log units produced, mark stage complete, report blockers', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                ProcessStageActionsDialog.show(
                  context,
                  order: widget.order,
                  process: process,
                  allStageStatuses: allStageStatuses,
                );
              },
            ),

            Consumer(
              builder: (context, ref, _) {
                final productsAsync = ref.watch(productsStreamProvider);
                final products = productsAsync.value ?? [];
                final target = widget.order.productName.trim().toLowerCase();

                final matchingProduct = products.firstWhere(
                  (p) =>
                      p.name.trim().toLowerCase() == target ||
                      p.partCode.trim().toLowerCase() == target,
                  orElse: () => ProductModel(
                    id: widget.order.productName.trim().replaceAll(RegExp(r'\s+'), '_'),
                    partCode: widget.order.productName.trim(),
                    name: widget.order.productName.trim(),
                    unit: widget.order.unit,
                  ),
                );

                final bomsAsync = ref.watch(productBomsStreamProvider(matchingProduct.id));
                final boms = bomsAsync.value ?? [];
                final hasBom = boms.isNotEmpty;

                // Step 1: Full Product BOM management
                if (process.sequence == 1) {
                  if (hasBom) {
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.table_view_rounded, color: Colors.blue, size: 20),
                      ),
                      title: Text(
                        'View Full Product BOM — ${matchingProduct.partCode}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Complete engineering component hierarchy, specs & inventory links',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (_) => ProductBomViewerSheet(product: matchingProduct),
                        );
                      },
                    );
                  } else {
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.upload_file_rounded, color: Colors.orange, size: 20),
                      ),
                      title: Text(
                        'Import Product BOM — ${matchingProduct.partCode}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'No BOM registered yet. Upload Excel (.xlsx) or CSV',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => BomImportDialog(product: matchingProduct),
                        );
                      },
                    );
                  }
                }

                // Steps 2+: Stage-specific BOM inventory selection and inspection
                if (!hasBom) {
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: Colors.orange, size: 20),
                    ),
                    title: Text(
                      'Import BOM First — ${matchingProduct.partCode}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Upload BOM to select and allocate stage inventory for this operation',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => BomImportDialog(product: matchingProduct),
                      );
                    },
                  );
                }

                final activeBom = boms.firstWhere((b) => b.isActive, orElse: () => boms.first);
                int allocatedCount = 0;
                try {
                  allocatedCount = process.selectedBomItemIds.length;
                } catch (_) {
                  allocatedCount = 0;
                }

                if (allocatedCount == 0) {
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.playlist_add_check_rounded, color: Color(0xFF0F766E), size: 20),
                    ),
                    title: Text(
                      'Select Stage BOM Inventory (${process.name})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Choose required components, raw materials & hardware from BOM',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      StageBomInventoryDialog.show(
                        context,
                        product: matchingProduct,
                        bom: activeBom,
                        process: process,
                        orderId: widget.order.id,
                        orgId: orgId,
                      );
                    },
                  );
                } else {
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Colors.green, size: 20),
                    ),
                    title: Text(
                      'Stage Inventory ($allocatedCount items selected)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'View or edit allocated BOM materials & stock links for ${process.name}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      StageBomInventoryDialog.show(
                        context,
                        product: matchingProduct,
                        bom: activeBom,
                        process: process,
                        orderId: widget.order.id,
                        orgId: orgId,
                      );
                    },
                  );
                }
              },
            ),

            if (process.sequence >= 4 && process.sequence <= 11)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_tree_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                title: Text(
                  process.subProcesses.isEmpty
                      ? 'Add Sub-Processes & Allocations'
                      : 'Sub-Processes & Allocations (${process.subProcesses.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  process.subProcesses.isEmpty
                      ? 'Admin can add sub-processes and allocate to individual operators'
                      : '${process.subProcesses.where((s) => s.isCompleted).length} of ${process.subProcesses.length} completed • Tap to manage or update status',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => StageSubProcessesDialog(
                      order: widget.order,
                      process: process,
                    ),
                  );
                },
              ),

            if (process.sequence == 4)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.request_quote_rounded, color: Color(0xFFEA580C), size: 20),
                ),
                title: const Text(
                  'M/G Jobwork Purchase Order (PO)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Create, manage & export Milling & Grinding jobwork PO from BOM components',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  JobworkPoDialog.show(
                    context,
                    order: widget.order,
                    process: process,
                  );
                },
              ),

            if (process.name.toUpperCase().contains('VMC') || process.sequence == 9)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0F766E), size: 20),
                ),
                title: const Text(
                  'VMC Purchase Order (PO)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Create, manage & export VMC jobwork PO from BOM components',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  JobworkPoDialog.show(
                    context,
                    order: widget.order,
                    process: process,
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildUninitializedStagesBanner(BuildContext context, String orgId) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    final initButton = ElevatedButton.icon(
      icon: const Icon(Icons.play_arrow_rounded, size: 16),
      label: Text('Initialize ${ProductionWorkflows.getLabel(widget.order.productionType)}'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      onPressed: () async {
        try {
          final steps = ProductionWorkflows.getStages(widget.order.productionType);
          await ref.read(productionRepositoryProvider).initializeStagesForOrder(
                orgId: orgId,
                orderId: widget.order.id,
                steps: steps,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Initialized ${ProductionWorkflows.getLabel(widget.order.productionType)} stages for this work order!'),
                backgroundColor: AppColors.secondary,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
            );
          }
        }
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.schema_rounded, color: Color(0xFF0F766E), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '17 Manufacturing Stages Not Initialized',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Snapshot the standard 17-stage workflow to assign employees and track progress.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                initButton,
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schema_rounded, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ProductionWorkflows.getLabel(widget.order.productionType)} Stages Not Initialized',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Snapshot the ${ProductionWorkflows.getLabel(widget.order.productionType)} workflow to assign employees and track progress.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                initButton,
              ],
            ),
    );
  }

  void _confirmAndSwitchWorkflow(BuildContext context, String orgId, String targetWorkflow) {
    final label = ProductionWorkflows.getLabel(targetWorkflow);
    final count = ProductionWorkflows.getStageCount(targetWorkflow);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: targetWorkflow == ProductionWorkflows.cutting ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Switch to $label ($count Stages)?')),
          ],
        ),
        content: Text(
          'This will replace the current stage sequence for ${widget.order.orderNumber} with the official $label ($count stages) workflow. Any existing stage statuses will be reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: targetWorkflow == ProductionWorkflows.cutting ? Colors.orange[800] : const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(productionRepositoryProvider).replaceWorkflowStagesForOrder(
                  orgId: orgId,
                  orderId: widget.order.id,
                  productionType: targetWorkflow,
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Replaced process workflow with $label ($count stages)!'),
                    backgroundColor: Colors.green[700],
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to switch workflow: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text('Confirm & Replace with $label'),
          ),
        ],
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
        actions: [
          if (user?.role.isAdmin ?? false) ...[
            TextButton.icon(
              icon: const Icon(Icons.assignment_ind_outlined, size: 18),
              label: const Text('Assign Stages'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _showAssignAllStagesDialog(
                context,
                orgId,
                processesAsync.value ?? [],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              tooltip: 'Workflow Options',
              onSelected: (val) {
                if (val == 'SWITCH_CUTTING') {
                  _confirmAndSwitchWorkflow(context, orgId, ProductionWorkflows.cutting);
                } else if (val == 'SWITCH_NON_CUTTING') {
                  _confirmAndSwitchWorkflow(context, orgId, ProductionWorkflows.nonCutting);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'SWITCH_CUTTING',
                  child: Row(
                    children: [
                      Icon(Icons.content_cut_rounded, size: 18, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Switch to Cutting (14 Stages)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'SWITCH_NON_CUTTING',
                  child: Row(
                    children: [
                      Icon(Icons.precision_manufacturing_outlined, size: 18, color: Colors.blue),
                      SizedBox(width: 10),
                      Text('Switch to Non-Cutting (15 Stages)'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveContainer(
        padding: EdgeInsets.zero,
        child: processesAsync.when(
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
              // Uninitialized Stages Alert Banner
              if (processes.isEmpty)
                _buildUninitializedStagesBanner(context, orgId),

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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.order.isCutting
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: widget.order.isCutting
                                      ? Colors.orange.withValues(alpha: 0.5)
                                      : Colors.blue.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                widget.order.isCutting ? 'CUTTING' : 'NON-CUTTING',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: widget.order.isCutting ? Colors.orange[800] : Colors.blue[800],
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
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
                          ],
                        ),
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

              // Visual Process Flow Chart (Cutting, Non-Cutting, or 17 Stages)
              UnityProcessFlowChartWidget(
                liveOrderStages: processes,
                productionType: widget.order.productionType,
                showHeader: false,
                canAssign: user?.role.isAdmin ?? false,
                onAssignAllStages: () => _showAssignAllStagesDialog(context, orgId, processes),
                onAssignEmployee: (seq, name, liveStage) {
                  if (liveStage != null && liveStage.id.isNotEmpty) {
                    _showStageActionOrAssignSheet(context, orgId, liveStage, stepStatusMap);
                  } else {
                    _showAssignAllStagesDialog(context, orgId, processes);
                  }
                },
                onStageTap: (seq, name) {
                  final matched = processes.where((p) => p.sequence == seq);
                  if (matched.isNotEmpty) {
                    _showStageActionOrAssignSheet(context, orgId, matched.first, stepStatusMap);
                  } else {
                    _showAssignAllStagesDialog(context, orgId, processes);
                  }
                },
              ),
              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sequential Manufacturing Stages', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Later stages remain locked until prerequisite stages are approved and completed.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (user?.role.isAdmin ?? false) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.assignment_ind_outlined, size: 15),
                      label: const Text('Assign Stages'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                      ),
                      onPressed: () => _showAssignAllStagesDialog(context, orgId, processes),
                    ),
                  ],
                ],
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
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.pending_actions_rounded, size: 36, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        const Text('No stages snapshotted for this work order.', style: AppTextStyles.titleSmall),
                        const SizedBox(height: 6),
                        const Text(
                          'Click "Initialize 17 Stages" above to populate the manufacturing pipeline.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...processes.map((proc) {
                  final isUnlocked = proc.isUnlocked(stepStatusMap);
                  final statusColor = _getStatusColor(proc.status);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _showStageActionOrAssignSheet(context, orgId, proc, stepStatusMap);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                      color: isUnlocked ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: proc.isInProgress
                            ? const Color(0xFFD97706)
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

                          // Operator Assignment Interactive Chip
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _showAssignEmployeeDialog(context, orgId, proc),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: proc.assignedEmployeeUid.isNotEmpty
                                    ? AppColors.primaryLight.withValues(alpha: 0.1)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: proc.assignedEmployeeUid.isNotEmpty
                                      ? AppColors.primaryLight.withValues(alpha: 0.3)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    proc.assignedEmployeeUid.isNotEmpty
                                        ? Icons.engineering_rounded
                                        : Icons.person_add_alt_1_outlined,
                                    size: 14,
                                    color: proc.assignedEmployeeUid.isNotEmpty
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    proc.assignedEmployeeUid.isNotEmpty
                                        ? 'Operator: ${proc.assignedEmployeeName}'
                                        : 'Operator: Unassigned (Tap to assign)',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: proc.assignedEmployeeUid.isNotEmpty
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: proc.assignedEmployeeUid.isNotEmpty
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (proc.dependsOnStepSequence.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Prerequisite: Step ${proc.dependsOnStepSequence.join(", ")}',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],

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
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                                label: Text(proc.assignedEmployeeUid.isNotEmpty ? 'Reassign' : 'Assign Operator'),
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
      ),
    );
  }
}
