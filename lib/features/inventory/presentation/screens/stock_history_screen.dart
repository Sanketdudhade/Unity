import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';

/// Full-screen immutable audit trail for inventory transactions.
class StockHistoryScreen extends ConsumerStatefulWidget {
  final String? initialMaterialId;
  final String? materialName;

  const StockHistoryScreen({
    super.key,
    this.initialMaterialId,
    this.materialName,
  });

  @override
  ConsumerState<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  String _selectedType = 'ALL';

  final List<String> _types = [
    'ALL',
    'RECEIPT',
    'ISSUE',
    'ALLOCATION',
    'DEALLOCATION',
    'SCRAP',
    'ADJUSTMENT',
    'RETURN',
  ];

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'RECEIPT':
      case 'RETURN':
        return AppColors.success;
      case 'ISSUE':
        return AppColors.error;
      case 'ALLOCATION':
        return AppColors.info;
      case 'DEALLOCATION':
        return AppColors.primary;
      case 'SCRAP':
        return AppColors.warning;
      case 'ADJUSTMENT':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'RECEIPT':
        return Icons.call_received_rounded;
      case 'RETURN':
        return Icons.assignment_return_rounded;
      case 'ISSUE':
        return Icons.call_made_rounded;
      case 'ALLOCATION':
        return Icons.lock_outline_rounded;
      case 'DEALLOCATION':
        return Icons.lock_open_rounded;
      case 'SCRAP':
        return Icons.delete_sweep_rounded;
      case 'ADJUSTMENT':
        return Icons.tune_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(stockTransactionsStreamProvider(widget.initialMaterialId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.materialName != null ? 'Ledger: ${widget.materialName}' : 'Stock Transaction Ledger'),
      ),
      body: Column(
        children: [
          // Filter Chips Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _types.map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _selectedType = type),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Ledger Entries List
          Expanded(
            child: transactionsAsync.when(
              loading: () => const LoadingWidget(message: 'Loading ledger audit trail...'),
              error: (err, _) => Center(
                child: Text('Failed to load ledger: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
              ),
              data: (txList) {
                final filtered = _selectedType == 'ALL'
                    ? txList
                    : txList.where((tx) => tx.type.toUpperCase() == _selectedType).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text(
                          'No ledger transactions found',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final typeColor = _getTypeColor(tx.type);

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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getTypeIcon(tx.type), size: 14, color: typeColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        tx.type,
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: typeColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  tx.createdAt != null
                                      ? FactoryDateUtils.formatFactoryDateTime(tx.createdAt!)
                                      : 'Recent',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.materialName,
                                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${tx.materialSku} • Loc: ${tx.locationId}',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      tx.formattedDelta,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        color: tx.isPositiveDelta ? AppColors.success : AppColors.error,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Bal: ${tx.formattedBalanceAfter}',
                                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (tx.orderId != null && tx.orderId!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Linked Order: ${tx.orderId}',
                                  style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            if (tx.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                tx.notes,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.person_pin_circle_rounded, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'By ${tx.performedByName}',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tx.transactionNumber,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
