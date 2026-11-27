import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/empty_state.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
import 'package:unity/features/bom/presentation/widgets/bom_import_dialog.dart';
import 'package:unity/features/bom/presentation/widgets/product_bom_viewer_sheet.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/products/presentation/providers/product_providers.dart';

/// Embedded Tab within Materials & Stock screen to manage product-wise Bill of Materials.
class ProductBomsTab extends ConsumerStatefulWidget {
  const ProductBomsTab({super.key});

  @override
  ConsumerState<ProductBomsTab> createState() => _ProductBomsTabState();
}

class _ProductBomsTabState extends ConsumerState<ProductBomsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _bomFilter = 'ALL'; // 'ALL', 'WITH_BOM', 'NO_BOM'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBomViewer(ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => ProductBomViewerSheet(product: product),
    );
  }

  void _openImportDialog(ProductModel product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BomImportDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final productsAsync = ref.watch(productsStreamProvider);

    return Column(
      children: [
        // Filter and Search Toolbar
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
              final isWide = constraints.maxWidth >= 700;
              final searchWidget = SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search products by name, code, drawing #, or customer...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
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
                  ),
                ),
              );

              final filterPills = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterPill('ALL', 'All Products', isDark, theme),
                    const SizedBox(width: 6),
                    _buildFilterPill('WITH_BOM', 'Has BOM', isDark, theme),
                    const SizedBox(width: 6),
                    _buildFilterPill('NO_BOM', 'Missing BOM', isDark, theme),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchWidget,
                    const SizedBox(height: 10),
                    filterPills,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchWidget),
                  const SizedBox(width: 12),
                  filterPills,
                ],
              );
            },
          ),
        ),

        // Product Catalog Grid / List for BOMs
        Expanded(
          child: productsAsync.when(
            loading: () => const LoadingWidget(message: 'Loading products...'),
            error: (err, _) => Center(
              child: Text('Error loading products: $err', style: TextStyle(color: tokens.danger)),
            ),
            data: (products) {
              final query = _searchController.text.trim().toLowerCase();
              final filtered = products.where((p) {
                final matchesFilter = _bomFilter == 'ALL' ||
                    (_bomFilter == 'WITH_BOM' && p.hasBom) ||
                    (_bomFilter == 'NO_BOM' && !p.hasBom);

                final matchesQuery = query.isEmpty ||
                    p.partCode.toLowerCase().contains(query) ||
                    p.name.toLowerCase().contains(query) ||
                    p.drawingNumber.toLowerCase().contains(query) ||
                    p.customerReference.toLowerCase().contains(query);

                return matchesFilter && matchesQuery;
              }).toList();

              if (filtered.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.account_tree_outlined,
                  title: products.isEmpty ? 'No products registered yet' : 'No matching products',
                  description: products.isEmpty
                      ? 'Add products to the Product Catalog to configure Bill of Materials.'
                      : 'No products match the selected criteria.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final prod = filtered[index];

                  return InkWell(
                    onTap: () => _openBomViewer(prod),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        // Code Badge
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tokens.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.precision_manufacturing_outlined, color: theme.colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 14),

                        // Info
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    prod.partCode,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    prod.revision,
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                prod.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (prod.customerReference.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Customer: ${prod.customerReference} | Drawing: ${prod.drawingNumber.isNotEmpty ? prod.drawingNumber : '-'}',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // BOM Status
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusChip(
                                label: prod.hasBom ? 'BOM V${prod.bomVersion}' : 'NO BOM ATTACHED',
                                variant: prod.hasBom ? StatusVariant.info : StatusVariant.warning,
                                icon: prod.hasBom ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                prod.hasBom
                                    ? 'Updated: ${prod.bomUpdatedAt?.toString().split(' ').first ?? '-'}'
                                    : 'Upload Excel to attach',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons
                        Wrap(
                          spacing: 8,
                          children: [
                            if (prod.hasBom)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.account_tree_outlined, size: 15),
                                label: const Text('Manage BOM'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _openBomViewer(prod),
                              )
                            else
                              ElevatedButton.icon(
                                icon: const Icon(Icons.upload_file_rounded, size: 15),
                                label: const Text('Import BOM'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _openImportDialog(prod),
                              ),
                            if (prod.hasBom)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.file_upload_outlined, size: 15),
                                label: const Text('Replace'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _openImportDialog(prod),
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
    );
  }

  Widget _buildFilterPill(String filterKey, String label, bool isDark, ThemeData theme) {
    final isSelected = _bomFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _bomFilter = filterKey),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFA6B6CB) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
