import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/admin_page_header.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/empty_state.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/processes/data/models/process_template_model.dart';
import 'package:unity/features/processes/presentation/providers/process_template_providers.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/products/presentation/providers/product_providers.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/production/presentation/screens/production_details_screen.dart';

class ProductionListScreen extends ConsumerStatefulWidget {
  const ProductionListScreen({super.key});

  @override
  ConsumerState<ProductionListScreen> createState() => _ProductionListScreenState();
}

class _ProductionListScreenState extends ConsumerState<ProductionListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateOrderDialog(BuildContext context, String orgId, {ProductModel? preselectedProduct}) {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final formKey = GlobalKey<FormState>();

    ProductModel? selectedProduct = preselectedProduct;
    ProcessTemplateModel? selectedTemplate;
    String? selectedEmployeeUid;
    String? selectedEmployeeName;
    final Map<int, ({String uid, String name})> stageAssignments = {};
    bool showCustomStageAssignments = false;
    final orderNumController = TextEditingController(
      text: 'WO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final qtyController = TextEditingController(text: '100');
    final priorityController = TextEditingController(text: 'normal');
    final notesController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    DateTime startDate = DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final productsAsync = ref.watch(productsStreamProvider);
          final templatesAsync = ref.watch(processTemplatesStreamProvider);

          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_task_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Launch Work Order',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Selector
                        productsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error loading products: $e', style: TextStyle(color: tokens.danger)),
                          data: (products) {
                            if (products.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: tokens.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: tokens.warning),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: tokens.warning, size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text('No products available. Add a product first in Product Master.'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            selectedProduct ??= products.first;

                            return DropdownButtonFormField<ProductModel>(
                              initialValue: selectedProduct,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Product / Part Code *',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: products.map((p) {
                                return DropdownMenuItem<ProductModel>(
                                  value: p,
                                  child: Text('${p.partCode} - ${p.name}', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: isSaving
                                  ? null
                                  : (p) {
                                      setDialogState(() {
                                        selectedProduct = p;
                                      });
                                    },
                              validator: (v) => v == null ? 'Please select a product' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Template Selector
                        templatesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error loading workflows: $e', style: TextStyle(color: tokens.danger)),
                          data: (templates) {
                            if (templates.isNotEmpty && selectedTemplate == null) {
                              selectedTemplate = templates.first;
                            }
                            return DropdownButtonFormField<ProcessTemplateModel>(
                              initialValue: selectedTemplate,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Manufacturing Process Route (Stages) *',
                                prefixIcon: Icon(Icons.account_tree_outlined),
                              ),
                              items: templates.map((t) {
                                return DropdownMenuItem<ProcessTemplateModel>(
                                  value: t,
                                  child: Text(
                                    '${t.name} (${t.steps.length} stages)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: isSaving
                                  ? null
                                  : (t) {
                                      setDialogState(() {
                                        selectedTemplate = t;
                                      });
                                    },
                              validator: (v) => v == null ? 'Please select a routing template' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Stage Operator Assignment per Stage
                        Consumer(
                          builder: (context, ref, _) {
                            final employees = ref.watch(employeesStreamProvider).value ?? [];
                            final activeEmployees = employees.where((e) => e.isActive).toList();
                            final templateSteps = selectedTemplate?.steps ?? ProcessTemplateModel.default17Stages();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.assignment_ind_outlined, size: 16, color: theme.colorScheme.primary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Stage Assignments (${templateSteps.length} Stages)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      ),
                                      icon: Icon(
                                        showCustomStageAssignments ? Icons.expand_less_rounded : Icons.tune_rounded,
                                        size: 14,
                                      ),
                                      label: Text(
                                        showCustomStageAssignments ? 'Collapse' : 'Assign Each Stage',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          showCustomStageAssignments = !showCustomStageAssignments;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String?>(
                                  initialValue: selectedEmployeeUid,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Default Operator (All Stages)',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                    helperText: 'Select an employee for all stages or customize each stage below',
                                  ),
                                  hint: const Text(
                                    'Unassigned (Custom per stage or assign later)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        'Unassigned (Custom per stage or assign later)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ...activeEmployees.map((e) => DropdownMenuItem<String?>(
                                          value: e.uid,
                                          child: Text(
                                            '${e.fullName} (${e.role.value})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                  ],
                                  onChanged: isSaving
                                      ? null
                                      : (uid) {
                                          setDialogState(() {
                                            selectedEmployeeUid = uid;
                                            if (uid != null) {
                                              final emp = activeEmployees.firstWhere((e) => e.uid == uid);
                                              selectedEmployeeName = emp.fullName;
                                              for (final s in templateSteps) {
                                                stageAssignments[s.sequence] = (uid: uid, name: emp.fullName);
                                              }
                                            } else {
                                              selectedEmployeeName = null;
                                              stageAssignments.clear();
                                            }
                                          });
                                        },
                                ),
                                if (showCustomStageAssignments) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 220),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.colorScheme.outline),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: templateSteps.length,
                                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                                      itemBuilder: (context, i) {
                                        final s = templateSteps[i];
                                        final currentUid = stageAssignments[s.sequence]?.uid ?? selectedEmployeeUid;

                                        return Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${s.sequence}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                s.name,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              flex: 4,
                                              child: DropdownButtonFormField<String?>(
                                                initialValue: currentUid != null && activeEmployees.any((e) => e.uid == currentUid)
                                                    ? currentUid
                                                    : null,
                                                isDense: true,
                                                isExpanded: true,
                                                decoration: InputDecoration(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                hint: const Text('Unassigned', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                                items: [
                                                  const DropdownMenuItem<String?>(
                                                    value: null,
                                                    child: Text('Unassigned', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                                  ),
                                                  ...activeEmployees.map(
                                                    (e) => DropdownMenuItem<String?>(
                                                      value: e.uid,
                                                      child: Text(e.fullName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                                    ),
                                                  ),
                                                ],
                                                onChanged: isSaving
                                                    ? null
                                                    : (val) {
                                                        setDialogState(() {
                                                          if (val != null) {
                                                            final emp = activeEmployees.firstWhere((e) => e.uid == val);
                                                            stageAssignments[s.sequence] = (uid: val, name: emp.fullName);
                                                          } else {
                                                            stageAssignments.remove(s.sequence);
                                                          }
                                                        });
                                                      },
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 420;

                            final workOrderField = TextFormField(
                              controller: orderNumController,
                              decoration: const InputDecoration(
                                labelText: 'Work Order # *',
                                prefixIcon: Icon(Icons.tag_rounded),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            );

                            final qtyField = TextFormField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Target Qty (${selectedProduct?.unit ?? "PCS"}) *',
                                prefixIcon: const Icon(Icons.numbers_rounded),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                final n = double.tryParse(v);
                                if (n == null || n <= 0) return 'Must be > 0';
                                return null;
                              },
                            );

                            final priorityField = DropdownButtonFormField<String>(
                              initialValue: priorityController.text,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                prefixIcon: Icon(Icons.flag_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Low', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'normal', child: Text('Normal', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'high', child: Text('High', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'urgent', child: Text('Urgent', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: isSaving ? null : (v) => priorityController.text = v ?? 'normal',
                            );

                            final dueDateField = InkWell(
                              onTap: isSaving
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: dueDate,
                                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => dueDate = picked);
                                      }
                                    },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Target Due Date',
                                  prefixIcon: Icon(Icons.calendar_today_outlined),
                                ),
                                child: Text(
                                  '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                                ),
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  workOrderField,
                                  const SizedBox(height: 12),
                                  qtyField,
                                  const SizedBox(height: 12),
                                  priorityField,
                                  const SizedBox(height: 12),
                                  dueDateField,
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: workOrderField),
                                    const SizedBox(width: 10),
                                    Expanded(child: qtyField),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: priorityField),
                                    const SizedBox(width: 10),
                                    Expanded(child: dueDateField),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Production Notes / Work Instructions',
                            hintText: 'e.g. Critical tolerance surface finish required',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (selectedProduct == null || selectedTemplate == null) return;

                        setDialogState(() => isSaving = true);

                        final targetQty = double.tryParse(qtyController.text.trim()) ?? 100;
                        final order = ProductionOrder(
                          id: '',
                          orderNumber: orderNumController.text.trim(),
                          productName: selectedProduct!.name,
                          targetQuantity: targetQty,
                          completedQuantity: 0,
                          unit: selectedProduct!.unit,
                          status: 'scheduled',
                          priority: priorityController.text,
                          customerName: selectedProduct?.customerReference ?? '',
                          notes: notesController.text.trim(),
                          startDate: startDate,
                          dueDate: dueDate,
                          updatedAt: DateTime.now(),
                        );

                        try {
                          await ref.read(productionRepositoryProvider).createOrderWithSnapshottedTemplate(
                                orgId: orgId,
                                order: order,
                                templateSteps: selectedTemplate!.steps,
                                assignedEmployeeUid: selectedEmployeeUid,
                                assignedEmployeeName: selectedEmployeeName,
                                stageAssignmentsBySequence: stageAssignments.isNotEmpty ? stageAssignments : null,
                              );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Work order ${order.orderNumber} launched with ${selectedTemplate!.steps.length} stages!',
                                ),
                                backgroundColor: tokens.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to launch order: $e'),
                              backgroundColor: tokens.danger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Launch Work Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateProgressDialog(BuildContext context, String orgId, ProductionOrder order) {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final qtyController = TextEditingController(text: order.completedQuantity.toStringAsFixed(0));
    String selectedStatus = order.status;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          title: Text(
            'Update Order Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.orderNumber} - ${order.productName}',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Target: ${order.targetQuantity.toStringAsFixed(0)} ${order.unit}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Completed Quantity (${order.unit})',
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Order Status',
                  prefixIcon: Icon(Icons.sync_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'in_production', child: Text('In Production', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'on_hold', child: Text('On Hold', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: isSaving ? null : (v) => setDialogState(() => selectedStatus = v ?? selectedStatus),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final val = double.tryParse(qtyController.text.trim());
                      if (val == null || val < 0) return;

                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(productionRepositoryProvider).updateOrderStatus(
                              orgId: orgId,
                              orderId: order.id,
                              completedQuantity: val,
                              status: selectedStatus,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Order ${order.orderNumber} updated!'),
                            backgroundColor: tokens.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: tokens.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignStageDialog(BuildContext context, String orgId, ProductionOrder order) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final theme = Theme.of(context);
      final tokens = context.adminTokens;
      final isDark = theme.brightness == Brightness.dark;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.assignment_ind_rounded, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign Stage Operators',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${order.orderNumber} • ${order.productName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: Consumer(
                builder: (context, ref, _) {
                  final processesAsync = ref.watch(orderProcessesStreamProvider(order.id));
                  final employeesAsync = ref.watch(employeesStreamProvider);

                  if (processesAsync.isLoading || employeesAsync.isLoading) {
                    return const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  if (processesAsync.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading stages: ${processesAsync.error}',
                          style: TextStyle(color: tokens.danger, fontSize: 13)),
                    );
                  }

                  final processes = processesAsync.value ?? [];
                  final employees = employeesAsync.value ?? [];
                  final activeEmployees = employees.where((e) => e.isActive).toList();

                  // Deduplicate active employees by uid to avoid duplicate DropdownMenuItems
                  final uniqueEmployees = <String, AppUserModel>{};
                  for (final emp in activeEmployees) {
                    if (emp.uid.isNotEmpty) {
                      uniqueEmployees[emp.uid] = emp;
                    }
                  }

                  if (processes.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_clear_outlined, size: 36, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(
                            'No stages snapshotted for this work order yet.',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await ref.read(productionRepositoryProvider).initializeStagesForOrder(
                                      orgId: orgId,
                                      orderId: order.id,
                                    );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text('Initialized default 17 manufacturing stages for order.'),
                                    backgroundColor: tokens.success,
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed to initialize: $e'), backgroundColor: tokens.danger),
                                );
                              }
                            },
                            icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                            label: const Text('Initialize 17 Stages Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.primarySoft.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Assigned operators can log in to view their station queue, start operation, log daily outputs, and submit sign-off.',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sequential Stages (${processes.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 380,
                        child: ListView.separated(
                          itemCount: processes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final proc = processes[index];
                            final hasAssigned = proc.assignedEmployeeUid.isNotEmpty;
                            final selectedUid = hasAssigned && uniqueEmployees.containsKey(proc.assignedEmployeeUid)
                                ? proc.assignedEmployeeUid
                                : null;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: hasAssigned
                                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                      : theme.colorScheme.outline,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Step ${proc.sequence}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          proc.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      StatusChip(
                                        label: proc.status.replaceAll('_', ' '),
                                        variant: proc.isCompleted
                                            ? StatusVariant.success
                                            : (proc.isInProgress ? StatusVariant.info : StatusVariant.neutral),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String?>(
                                    key: ValueKey('list_stage_${proc.id}_$selectedUid'),
                                    initialValue: selectedUid,
                                    isDense: true,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Assigned Operator',
                                      prefixIcon: const Icon(Icons.person_outline, size: 16),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    hint: const Text('Unassigned (Shop-Floor Team)', style: TextStyle(fontSize: 12)),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Unassigned (Shop-Floor Team)', style: TextStyle(fontSize: 12)),
                                      ),
                                      ...uniqueEmployees.values.map(
                                        (emp) => DropdownMenuItem<String?>(
                                          value: emp.uid,
                                          child: Text(
                                            '${emp.fullName} (${emp.role.value})',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (newSelectedUid) async {
                                      final emp = newSelectedUid != null ? uniqueEmployees[newSelectedUid] : null;
                                      final newUid = newSelectedUid ?? '';
                                      final newName = emp?.fullName ?? 'Unassigned';

                                      try {
                                        await ref.read(productionRepositoryProvider).assignEmployeeToProcess(
                                              orgId: orgId,
                                              orderId: order.id,
                                              processId: proc.id,
                                              employeeUid: newUid,
                                              employeeName: newName,
                                            );
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              newUid.isNotEmpty
                                                  ? 'Step ${proc.sequence} (${proc.name}) assigned to $newName'
                                                  : 'Step ${proc.sequence} marked Unassigned',
                                            ),
                                            backgroundColor: tokens.success,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to assign: $e'),
                                            backgroundColor: tokens.danger,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProductionDetailsScreen(order: order),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Open 17 Stages Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';
    final ordersAsync = ref.watch(productionOrdersStreamProvider);
    final allProductsAsync = ref.watch(productsStreamProvider);
    final products = allProductsAsync.value ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Page Header with Integrated TabBar
          AdminPageHeader(
            title: 'Production & Batches',
            subtitle: 'Live manufacturing orders, batch progress tracking, and multi-stage workflow dispatch',
            icon: Icons.precision_manufacturing_rounded,
            trailing: ElevatedButton.icon(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showCreateOrderDialog(context, orgId);
                } else {
                  context.push(RouteNames.adminProducts);
                }
              },
              icon: Icon(_tabController.index == 0 ? Icons.add_rounded : Icons.add_box_outlined, size: 18),
              label: Text(_tabController.index == 0 ? 'New Work Order' : 'Add New Part'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 2.5,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Work Orders & Batches'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Product Catalog'),
                      if (products.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${products.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWorkOrdersTab(ordersAsync, orgId),
                _buildProductsCatalogTab(allProductsAsync, orgId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkOrdersTab(AsyncValue<List<ProductionOrder>> ordersAsync, String orgId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;

    return ordersAsync.when(
      loading: () => const LoadingWidget(message: 'Loading production orders...'),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading orders: $err', style: TextStyle(color: tokens.danger)),
        ),
      ),
      data: (orders) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = orders.where((o) {
          final matchesFilter = _selectedFilter == 'All' ||
              (_selectedFilter == 'In Production' && o.isInProduction) ||
              (_selectedFilter == 'Scheduled' && o.isScheduled) ||
              (_selectedFilter == 'Completed' && o.isCompleted) ||
              (_selectedFilter == 'On Hold' && o.isOnHold);

          final matchesQuery = query.isEmpty ||
              o.orderNumber.toLowerCase().contains(query) ||
              o.productName.toLowerCase().contains(query);

          return matchesFilter && matchesQuery;
        }).toList();

        final inProdCount = orders.where((o) => o.isInProduction).length;
        final schedCount = orders.where((o) => o.isScheduled).length;
        final compCount = orders.where((o) => o.isCompleted).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productionOrdersStreamProvider),
          child: Column(
            children: [
              // Search & Filter Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF152235) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;

                    final metricBadges = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniOrderBadge(
                          label: 'In Production',
                          count: inProdCount,
                          color: tokens.info,
                          icon: Icons.precision_manufacturing_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MiniOrderBadge(
                          label: 'Scheduled',
                          count: schedCount,
                          color: tokens.warning,
                          icon: Icons.schedule_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MiniOrderBadge(
                          label: 'Completed',
                          count: compCount,
                          color: tokens.success,
                          icon: Icons.check_circle_rounded,
                        ),
                      ],
                    );

                    final searchField = SizedBox(
                      width: isWide ? 260 : double.infinity,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search order # or product...',
                          hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0E1728) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    );

                    final filterRow = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          'All',
                          'In Production',
                          'Scheduled',
                          'Completed',
                          'On Hold',
                        ].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setState(() => _selectedFilter = filter),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : (isDark ? const Color(0xFF0E1728) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                                  ),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? const Color(0xFFA6B6CB) : const Color(0xFF475569)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          metricBadges,
                          const Spacer(),
                          searchField,
                          const SizedBox(width: 10),
                          filterRow,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: metricBadges,
                          ),
                          const SizedBox(height: 10),
                          searchField,
                          const SizedBox(height: 8),
                          filterRow,
                        ],
                      );
                    }
                  },
                ),
              ),

              // Orders List
              Expanded(
                child: filtered.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.precision_manufacturing_outlined,
                        title: orders.isEmpty ? 'No work orders launched yet' : 'No matching work orders',
                        description: orders.isEmpty
                            ? 'Tap "New Work Order" above to initiate a manufacturing batch.'
                            : 'No orders match your filter criteria "$query".',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final pct = order.progressPercentage;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.colorScheme.outline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: tokens.primarySoft,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        order.orderNumber,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    if (order.priority.toLowerCase() == 'urgent' ||
                                        order.priority.toLowerCase() == 'high') ...[
                                      const SizedBox(width: 8),
                                      StatusChip(
                                        label: order.priority.toUpperCase(),
                                        variant: order.priority.toLowerCase() == 'urgent'
                                            ? StatusVariant.error
                                            : StatusVariant.warning,
                                        icon: Icons.flag_rounded,
                                      ),
                                    ],
                                    const Spacer(),
                                    StatusChip.fromStatus(order.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  order.productName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Progress bar & metrics
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Batch: ${order.completedQuantity.toStringAsFixed(0)} / ${order.targetQuantity.toStringAsFixed(0)} ${order.unit}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
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
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (order.dueDate != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.event_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Due: ${order.dueDate!.day}/${order.dueDate!.month}/${order.dueDate!.year}',
                                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => ProductionDetailsScreen(order: order),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.account_tree_outlined, size: 14),
                                          label: const Text('17 Stages'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _showAssignStageDialog(context, orgId, order),
                                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                                          label: const Text('Assign Stage'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _showUpdateProgressDialog(context, orgId, order),
                                          icon: const Icon(Icons.edit_outlined, size: 14),
                                          label: const Text('Progress'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsCatalogTab(AsyncValue<List<ProductModel>> productsAsync, String orgId) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;

    return productsAsync.when(
      loading: () => const LoadingWidget(message: 'Loading product catalog...'),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading products: $err', style: TextStyle(color: tokens.danger)),
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.category_outlined,
            title: 'No products in catalog yet',
            description: 'Add products in Product Master to launch production batches.',
            action: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product to Catalog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.push(RouteNames.adminProducts),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(productsStreamProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${products.length} registered product(s) in catalog. Click "Launch Work Order" on any part to initiate production with manufacturing stages.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...products.map((prod) => _buildProductCatalogCard(prod, orgId)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCatalogCard(ProductModel prod, String orgId) {
    final theme = Theme.of(context);
    final tokens = context.adminTokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prod.partCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (prod.customerReference.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    prod.customerReference,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (prod.isActive)
                StatusChip(
                  label: 'ACTIVE',
                  variant: StatusVariant.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prod.name,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
          ),
          if (prod.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              prod.description,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (prod.drawingNumber.isNotEmpty) ...[
                Icon(Icons.architecture_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Dwg: ${prod.drawingNumber} (Rev ${prod.revision})',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
              ],
              Icon(Icons.straighten_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Unit: ${prod.unit}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit Part'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => context.push(RouteNames.adminProducts),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Launch Work Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _showCreateOrderDialog(context, orgId, preselectedProduct: prod),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniOrderBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MiniOrderBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1728) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
