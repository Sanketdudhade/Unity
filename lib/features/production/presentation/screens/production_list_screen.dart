import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/processes/data/models/process_step_model.dart';
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

class _ProductionListScreenState extends ConsumerState<ProductionListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_production':
        return AppColors.info;
      case 'scheduled':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'on_hold':
      default:
        return AppColors.error;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_production':
        return 'IN PRODUCTION';
      case 'scheduled':
        return 'SCHEDULED';
      case 'completed':
        return 'COMPLETED';
      case 'on_hold':
        return 'ON HOLD';
      default:
        return status.toUpperCase();
    }
  }

  void _showCreateOrderDialog(BuildContext context, String orgId) {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();

    final orderNum = 'WO-${DateTime.now().year}-${(100 + (DateTime.now().millisecond % 900))}';
    final orderNumController = TextEditingController(text: orderNum);
    final productController = TextEditingController();
    final qtyController = TextEditingController(text: '200');
    final unitController = TextEditingController(text: 'pcs');
    final notesController = TextEditingController();
    String selectedPriority = 'normal';
    String selectedStatus = 'in_production';
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));
    bool isSaving = false;

    ProductModel? selectedProduct;
    ProcessTemplateModel? selectedTemplate;
    bool is17StageDefault = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final products = ref.watch(activeProductsProvider);
          final templates = ref.watch(activeProcessTemplatesProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_rounded, color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Create Work Order', style: AppTextStyles.titleMedium),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: orderNumController,
                          decoration: const InputDecoration(
                            labelText: 'Work Order Number *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Product Selection (Catalog vs Manual)
                        if (products.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            initialValue: selectedProduct?.id ?? 'custom',
                            decoration: const InputDecoration(
                              labelText: 'Catalog Product',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'custom',
                                child: Text('Custom / Manual Product Entry'),
                              ),
                              ...products.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('[${p.partCode}] ${p.name} (${p.unit})'),
                              )),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == null || val == 'custom') {
                                  selectedProduct = null;
                                } else {
                                  selectedProduct = products.firstWhere((p) => p.id == val);
                                  productController.text = selectedProduct!.name;
                                  unitController.text = selectedProduct!.unit;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextFormField(
                          controller: productController,
                          decoration: InputDecoration(
                            labelText: 'Target Product / Assembly *',
                            hintText: 'e.g. Stainless Steel Mounting Brackets',
                            helperText: selectedProduct != null
                                ? 'Drawing: ${selectedProduct!.drawingNumber} (Rev ${selectedProduct!.revision})'
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Process Template Flow Selection
                        DropdownButtonFormField<String>(
                          initialValue: is17StageDefault ? 'default_17' : (selectedTemplate?.id ?? 'default_17'),
                          decoration: const InputDecoration(
                            labelText: 'Manufacturing Process Flow *',
                            border: OutlineInputBorder(),
                            helperText: 'Snapshots stages & sequential dependency rules',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'default_17',
                              child: Text('Default 17-Stage Manufacturing Flow (Locked)'),
                            ),
                            ...templates.map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text('${t.name} (v${t.version}) - ${t.steps.length} stages'),
                            )),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == null || val == 'default_17') {
                                is17StageDefault = true;
                                selectedTemplate = null;
                              } else {
                                is17StageDefault = false;
                                selectedTemplate = templates.firstWhere((t) => t.id == val);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Target Batch Quantity *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final n = double.tryParse(v);
                                  if (n == null || n <= 0) return 'Must be > 0';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: unitController,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedPriority,
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                  DropdownMenuItem(value: 'high', child: Text('High')),
                                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => selectedPriority = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Initial Status',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'in_production', child: Text('In Production')),
                                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                                  DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => selectedStatus = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDueDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Target Due Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                            ),
                            child: Text(
                              '${selectedDueDate.day}/${selectedDueDate.month}/${selectedDueDate.year}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Batch Instructions / Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
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
                          setDialogState(() => isSaving = true);

                          final order = ProductionOrder(
                            id: '',
                            orderNumber: orderNumController.text.trim(),
                            productName: productController.text.trim(),
                            targetQuantity: double.parse(qtyController.text.trim()),
                            completedQuantity: 0.0,
                            unit: unitController.text.trim(),
                            status: selectedStatus,
                            priority: selectedPriority,
                            startDate: DateTime.now(),
                            dueDate: selectedDueDate,
                            notes: notesController.text.trim(),
                          );

                          final List<ProcessStepModel> templateSteps;
                          if (!is17StageDefault &&
                              selectedTemplate != null &&
                              selectedTemplate!.steps.isNotEmpty) {
                            templateSteps = selectedTemplate!.steps;
                          } else {
                            templateSteps = ProcessTemplateModel.default17Stages();
                          }

                          try {
                            await ref.read(productionRepositoryProvider).createOrderWithSnapshottedTemplate(
                              orgId: orgId,
                              order: order,
                              templateSteps: templateSteps,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Work order ${order.orderNumber} launched with ${templateSteps.length} stages!',
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
                                content: Text('Failed to launch order: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
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
        );
      },
    ),
  );
}

  void _showUpdateProgressDialog(BuildContext context, String orgId, ProductionOrder order) {
    final messenger = ScaffoldMessenger.of(context);
    final qtyController = TextEditingController(text: order.completedQuantity.toStringAsFixed(0));
    String selectedStatus = order.status;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Update ${order.orderNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.productName, style: AppTextStyles.titleSmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Units Produced',
                  suffixText: '/ ${order.targetQuantity.toStringAsFixed(0)} ${order.unit}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Order Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'in_production', child: Text('In Production')),
                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedStatus = v);
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
              onPressed: isSaving
                  ? null
                  : () async {
                      final parsed = double.tryParse(qtyController.text.trim()) ?? order.completedQuantity;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(productionRepositoryProvider).updateOrderStatus(
                          orgId: orgId,
                          orderId: order.id,
                          status: selectedStatus,
                          completedQuantity: parsed,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Updated ${order.orderNumber} successfully.'),
                              backgroundColor: AppColors.primary,
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
              child: const Text('Save Updates'),
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
    final ordersAsync = ref.watch(productionOrdersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Production & Batches'),
        actions: [
          IconButton(
            tooltip: 'Product Catalog',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => context.push(RouteNames.adminProducts),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderDialog(context, orgId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Work Order'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ordersAsync.when(
        loading: () => const LoadingWidget(message: 'Loading production orders...'),
        error: (err, _) => Center(
          child: Text('Error loading orders: $err', style: AppTextStyles.bodyMedium),
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
            onRefresh: () async {
              ref.invalidate(productionOrdersStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Metric Cards
                Row(
                  children: [
                    _MetricMiniCard(
                      label: 'In Production',
                      count: inProdCount,
                      color: AppColors.info,
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                    const SizedBox(width: 8),
                    _MetricMiniCard(
                      label: 'Scheduled',
                      count: schedCount,
                      color: AppColors.warning,
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(width: 8),
                    _MetricMiniCard(
                      label: 'Completed',
                      count: compCount,
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Order # or Product...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'All',
                      'In Production',
                      'Scheduled',
                      'Completed',
                      'On Hold',
                    ].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(filter),
                          selectedColor: AppColors.primaryLight,
                          labelStyle: AppTextStyles.labelSmall.copyWith(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // List of Orders
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          orders.isEmpty
                              ? 'No work orders launched yet.\nTap "New Work Order" below to start production.'
                              : 'No orders match your filter criteria.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((order) {
                    final statusColor = _getStatusColor(order.status);
                    final pct = order.progressPercentage;

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductionDetailsScreen(order: order),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                                    order.orderNumber,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (order.priority.toLowerCase() == 'urgent' ||
                                    order.priority.toLowerCase() == 'high') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: order.priority.toLowerCase() == 'urgent'
                                          ? AppColors.errorLight
                                          : AppColors.warningLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      order.priority.toUpperCase(),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: order.priority.toLowerCase() == 'urgent'
                                            ? AppColors.error
                                            : AppColors.warning,
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
                                  child: Text(
                                    _formatStatus(order.status),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(order.productName, style: AppTextStyles.titleMedium),
                            const SizedBox(height: 8),

                            // Progress bar & metrics
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Batch: ${order.completedQuantity.toStringAsFixed(0)} / ${order.targetQuantity.toStringAsFixed(0)} ${order.unit}',
                                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
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
                                backgroundColor: AppColors.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (order.dueDate != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.event_outlined, size: 14, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Due: ${order.dueDate!.day}/${order.dueDate!.month}/${order.dueDate!.year}',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  )
                                else
                                  const SizedBox.shrink(),
                                Row(
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        textStyle: AppTextStyles.labelSmall,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton.icon(
                                      onPressed: () => _showUpdateProgressDialog(context, orgId, order),
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: const Text('Progress'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        textStyle: AppTextStyles.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricMiniCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MetricMiniCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
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
