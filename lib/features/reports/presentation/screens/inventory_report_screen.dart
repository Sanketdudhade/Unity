import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/csv_exporter.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/reports/presentation/widgets/csv_export_modal.dart';

/// Inventory Stock Balances & Safety Levels Audit Report with CSV Export.
class InventoryReportScreen extends ConsumerWidget {
  const InventoryReportScreen({super.key});

  void _exportCsv(BuildContext context, List<StockBalanceModel> balances) {
    final headers = [
      'SKU',
      'Material Name',
      'Location',
      'Current Quantity',
      'Available Quantity',
      'Allocated Quantity',
      'Unit',
      'Minimum Safety Stock',
      'Stock Status',
    ];

    final rows = balances.map((b) {
      return [
        b.materialSku,
        b.materialName,
        b.locationName,
        b.formattedCurrent,
        b.formattedAvailable,
        b.formattedAllocated,
        b.unit,
        b.formattedMinimumStock,
        b.isLowStock ? 'BELOW MINIMUM' : 'OPTIMAL',
      ];
    }).toList();

    final csvString = CsvExporter.generateCsv(headers: headers, rows: rows);

    CsvExportModal.show(
      context,
      title: 'Inventory Stock Balances Report',
      filename: 'inventory_balances_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csvString,
      recordCount: balances.length,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(stockBalancesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory Balances Report'),
        actions: [
          balancesAsync.maybeWhen(
            data: (balances) => IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _exportCsv(context, balances),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: balancesAsync.when(
        loading: () => const LoadingWidget(message: 'Compiling inventory balances...'),
        error: (err, _) => Center(
          child: Text('Failed to load report: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
        ),
        data: (balances) {
          if (balances.isEmpty) {
            return Center(
              child: Text('No inventory records found.', style: AppTextStyles.bodyMedium),
            );
          }

          final lowStockCount = balances.where((b) => b.isLowStock).length;

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Total Materials', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text('${balances.length}', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Optimal Stock', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text(
                          '${balances.length - lowStockCount}',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Low Stock Alerts', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text(
                          '$lowStockCount',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: lowStockCount > 0 ? AppColors.error : AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Balances List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: balances.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final b = balances[index];
                    final isLow = b.isLowStock;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isLow ? AppColors.error.withValues(alpha: 0.7) : AppColors.border,
                          width: isLow ? 1.4 : 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(b.materialSku, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                                const Spacer(),
                                if (isLow)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'LOW STOCK',
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w700),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.successLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'OPTIMAL',
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(b.materialName, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Available', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                      Text('${b.formattedAvailable} ${b.unit}', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Allocated', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                      Text('${b.formattedAllocated} ${b.unit}', style: AppTextStyles.bodyMedium),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Safety Min', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                      Text('${b.formattedMinimumStock} ${b.unit}', style: AppTextStyles.bodyMedium),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
