import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/inventory/presentation/widgets/record_material_usage_dialog.dart';

/// Material consumption tab conforming to Section 5F & 6: View balances & log usage.
class EmployeeMaterialsView extends ConsumerStatefulWidget {
  const EmployeeMaterialsView({super.key});

  @override
  ConsumerState<EmployeeMaterialsView> createState() => _EmployeeMaterialsViewState();
}

class _EmployeeMaterialsViewState extends ConsumerState<EmployeeMaterialsView> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    final inventoryAsync = ref.watch(inventoryStreamProvider);

    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(inventoryStreamProvider);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Bar with Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Material Consumption',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Log consumed raw materials & components for your active production run.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => RecordMaterialUsageDialog.show(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Log Usage'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Search Field
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF152235) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search raw materials by SKU, item name, unit...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                  ),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() => _search = val.trim().toLowerCase());
                },
              ),
            ),

            const SizedBox(height: 16),

            // 3. Materials List
            inventoryAsync.when(
              loading: () => const LoadingWidget(message: 'Loading inventory stocks...'),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Error loading inventory: $e', style: TextStyle(color: tokens.danger)),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  if (_search.isEmpty) return true;
                  final nameMatch = item.name.toLowerCase().contains(_search);
                  final skuMatch = item.sku.toLowerCase().contains(_search);
                  final unitMatch = item.unit.toLowerCase().contains(_search);
                  return nameMatch || skuMatch || unitMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF152235) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 40, color: textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No materials found',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _search.isNotEmpty
                              ? 'No inventory item matches "$_search".'
                              : 'No raw materials or components in the stock database.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: filtered.map((item) {
                    final isLow = item.isLowStock;
                    final cardBg = isDark ? const Color(0xFF152235) : Colors.white;
                    final cardBorder = isLow
                        ? tokens.danger.withValues(alpha: 0.4)
                        : (isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isLow
                                  ? tokens.danger.withValues(alpha: isDark ? 0.2 : 0.1)
                                  : const Color(0xFF0F766E).withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.category_rounded,
                              size: 20,
                              color: isLow ? tokens.danger : const Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.sku,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Available: ',
                                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                                    ),
                                    Text(
                                      '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isLow ? tokens.danger : textPrimary,
                                      ),
                                    ),
                                    if (isLow) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: tokens.danger.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'LOW STOCK',
                                          style: TextStyle(
                                            color: tokens.danger,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => RecordMaterialUsageDialog.show(context),
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 14),
                            label: const Text('Log Usage'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F766E),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
