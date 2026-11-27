import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/features/bom/data/models/bom_component_item.dart';
import 'package:unity/features/bom/data/models/bom_mapping_status.dart';
import 'package:unity/features/bom/data/models/bom_standard_item.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';
import 'package:unity/features/inventory/data/models/material_model.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';

/// Interactive dialog for inspecting BOM mapping and manually re-assigning
/// or searching inventory materials.
class BomMappingDialog extends ConsumerStatefulWidget {
  final ProductBomModel bom;
  final Function(ProductBomModel updatedBom) onBomUpdated;

  const BomMappingDialog({
    super.key,
    required this.bom,
    required this.onBomUpdated,
  });

  @override
  ConsumerState<BomMappingDialog> createState() => _BomMappingDialogState();
}

class _BomMappingDialogState extends ConsumerState<BomMappingDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ProductBomModel _currentBom;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentBom = widget.bom;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _mapComponent(BomComponentItem item, MaterialModel material) {
    final updatedList = _currentBom.mainComponents.map((c) {
      if (c.id == item.id) {
        return c.copyWith(
          inventoryMaterialId: material.id,
          inventoryMaterialSku: material.sku,
          inventoryMaterialName: material.name,
          inventoryUnit: material.unit,
          inventoryUnitScale: material.unitScale,
          mappingStatus: BomMappingStatus.manuallyMapped,
        );
      }
      return c;
    }).toList();

    setState(() {
      _currentBom = _currentBom.copyWith(mainComponents: updatedList);
    });
    widget.onBomUpdated(_currentBom);
  }

  void _unmapComponent(BomComponentItem item) {
    final updatedList = _currentBom.mainComponents.map((c) {
      if (c.id == item.id) {
        return c.copyWith(
          inventoryMaterialId: null,
          inventoryMaterialSku: null,
          inventoryMaterialName: null,
          inventoryUnit: null,
          mappingStatus: BomMappingStatus.unmatched,
        );
      }
      return c;
    }).toList();

    setState(() {
      _currentBom = _currentBom.copyWith(mainComponents: updatedList);
    });
    widget.onBomUpdated(_currentBom);
  }

  void _mapStandardItem(BomStandardItem item, MaterialModel material) {
    final updatedList = _currentBom.standardItems.map((s) {
      if (s.id == item.id) {
        return s.copyWith(
          inventoryMaterialId: material.id,
          inventoryMaterialSku: material.sku,
          inventoryMaterialName: material.name,
          inventoryUnit: material.unit,
          inventoryUnitScale: material.unitScale,
          mappingStatus: BomMappingStatus.manuallyMapped,
        );
      }
      return s;
    }).toList();

    setState(() {
      _currentBom = _currentBom.copyWith(standardItems: updatedList);
    });
    widget.onBomUpdated(_currentBom);
  }

  void _unmapStandardItem(BomStandardItem item) {
    final updatedList = _currentBom.standardItems.map((s) {
      if (s.id == item.id) {
        return s.copyWith(
          inventoryMaterialId: null,
          inventoryMaterialSku: null,
          inventoryMaterialName: null,
          inventoryUnit: null,
          mappingStatus: BomMappingStatus.unmatched,
        );
      }
      return s;
    }).toList();

    setState(() {
      _currentBom = _currentBom.copyWith(standardItems: updatedList);
    });
    widget.onBomUpdated(_currentBom);
  }

  void _showMaterialPicker({
    required BuildContext context,
    required String title,
    required List<MaterialModel> materials,
    required Function(MaterialModel selected) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = materials.where((m) {
              final q = searchQuery.toLowerCase();
              return m.name.toLowerCase().contains(q) ||
                  m.sku.toLowerCase().contains(q) ||
                  m.category.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search material by name, SKU or category...',
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) {
                      setSheetState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching inventory materials found.'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final mat = filtered[index];
                              return ListTile(
                                dense: true,
                                title: Text(mat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('SKU: ${mat.sku} | Unit: ${mat.unit} | ${mat.category}'),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onSelect(mat);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final materialsAsync = ref.watch(materialsStreamProvider);
    final materials = materialsAsync.value ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 900,
        height: 650,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_rounded, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Mapping — ${_currentBom.productCode}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Match BOM components and standard parts with live stock inventory items.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              indicatorColor: theme.colorScheme.primary,
              tabs: [
                Tab(text: 'Main Components (${_currentBom.mainComponents.length})'),
                Tab(text: 'Standard Parts (${_currentBom.standardItems.length})'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Main components
                  _buildComponentsList(materials, tokens, theme),
                  // Tab 2: Standard items
                  _buildStandardsList(materials, tokens, theme),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentsList(List<MaterialModel> materials, dynamic tokens, ThemeData theme) {
    if (_currentBom.mainComponents.isEmpty) {
      return const Center(child: Text('No main components in this BOM.'));
    }

    return ListView.separated(
      itemCount: _currentBom.mainComponents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _currentBom.mainComponents[index];
        final isMapped = c.isMapped;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMapped ? Colors.green.withOpacity(0.4) : theme.colorScheme.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.detNo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nameOfPart,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      'Material: ${c.material} | Qty: ${c.qty}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: isMapped
                    ? Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.inventoryMaterialName ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'SKU: ${c.inventoryMaterialSku ?? '-'} (${c.mappingStatus.label})',
                                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            tooltip: 'Unmap',
                            onPressed: () => _unmapComponent(c),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Unmapped',
                            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 14),
                label: Text(isMapped ? 'Change' : 'Map Item'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _showMaterialPicker(
                  context: context,
                  title: 'Map "${c.nameOfPart}" to Inventory',
                  materials: materials,
                  onSelect: (mat) => _mapComponent(c, mat),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandardsList(List<MaterialModel> materials, dynamic tokens, ThemeData theme) {
    if (_currentBom.standardItems.isEmpty) {
      return const Center(child: Text('No standard items in this BOM.'));
    }

    return ListView.separated(
      itemCount: _currentBom.standardItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = _currentBom.standardItems[index];
        final isMapped = s.isMapped;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMapped ? Colors.green.withOpacity(0.4) : theme.colorScheme.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.detNo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nameOfPart,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      'Part Code: ${s.partCode} | Vendor: ${s.vendor} | Qty: ${s.qty}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: isMapped
                    ? Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.inventoryMaterialName ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'SKU: ${s.inventoryMaterialSku ?? '-'} (${s.mappingStatus.label})',
                                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            tooltip: 'Unmap',
                            onPressed: () => _unmapStandardItem(s),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Unmapped',
                            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 14),
                label: Text(isMapped ? 'Change' : 'Map Item'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _showMaterialPicker(
                  context: context,
                  title: 'Map "${s.nameOfPart}" to Inventory',
                  materials: materials,
                  onSelect: (mat) => _mapStandardItem(s, mat),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
