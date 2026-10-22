import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/csv_exporter.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/reports/presentation/widgets/csv_export_modal.dart';

/// Detailed Production Orders Status & Throughput Report with CSV Export.
class ProductionReportScreen extends ConsumerWidget {
  const ProductionReportScreen({super.key});

  void _exportCsv(BuildContext context, List<ProductionOrder> orders) {
    final headers = [
      'Order Number',
      'Product Name',
      'Target Quantity',
      'Completed Quantity',
      'Unit',
      'Progress %',
      'Status',
      'Priority',
      'Start Date',
      'Due Date',
      'Customer',
    ];

    final rows = orders.map((o) {
      return [
        o.orderNumber,
        o.productName,
        o.targetQuantity,
        o.completedQuantity,
        o.unit,
        '${(o.progressPercentage * 100).toStringAsFixed(1)}%',
        o.status.toUpperCase(),
        o.priority.toUpperCase(),
        o.startDate != null ? FactoryDateUtils.formatFactoryDate(o.startDate!) : 'N/A',
        o.dueDate != null ? FactoryDateUtils.formatFactoryDate(o.dueDate!) : 'N/A',
        o.customerName,
      ];
    }).toList();

    final csvString = CsvExporter.generateCsv(headers: headers, rows: rows);

    CsvExportModal.show(
      context,
      title: 'Production Orders Report',
      filename: 'production_orders_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csvString,
      recordCount: orders.length,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(productionOrdersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Production Orders Report'),
        actions: [
          ordersAsync.maybeWhen(
            data: (orders) => IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _exportCsv(context, orders),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const LoadingWidget(message: 'Generating production report...'),
        error: (err, _) => Center(
          child: Text('Failed to load report: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Text('No production orders recorded yet.', style: AppTextStyles.bodyMedium),
            );
          }

          final activeCount = orders.where((o) => o.isInProduction).length;
          final completedCount = orders.where((o) => o.isCompleted).length;

          return Column(
            children: [
              // Summary KPI header
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Total Orders', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text('${orders.length}', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('In Production', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text('$activeCount', style: AppTextStyles.titleMedium.copyWith(color: AppColors.info, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Completed', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        Text('$completedCount', style: AppTextStyles.titleMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Orders List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    final pct = o.progressPercentage;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(o.orderNumber, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: o.isCompleted
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : AppColors.info.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    o.status.toUpperCase(),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: o.isCompleted ? AppColors.success : AppColors.info,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(o.productName, style: AppTextStyles.bodyMedium),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Output: ${o.completedQuantity.toInt()} / ${o.targetQuantity.toInt()} ${o.unit}',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  o.isCompleted ? AppColors.success : AppColors.primary,
                                ),
                              ),
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
