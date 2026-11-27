import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/features/bom/data/models/bom_component_item.dart';
import 'package:unity/features/bom/data/models/bom_standard_item.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';

/// Modal dialog allowing operators and administrators to select BOM items
/// allocated to a specific production stage, and inspect that stage's inventory.
class StageBomInventoryDialog extends ConsumerStatefulWidget {
  final ProductModel product;
  final ProductBomModel bom;
  final OrderProcessModel process;
  final String orderId;
  final String orgId;

  const StageBomInventoryDialog({
    super.key,
    required this.product,
    required this.bom,
    required this.process,
    required this.orderId,
    required this.orgId,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductModel product,
    required ProductBomModel bom,
    required OrderProcessModel process,
    required String orderId,
    required String orgId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StageBomInventoryDialog(
        product: product,
        bom: bom,
        process: process,
        orderId: orderId,
        orgId: orgId,
      ),
    );
  }

  @override
  ConsumerState<StageBomInventoryDialog> createState() => _StageBomInventoryDialogState();
}

class _StageBomInventoryDialogState extends ConsumerState<StageBomInventoryDialog> {
  late Set<String> _selectedIds;
  late bool _isEditing;
  bool _isSaving = false;
  String _searchQuery = '';
  String _selectedSection = 'ALL';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    try {
      _selectedIds = Set.from(widget.process.selectedBomItemIds);
    } catch (_) {
      _selectedIds = {};
    }
    // If no items allocated yet, open straight in selection mode
    _isEditing = _selectedIds.isEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveAllocations() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(productionRepositoryProvider).updateProcessAllocatedBomItems(
            orgId: widget.orgId,
            orderId: widget.orderId,
            processId: widget.process.id,
            selectedBomItemIds: _selectedIds.toList(),
          );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Updated stage inventory: ${_selectedIds.length} BOM items allocated to Step ${widget.process.sequence} (${widget.process.name})!',
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save stage inventory: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final screenMedia = MediaQuery.sizeOf(context);
    final dialogWidth = min(960.0, screenMedia.width - 32);
    final dialogHeight = min(720.0, screenMedia.height - 32);

    // Filtered allocated items for view mode
    final allocatedComponents = widget.bom.mainComponents
        .where((c) => _selectedIds.contains(c.id))
        .toList();
    final allocatedStandards = widget.bom.standardItems
        .where((s) => _selectedIds.contains(s.id))
        .toList();
    final totalAllocated = allocatedComponents.length + allocatedStandards.length;

    // Filtered items for selection mode
    final query = _searchQuery.trim().toLowerCase();
    final filteredComponents = widget.bom.mainComponents.where((c) {
      if (_selectedSection != 'ALL' && _selectedSection != 'COMPONENTS') {
        if (_selectedSection != c.sectionName) return false;
      }
      if (query.isEmpty) return true;
      return c.nameOfPart.toLowerCase().contains(query) ||
          c.detNo.toLowerCase().contains(query) ||
          c.material.toLowerCase().contains(query);
    }).toList();

    final filteredStandards = widget.bom.standardItems.where((s) {
      if (_selectedSection != 'ALL' && _selectedSection != 'STD BOM') {
        return false;
      }
      if (query.isEmpty) return true;
      return s.nameOfPart.toLowerCase().contains(query) ||
          s.detNo.toLowerCase().contains(query) ||
          s.partCode.toLowerCase().contains(query) ||
          s.vendor.toLowerCase().contains(query);
    }).toList();

