import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/bom/data/models/product_bom_file_model.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';
import 'package:unity/features/bom/data/services/bom_export_service.dart';
import 'package:unity/features/bom/presentation/providers/bom_providers.dart';
import 'package:unity/features/bom/presentation/widgets/bom_import_dialog.dart';
import 'package:unity/features/bom/presentation/widgets/bom_mapping_dialog.dart';
import 'package:unity/features/products/data/models/product_model.dart';

/// Comprehensive BOM viewer, document manager & export center for a product.
class ProductBomViewerSheet extends ConsumerStatefulWidget {
  final ProductModel product;

  const ProductBomViewerSheet({super.key, required this.product});

  @override
  ConsumerState<ProductBomViewerSheet> createState() => _ProductBomViewerSheetState();
}

class _ProductBomViewerSheetState extends ConsumerState<ProductBomViewerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSection = 'ALL';
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openImportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BomImportDialog(product: widget.product),
    );
  }

  void _openMappingDialog(ProductBomModel bom) {
    showDialog(
      context: context,
      builder: (_) => BomMappingDialog(
        bom: bom,
        onBomUpdated: (updated) async {
          final authState = ref.read(authStateProvider);
          final orgId = authState.user?.organizationId ?? '';
          if (orgId.isNotEmpty) {
            await ref.read(bomRepositoryProvider).saveBom(
                  orgId: orgId,
                  productId: widget.product.id,
                  bom: updated,
                  makeActive: true,
                );
          }
        },
      ),
    );
  }

  Future<void> _exportBom(ProductBomModel bom, bool isExcel) async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final authState = ref.read(authStateProvider);
      final orgId = authState.user?.organizationId ?? '';
      final user = authState.user;

      final extension = isExcel ? 'xlsx' : 'csv';
      final fileName = '${widget.product.partCode}_${widget.product.name.replaceAll(' ', '_')}_BOM_V${bom.version}.$extension';

      final bytes = isExcel
          ? BomExportService.generateBomXlsx(product: widget.product, bom: bom)
          : BomExportService.generateBomCsv(product: widget.product, bom: bom);

      // 1. Let user save to disk / prompt file save location
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save BOM Export ($extension)',
        fileName: fileName,
        bytes: bytes,
        mimeType: isExcel
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'text/csv',
      );

      if (savedUri == null) {
        // User cancelled save
        return;
      }

      // 2. Register export in Firestore under product's bomFiles collection
      if (orgId.isNotEmpty) {
        final repo = ref.read(bomRepositoryProvider);
        await repo.recordBomFile(
          orgId: orgId,
          productId: widget.product.id,
          fileRecord: ProductBomFileModel(
            id: '',
            productId: widget.product.id,
            bomId: bom.id,
            fileName: fileName,
            fileType: isExcel ? 'EXCEL' : 'CSV',
            storagePath: 'organizations/$orgId/products/${widget.product.id}/bom/${bom.id}/exports/$fileName',
            downloadUrl: '',
            version: bom.version,
            generatedByUid: user?.uid ?? '',
            generatedByName: user?.fullName ?? 'Admin',
            generatedAt: DateTime.now(),
            fileSize: bytes.length,
          ),
        );
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Exported $fileName successfully!'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to export BOM: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteBom(ProductBomModel bom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete BOM'),
        content: Text('Are you sure you want to delete BOM V${bom.version} for ${widget.product.partCode}? Historical production orders will remain intact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authState = ref.read(authStateProvider);
      final orgId = authState.user?.organizationId ?? '';
      if (orgId.isNotEmpty) {
        await ref.read(bomRepositoryProvider).deleteBom(
              orgId: orgId,
              productId: widget.product.id,
              bomId: bom.id,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('BOM deleted successfully.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final bomsAsync = ref.watch(productBomsStreamProvider(widget.product.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 1100,
        height: 780,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.account_tree_outlined, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Bill of Materials (BOM) — ${widget.product.partCode}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.product.name,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Full engineering component hierarchy, raw materials, manufacturing stages, and inventory links.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Import / Replace BOM'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  ),
                  onPressed: _openImportDialog,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: bomsAsync.when(
                loading: () => const LoadingWidget(message: 'Loading Bill of Materials...'),
                error: (err, _) => Center(
                  child: Text('Error loading BOM: $err', style: TextStyle(color: tokens.danger)),
                ),
                data: (boms) {
                  if (boms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 60, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          const Text(
                            'No BOM Registered for this Product',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Upload the Tool/Die BOM Excel sheet to enable component inventory tracking.',
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Upload BOM Excel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _openImportDialog,
                          ),
                        ],
                      ),
                    );
                  }

                  // Find active BOM (or first in list)
                  final activeBom = boms.firstWhere((b) => b.isActive, orElse: () => boms.first);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active BOM Banner & Metadata
                      _buildHeaderBanner(activeBom, boms, theme, tokens),
                      const SizedBox(height: 12),

                      // Tabs for Components vs Standard Items vs Files
                      TabBar(
                        controller: _tabController,
                        labelColor: theme.colorScheme.primary,
                        indicatorColor: theme.colorScheme.primary,
                        tabs: [
                          Tab(text: 'Main Components (${activeBom.mainComponents.length})'),
                          Tab(text: 'Standard Parts & Off-The-Shelf (${activeBom.standardItems.length})'),
                          const Tab(text: 'Exported BOM Files'),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildComponentsTable(activeBom, theme, tokens),
                            _buildStandardItemsTable(activeBom, theme, tokens),
                            _buildFilesTab(activeBom, theme, tokens),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(
      ProductBomModel activeBom, List<ProductBomModel> allVersions, ThemeData theme, dynamic tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACTIVE V${activeBom.version}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tool: ${activeBom.toolName.isNotEmpty ? activeBom.toolName : activeBom.toolNo}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${activeBom.customer} | Sheet: ${activeBom.materialSheet} (${activeBom.materialThickness}) | Designer: ${activeBom.designedBy}',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.table_view_rounded, size: 14),
                label: const Text('Export Excel (.xlsx)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: _isExporting ? null : () => _exportBom(activeBom, true),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.text_snippet_outlined, size: 14),
                label: const Text('Export CSV (.csv)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: _isExporting ? null : () => _exportBom(activeBom, false),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.hub_outlined, size: 14),
                label: const Text('Inventory Links'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: () => _openMappingDialog(activeBom),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                tooltip: 'Delete BOM Version',
                onPressed: () => _deleteBom(activeBom),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsTable(ProductBomModel bom, ThemeData theme, dynamic tokens) {
    // Collect distinct sections from mainComponents
    final mainSections = bom.mainComponents.map((c) => c.sectionName).toSet().toList();

    // Reorder sections: insert 'STD BOM' directly before 'OTHER ITEM' (or other non-casting/non-insert sections)
    final orderedSections = <String>[];
    bool stdBomInserted = false;

    for (final sec in mainSections) {
      if (!stdBomInserted && (sec.toUpperCase().contains('OTHER') || sec.toUpperCase().contains('MISC'))) {
        if (bom.standardItems.isNotEmpty) {
          orderedSections.add('STD BOM');
          stdBomInserted = true;
        }
      }
      orderedSections.add(sec);
    }
    if (!stdBomInserted && bom.standardItems.isNotEmpty) {
      orderedSections.add('STD BOM');
    }

    final sections = ['ALL', ...orderedSections];

    return Column(
      children: [
        if (sections.length > 2)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sections.map((sec) {
                final isSelected = _selectedSection == sec;
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 6),
                  child: FilterChip(
                    label: Text(
                      sec == 'STD BOM' ? 'STD BOM (${bom.standardItems.length})' : sec,
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
        Expanded(
          child: _selectedSection == 'STD BOM'
              ? _buildStandardItemsTable(bom, theme, tokens)
              : _buildMainTableRows(bom, theme, tokens),
        ),
      ],
    );
  }

  Widget _buildMainTableRows(ProductBomModel bom, ThemeData theme, dynamic tokens) {
    final filtered = _selectedSection == 'ALL'
        ? bom.mainComponents
        : bom.mainComponents.where((c) => c.sectionName == _selectedSection).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 46,
          columnSpacing: 14,
          columns: const [
            DataColumn(label: Text('Det #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Part Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Finish Size (HxWxL)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Row Size (HxWxL)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Processes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Stock Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: filtered.map((c) {
            final finishSize = '${c.finishHeight} x ${c.finishWidth} x ${c.finishLength}'.replaceAll(RegExp(r'^\s*x\s*|\s*x\s*$'), '');
            final rowSize = '${c.rowHeight} x ${c.rowWidth} x ${c.rowLength}'.replaceAll(RegExp(r'^\s*x\s*|\s*x\s*$'), '');

            final List<String> procs = [];
            if (c.millingGrinding.isNotEmpty) procs.add('Mill');
            if (c.vmc.isNotEmpty) procs.add('VMC');
            if (c.wireCut.isNotEmpty) procs.add('WireCut');
            if (c.hardening.isNotEmpty) procs.add('Hard');
            if (c.jigBoring.isNotEmpty) procs.add('Jig');

            return DataRow(
              cells: [
                DataCell(Text(c.detNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.nameOfPart, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      if (c.sectionName.isNotEmpty)
                        Text(c.sectionName, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                DataCell(Text(c.qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataCell(Text(c.material, style: const TextStyle(fontSize: 12))),
                DataCell(Text(finishSize.isNotEmpty ? finishSize : '-', style: const TextStyle(fontSize: 11))),
                DataCell(Text(rowSize.isNotEmpty ? rowSize : '-', style: const TextStyle(fontSize: 11))),
                DataCell(Text(procs.isNotEmpty ? procs.join(', ') : '-', style: const TextStyle(fontSize: 11))),
                DataCell(
                  c.isMapped
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 14),
                            const SizedBox(width: 4),
                            Text(
                              c.inventoryMaterialSku ?? c.inventoryMaterialName ?? 'Mapped',
                              style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 14),
                            const SizedBox(width: 4),
                            Text('Unmapped', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                          ],
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStandardItemsTable(ProductBomModel bom, ThemeData theme, dynamic tokens) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 46,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Det #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Part Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Vendor / Brand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Part Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Inventory Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: bom.standardItems.map((s) {
            return DataRow(
              cells: [
                DataCell(Text(s.detNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataCell(Text(s.nameOfPart, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                DataCell(Text(s.vendor.isNotEmpty ? s.vendor : '-', style: const TextStyle(fontSize: 12))),
                DataCell(Text(s.partCode, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                DataCell(Text(s.qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataCell(
                  s.isMapped
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 14),
                            const SizedBox(width: 4),
                            Text(
                              s.inventoryMaterialSku ?? 'Mapped',
                              style: TextStyle(fontSize: 11, color: Colors.green[800], fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 14),
                            const SizedBox(width: 4),
                            Text('Unmapped', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                          ],
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilesTab(ProductBomModel bom, ThemeData theme, dynamic tokens) {
    final filesAsync = ref.watch(productBomFilesStreamProvider(widget.product.id));

    return filesAsync.when(
      loading: () => const LoadingWidget(message: 'Loading exported BOM files...'),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (files) {
        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                const Text('No Exported BOM Files Yet', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Export this BOM to Excel or CSV above to register and download historical files.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: files.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final f = files[index];
            final isXls = f.fileType == 'EXCEL';

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    isXls ? Icons.table_chart_rounded : Icons.text_snippet_rounded,
                    color: isXls ? Colors.green[700] : Colors.blue[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          'Size: ${f.formattedFileSize} | Version: V${f.version} | Exported by ${f.generatedByName} on ${f.generatedAt.toString().split('.').first}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    tooltip: 'Download Again',
                    onPressed: () => _exportBom(bom, isXls),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    tooltip: 'Delete File Record',
                    onPressed: () async {
                      final authState = ref.read(authStateProvider);
                      final orgId = authState.user?.organizationId ?? '';
                      if (orgId.isNotEmpty) {
                        await ref.read(bomRepositoryProvider).deleteBomFile(
                              orgId: orgId,
                              productId: widget.product.id,
                              fileId: f.id,
                            );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
