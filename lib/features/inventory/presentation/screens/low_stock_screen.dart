import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';

/// Screen listing materials below safety stock threshold with reorder actions.
class LowStockScreen extends ConsumerWidget {
  final bool isEmbedded;
  const LowStockScreen({super.key, this.isEmbedded = false});

  void _showRestockDialog(BuildContext context, WidgetRef ref, StockBalanceModel balance) {
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(authStateProvider).user;
    final orgId = user?.organizationId;
    if (orgId == null || orgId.isEmpty) return;

    final qtyController = TextEditingController(text: '50');
    final refController = TextEditingController(text: 'PO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final notesController = TextEditingController(text: 'Restock to meet minimum threshold');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock: ${balance.materialName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${balance.materialSku}', style: AppTextStyles.labelMedium),
            const SizedBox(height: 4),
            Text(
              'Current: ${balance.formattedCurrent} ${balance.unit} (Min: ${balance.formattedMinimumStock} ${balance.unit})',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Received Quantity (${balance.unit})',
                prefixIcon: const Icon(Icons.add_shopping_cart_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: refController,
              decoration: const InputDecoration(
                labelText: 'PO / Supplier Invoice Ref',
                prefixIcon: Icon(Icons.receipt_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final rawQty = double.tryParse(qtyController.text.trim());
              if (rawQty == null || rawQty <= 0) return;

              final baseUnits = balance.unitScale > 1
                  ? (rawQty * balance.unitScale).round()
                  : rawQty.round();

              Navigator.pop(ctx);

              try {
                await ref.read(inventoryRepositoryProvider).recordTransaction(
                      orgId: orgId,
                      materialId: balance.materialId,
                      materialSku: balance.materialSku,
                      materialName: balance.materialName,
                      type: 'RECEIPT',
                      quantityDelta: baseUnits,
                      locationId: balance.locationId,
                      locationName: balance.locationName,
                      performedByUid: user?.uid ?? 'admin',
                      performedByName: user?.fullName ?? 'Administrator',
                      referenceNumber: refController.text.trim(),
                      notes: notesController.text.trim(),
                      unit: balance.unit,
                      unitScale: balance.unitScale,
                    );

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Restocked $rawQty ${balance.unit} of ${balance.materialName}.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Restock failed: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockBalancesStreamProvider);

    final content = lowStockAsync.when(
        loading: () => const LoadingWidget(message: 'Checking safety stock thresholds...'),
        error: (err, _) => Center(
          child: Text('Error: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
        ),
        data: (lowStockList) {
          if (lowStockList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 72, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text('All stock levels are optimal!', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'No materials are currently below their minimum thresholds.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lowStockList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final balance = lowStockList[index];

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.error, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                                const SizedBox(width: 4),
                                Text(
                                  'BELOW MINIMUM',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            balance.locationName,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        balance.materialName,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'SKU: ${balance.materialSku}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Current Stock', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                Text(
                                  '${balance.formattedCurrent} ${balance.unit}',
                                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Minimum Safety', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                Text(
                                  '${balance.formattedMinimumStock} ${balance.unit}',
                                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                          label: const Text('Restock (GRN)'),
                          onPressed: () => _showRestockDialog(context, ref, balance),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Low Stock Alerts & Reorder'),
      ),
      body: content,
    );
  }
}
