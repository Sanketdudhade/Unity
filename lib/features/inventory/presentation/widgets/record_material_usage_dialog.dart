import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/inventory_item_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';

/// Modal dialog allowing shop-floor workers to log consumed raw materials with real-time stock deduction.
/// Conforms to Section 5F & 7: Touch-friendly on Android mobile, responsive on Windows desktop, Dark/Light mode aware.
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

  Future<void> _submitDeduction() async {
    final messenger = ScaffoldMessenger.of(context);
    final tokens = context.adminTokens;
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;

    if (orgId == null || orgId.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Cannot log usage: Organization ID missing.'),
          backgroundColor: tokens.danger,
        ),
      );
      return;
    }

    if (_selectedItem == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Please select a material from the inventory list.'),
          backgroundColor: tokens.danger,
        ),
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid positive quantity.'),
          backgroundColor: tokens.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(inventoryRepositoryProvider).adjustStock(
        orgId: orgId,
        itemId: _selectedItem!.id,
        delta: -qty,
        workOrder: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        performedByUid: user?.uid,
        performedByName: user?.fullName,
      );

      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Deducted $qty ${_selectedItem!.unit} of ${_selectedItem!.name}. Stock updated.',
            ),
            backgroundColor: tokens.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to deduct material: $err'),
            backgroundColor: tokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final inventoryAsync = ref.watch(inventoryStreamProvider);
    final materials = inventoryAsync.value ?? [];

    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);

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
            child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F766E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Record Material Usage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
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
                Text(
                  'Select Raw Material / Component',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                const SizedBox(height: 6),
                if (materials.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('No materials found in inventory.', style: TextStyle(fontSize: 12, color: textSecondary)),
                  )
                else
                  DropdownButtonFormField<InventoryItem>(
                    initialValue: _selectedItem,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    hint: const Text('Choose inventory item...'),
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
                                style: TextStyle(fontSize: 13, color: textPrimary),
                              ),
                            ),
                            Text(
                              '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: item.isLowStock ? tokens.danger : const Color(0xFF0F766E),
                                fontWeight: FontWeight.w700,
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
                      color: isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current On-Hand Balance', style: TextStyle(fontSize: 11, color: textSecondary)),
                            Text(
                              '${_selectedItem!.quantity.toStringAsFixed(2)} ${_selectedItem!.unit}',
                              style: TextStyle(
                                fontSize: 15,
                                color: _selectedItem!.isLowStock ? tokens.danger : const Color(0xFF0F766E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            'Loc: ${_selectedItem!.location}',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  'Quantity Consumed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 5.0',
                    suffixText: _selectedItem?.unit ?? 'units',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1)),
                    ),
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
                Text(
                  'Work Order / Batch Reference',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: 'e.g. WO-2026-081 cutting stage',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              : const Text('Deduct Stock'),
        ),
      ],
    );
  }
}