    // Distinct sections from main components
    final sections = [
      'ALL',
      if (widget.bom.mainComponents.isNotEmpty) 'COMPONENTS',
      if (widget.bom.standardItems.isNotEmpty) 'STD BOM',
      ...widget.bom.mainComponents
          .map((c) => c.sectionName)
          .where((s) => s.isNotEmpty)
          .toSet(),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0F766E), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Step ${widget.process.sequence}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.process.name} — Stage Inventory',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Product: ${widget.product.partCode} • Tool: ${widget.bom.toolName.isNotEmpty ? widget.bom.toolName : widget.bom.toolNo} (BOM V${widget.bom.version})',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isEditing)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: const Text('Edit / Select Items'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => setState(() => _isEditing = true),
                  )
                else if (totalAllocated > 0)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text('View Allocated ($totalAllocated)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => setState(() => _isEditing = false),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Content Area
            Expanded(
              child: _isEditing
                  ? _buildSelectionView(
                      theme: theme,
                      tokens: tokens,
                      sections: sections,
                      components: filteredComponents,
                      standards: filteredStandards,
                    )
                  : _buildAllocatedView(
                      theme: theme,
                      tokens: tokens,
                      allocatedComponents: allocatedComponents,
                      allocatedStandards: allocatedStandards,
                    ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Footer
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedIds.isNotEmpty
                        ? Colors.green.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _selectedIds.isNotEmpty
                          ? Colors.green.withValues(alpha: 0.4)
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    '${_selectedIds.length} / ${widget.bom.totalItemsCount} BOM Items Allocated to this Stage',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _selectedIds.isNotEmpty ? Colors.green[800] : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (_isEditing) ...[
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => setState(() {
                              try {
                                _selectedIds = Set.from(widget.process.selectedBomItemIds);
                              } catch (_) {
                                _selectedIds = {};
                              }
                              _isEditing = totalAllocated > 0 ? false : true;
                            }),
                    child: const Text('Cancel Changes'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save Stage Inventory'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isSaving ? null : _saveAllocations,
                  ),
                ] else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- View Mode: Displays ONLY items allocated to this stage ---
  Widget _buildAllocatedView({
    required ThemeData theme,
    required dynamic tokens,
    required List<BomComponentItem> allocatedComponents,
    required List<BomStandardItem> allocatedStandards,
  }) {
    if (allocatedComponents.isEmpty && allocatedStandards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 14),
            Text(
              'No BOM Materials Allocated to ${widget.process.name} Yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Select which plates, inserts, pins, or standard off-the-shelf parts are required for this stage.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
              label: const Text('Select Materials from BOM'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _isEditing = true),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (allocatedComponents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.view_in_ar_rounded, size: 16, color: Color(0xFF0F766E)),
                  const SizedBox(width: 6),
                  Text(
                    'Main Components (${allocatedComponents.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Det #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Part Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Finish Size (HxWxL)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Section / Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Stock Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: allocatedComponents.map((c) {
                  final finishSize = '${c.finishHeight} x ${c.finishWidth} x ${c.finishLength}'
                      .replaceAll(RegExp(r'^\s*x\s*|\s*x\s*$'), '');
                  return DataRow(
                    cells: [
                      DataCell(Text(c.detNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataCell(Text(c.nameOfPart, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataCell(Text(c.qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataCell(Text(c.material.isNotEmpty ? c.material : '-', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(finishSize.isNotEmpty ? finishSize : '-', style: const TextStyle(fontSize: 11))),
                      DataCell(Text(c.sectionName.isNotEmpty ? c.sectionName : 'GENERAL', style: const TextStyle(fontSize: 11))),
                      DataCell(
                        c.isMapped
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    (c.inventoryMaterialName != null && c.inventoryMaterialName!.isNotEmpty)
                                        ? c.inventoryMaterialName!
                                        : 'Linked',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 11),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Unmapped',
                                    style: TextStyle(color: Colors.orange[800], fontSize: 11),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (allocatedStandards.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 16, color: Colors.indigo),
                  const SizedBox(width: 6),
                  Text(
                    'Standard Hardware & Off-The-Shelf Parts (${allocatedStandards.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Det #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Part Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Part Code / Spec', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Stock Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: allocatedStandards.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(Text(s.detNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataCell(Text(s.nameOfPart, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataCell(Text(s.partCode.isNotEmpty ? s.partCode : '-', style: const TextStyle(fontSize: 11))),
                      DataCell(Text(s.qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataCell(Text(s.vendor.isNotEmpty ? s.vendor : '-', style: const TextStyle(fontSize: 11))),
                      DataCell(
                        s.isMapped
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    (s.inventoryMaterialName != null && s.inventoryMaterialName!.isNotEmpty)
                                        ? s.inventoryMaterialName!
                                        : 'Linked',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 11),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 14),
                                  const SizedBox(width: 4),
                                  Text('Unmapped', style: TextStyle(color: Colors.orange[800], fontSize: 11)),
                                ],
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Selection Mode: Checklist of all BOM components & standard items ---
  Widget _buildSelectionView({
    required ThemeData theme,
    required dynamic tokens,
    required List<String> sections,
    required List<BomComponentItem> components,
    required List<BomStandardItem> standards,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter bar & Search
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search BOM part name, det #, material or code...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.select_all_rounded, size: 15),
              label: const Text('Select All Visible'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () {
                setState(() {
                  for (final c in components) {
                    _selectedIds.add(c.id);
                  }
                  for (final s in standards) {
                    _selectedIds.add(s.id);
                  }
                });
              },
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.deselect_rounded, size: 15),
              label: const Text('Deselect All'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () => setState(() => _selectedIds.clear()),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Section Filter Chips
        if (sections.length > 2)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sections.map((sec) {
                final isSelected = _selectedSection == sec;
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 4),
                  child: FilterChip(
                    label: Text(
                      sec,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedSection = sec),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),

        // Checkable List
        Expanded(
          child: (components.isEmpty && standards.isEmpty)
              ? Center(
                  child: Text(
                    'No BOM items match "$_searchQuery"',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView(
                  children: [
                    if (components.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Components (${components.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      ...components.map((c) {
                        final isChecked = _selectedIds.contains(c.id);
                        final finishSize = '${c.finishHeight} x ${c.finishWidth} x ${c.finishLength}'
                            .replaceAll(RegExp(r'^\s*x\s*|\s*x\s*$'), '');

                        return CheckboxListTile(
                          value: isChecked,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFF0F766E),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(c.id);
                              } else {
                                _selectedIds.remove(c.id);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Det ${c.detNo}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.nameOfPart,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              Text(
                                'Qty: ${c.qty}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Mat: ${c.material.isNotEmpty ? c.material : "-"} • Size: ${finishSize.isNotEmpty ? finishSize : "-"} • Sec: ${c.sectionName.isNotEmpty ? c.sectionName : "GENERAL"}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    if (standards.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Standard & Off-The-Shelf Parts (${standards.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      ...standards.map((s) {
                        final isChecked = _selectedIds.contains(s.id);
                        return CheckboxListTile(
                          value: isChecked,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFF0F766E),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(s.id);
                              } else {
                                _selectedIds.remove(s.id);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Det ${s.detNo}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.nameOfPart,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              Text(
                                'Qty: ${s.qty}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Code: ${s.partCode.isNotEmpty ? s.partCode : "-"} • Vendor: ${s.vendor.isNotEmpty ? s.vendor : "-"}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
