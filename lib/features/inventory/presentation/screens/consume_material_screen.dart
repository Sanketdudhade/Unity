import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';

/// Screen for recording material issue, allocation, or consumption for manufacturing orders.
class ConsumeMaterialScreen extends ConsumerStatefulWidget {
  final String? initialWorkOrder;

  const ConsumeMaterialScreen({
    super.key,
    this.initialWorkOrder,
  });

  @override
  ConsumerState<ConsumeMaterialScreen> createState() => _ConsumeMaterialScreenState();
}

class _ConsumeMaterialScreenState extends ConsumerState<ConsumeMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _workOrderController = TextEditingController();
  final _notesController = TextEditingController();

  StockBalanceModel? _selectedBalance;
  String _transactionType = 'ISSUE'; // 'ISSUE', 'ALLOCATION', 'SCRAP'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkOrder != null) {
      _workOrderController.text = widget.initialWorkOrder!;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _workOrderController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBalance == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a material.')),
      );
      return;
    }

    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;
    if (orgId == null || orgId.isEmpty) return;

    final rawQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (rawQty <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a quantity greater than zero.')),
      );
      return;
    }

    final baseUnits = _selectedBalance!.unitScale > 1
        ? (rawQty * _selectedBalance!.unitScale).round()
        : rawQty.round();

    setState(() => _isSubmitting = true);

    try {
      await ref.read(inventoryRepositoryProvider).recordTransaction(
            orgId: orgId,
            materialId: _selectedBalance!.materialId,
            materialSku: _selectedBalance!.materialSku,
            materialName: _selectedBalance!.materialName,
            type: _transactionType,
            quantityDelta: _transactionType == 'ISSUE' || _transactionType == 'SCRAP'
                ? -baseUnits
                : baseUnits,
            locationId: _selectedBalance!.locationId,
            locationName: _selectedBalance!.locationName,
            orderId: _workOrderController.text.trim().isNotEmpty
                ? _workOrderController.text.trim()
                : null,
            performedByUid: user?.uid ?? 'operator',
            performedByName: user?.fullName ?? 'Operator',
            notes: _notesController.text.trim(),
            unit: _selectedBalance!.unit,
            unitScale: _selectedBalance!.unitScale,
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Successfully processed $_transactionType for ${_selectedBalance!.materialName}.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Transaction failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(stockBalancesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Issue / Consume Material'),
      ),
      body: balancesAsync.when(
        loading: () => const LoadingWidget(message: 'Loading inventory materials...'),
        error: (err, _) => Center(
          child: Text('Error: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
        ),
        data: (balances) {
          if (balances.isEmpty) {
            return Center(
              child: Text('No inventory materials registered.', style: AppTextStyles.bodyMedium),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Material Issue & Consumption', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 16),

                  // Transaction Type Selector
                  DropdownButtonFormField<String>(
                    initialValue: _transactionType,
                    decoration: const InputDecoration(
                      labelText: 'Operation Type',
                      prefixIcon: Icon(Icons.swap_horiz_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ISSUE', child: Text('Issue to Shop Floor (Consumption)')),
                      DropdownMenuItem(value: 'ALLOCATION', child: Text('Reserve / Allocate for Order')),
                      DropdownMenuItem(value: 'SCRAP', child: Text('Write-off Scrap / Damage')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _transactionType = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Material Selector
                  DropdownButtonFormField<StockBalanceModel>(
                    initialValue: _selectedBalance,
                    decoration: const InputDecoration(
                      labelText: 'Select Material *',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: balances.map((b) {
                      return DropdownMenuItem<StockBalanceModel>(
                        value: b,
                        child: Text('${b.materialName} (${b.materialSku})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBalance = val),
                    validator: (v) => v == null ? 'Please select a material' : null,
                  ),
                  const SizedBox(height: 12),

                  // Balance info card
                  if (_selectedBalance != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('Available Stock', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                              Text(
                                '${_selectedBalance!.formattedAvailable} ${_selectedBalance!.unit}',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: _selectedBalance!.availableQuantity > 0 ? AppColors.success : AppColors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text('Allocated', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                              Text(
                                '${_selectedBalance!.formattedAllocated} ${_selectedBalance!.unit}',
                                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text('Location', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                              Text(
                                _selectedBalance!.locationName,
                                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Quantity input
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantity to Deduct ${_selectedBalance != null ? "(${_selectedBalance!.unit})" : ""} *',
                      prefixIcon: const Icon(Icons.exposure_minus_1_rounded),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Quantity is required';
                      final val = double.tryParse(v.trim());
                      if (val == null || val <= 0) return 'Must be a positive number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Linked Work Order
                  TextFormField(
                    controller: _workOrderController,
                    decoration: const InputDecoration(
                      labelText: 'Linked Work Order # (Optional)',
                      hintText: 'e.g. WO-2026-101',
                      prefixIcon: Icon(Icons.precision_manufacturing_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason / Stage / Department Notes',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(_isSubmitting ? 'Recording Ledger Entry...' : 'Confirm Transaction'),
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
