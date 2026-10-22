import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/inventory_item_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';

/// Modal dialog allowing shop-floor workers to log consumed raw materials with real-time stock deduction.
class RecordMaterialUsageDialog extends ConsumerStatefulWidget {
  final String? initialWorkOrder;

  const RecordMaterialUsageDialog({
    super.key,
    this.initialWorkOrder,
  });

  static Future<void> show(BuildContext context, {String? workOrder}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordMaterialUsageDialog(initialWorkOrder: workOrder),
    );
  }

  @override
  ConsumerState<RecordMaterialUsageDialog> createState() => _RecordMaterialUsageDialogState();
}

class _RecordMaterialUsageDialogState extends ConsumerState<RecordMaterialUsageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();

  InventoryItem? _selectedItem;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkOrder != null && widget.initialWorkOrder!.isNotEmpty) {
      _noteController.text = 'Consumed for ${widget.initialWorkOrder}';
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitDeduction() {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return Future.value();

    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;

    if (orgId == null || orgId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cannot log usage: Organization ID missing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return Future.value();
    }

    if (_selectedItem == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select a material from the inventory list.'),
          backgroundColor: AppColors.error,
        ),
      );
      return Future.value();
    }

    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive quantity.'),
          backgroundColor: AppColors.error,
        ),
      );
      return Future.value();
    }

    setState(() => _isSubmitting = true);

    return ref.read(inventoryRepositoryProvider).adjustStock(
      orgId: orgId,
      itemId: _selectedItem!.id,
      delta: -qty,
    ).then((_) {
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Deducted $qty ${_selectedItem!.unit} of ${_selectedItem!.name}. Stock updated.',
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }).catchError((err) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to deduct material: $err'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final materials = inventoryAsync.value ?? [];

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_rounded, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Record Material Usage', style: AppTextStyles.titleMedium),
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
                const Text('Select Material', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                if (materials.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('No materials found in inventory.', style: AppTextStyles.bodySmall),
                  )
                else
                  DropdownButtonFormField<InventoryItem>(
                    initialValue: _selectedItem,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    hint: const Text('Choose raw material or component...'),
                    items: materials.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '[${item.sku}] ${item.name}',
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                            Text(
                              '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: item.isLowStock ? AppColors.error : AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (item) {
                      setState(() => _selectedItem = item);
                    },
                    validator: (val) => val == null ? 'Please choose an inventory item' : null,
                  ),

                if (_selectedItem != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current On-Hand Balance', style: AppTextStyles.bodySmall),
                            Text(
                              '${_selectedItem!.quantity.toStringAsFixed(2)} ${_selectedItem!.unit}',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: _selectedItem!.isLowStock ? AppColors.error : AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Text(
                            'Loc: ${_selectedItem!.location}',
                            style: AppTextStyles.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Text('Quantity Consumed', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 5.0',
                    suffixText: _selectedItem?.unit ?? 'units',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter quantity';
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) return 'Must be greater than 0';
                    if (_selectedItem != null && parsed > _selectedItem!.quantity) {
                      return 'Exceeds current stock (${_selectedItem!.quantity})';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                const Text('Work Order / Batch Reference', style: AppTextStyles.labelMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. WO-2026-081 cutting stage',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          onPressed: _isSubmitting ? null : _submitDeduction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textOnPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Deduct Stock'),
        ),
      ],
    );
  }
}
