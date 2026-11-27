import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';
import 'package:unity/features/bom/data/services/bom_excel_parser.dart';
import 'package:unity/features/bom/presentation/providers/bom_providers.dart';
import 'package:unity/features/bom/presentation/widgets/bom_mapping_dialog.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/products/data/models/product_model.dart';

/// Modal dialog for uploading, validating, previewing, and saving a Product BOM.
class BomImportDialog extends ConsumerStatefulWidget {
  final ProductModel product;

  const BomImportDialog({super.key, required this.product});

  @override
  ConsumerState<BomImportDialog> createState() => _BomImportDialogState();
}

class _BomImportDialogState extends ConsumerState<BomImportDialog> {
  bool _isLoading = false;
  String? _selectedFileName;
  ParsedBomResult? _parsedResult;
  ProductBomModel? _bomDraft;
  String? _errorMessage;

  Future<void> _pickAndParseFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (file == null) {
        setState(() => _isLoading = false);
        return;
      }

      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        if (file.path != null && file.path!.isNotEmpty) {
          bytes = await File(file.path!).readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _errorMessage = 'Could not read file data. Please try another file.';
          _isLoading = false;
        });
        return;
      }

      final authState = ref.read(authStateProvider);
      final authUser = authState.user;

      final parsed = BomExcelParser.parseBytes(
        bytes: bytes,
        fileName: file.name,
        productId: widget.product.id,
        productCode: widget.product.partCode,
        productName: widget.product.name,
        uploadedByUid: authUser?.uid ?? '',
        uploadedByName: authUser?.fullName ?? 'Admin',
      );

      if (!parsed.isValid) {
        setState(() {
          _selectedFileName = file.name;
          _parsedResult = parsed;
          _bomDraft = parsed.bom;
          _errorMessage = parsed.errors.isNotEmpty
              ? parsed.errors.join('\n')
              : 'No valid BOM component records found.';
          _isLoading = false;
        });
        return;
      }

      // Auto-map inventory against current inventory catalog
      final materials = ref.read(materialsStreamProvider).value ?? [];
      final repo = ref.read(bomRepositoryProvider);
      final autoMappedBom = repo.autoMapInventory(
        bom: parsed.bom,
        inventoryMaterials: materials,
      );

      setState(() {
        _selectedFileName = file.name;
        _parsedResult = parsed;
        _bomDraft = autoMappedBom;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse file: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBom() async {
    if (_bomDraft == null) return;

    final authState = ref.read(authStateProvider);
    final orgId = authState.user?.organizationId ?? '';
    if (orgId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(bomRepositoryProvider);
      await repo.saveBom(
        orgId: orgId,
        productId: widget.product.id,
        bom: _bomDraft!,
        makeActive: true,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('BOM for ${widget.product.partCode} imported and activated successfully!'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save BOM: $e';
        _isLoading = false;
      });
    }
  }

  void _openMappingEditor() {
    if (_bomDraft == null) return;

    showDialog(
      context: context,
      builder: (_) => BomMappingDialog(
        bom: _bomDraft!,
        onBomUpdated: (updated) {
          setState(() => _bomDraft = updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.adminTokens;

    final draft = _bomDraft;
    final totalComponents = draft?.mainComponents.length ?? 0;
    final totalStandards = draft?.standardItems.length ?? 0;
    final mappedCount = draft?.mappedItemsCount ?? 0;
    final totalItems = draft?.totalItemsCount ?? 0;

    final media = MediaQuery.sizeOf(context);
    final isCompact = media.width < 600;
    final dialogWidth = min(750.0, media.width - 32);
    final dialogHeight = min(700.0, media.height - 32);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogHeight),
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.file_upload_outlined, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Product BOM — ${widget.product.partCode}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Upload Excel (.xlsx) or CSV file with Tool / Die Bill of Materials',
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
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.danger.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: tokens.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12, color: tokens.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_selectedFileName == null) ...[
              // Upload placeholder
              InkWell(
                onTap: _isLoading ? null : _pickAndParseFile,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Click to browse Excel / CSV BOM file',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports .xlsx (with headers, merged rows, multi-section) and .csv',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Preview parsed summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedFileName!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Change File'),
                          onPressed: _isLoading ? null : _pickAndParseFile,
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _buildMetric('Main Components', '$totalComponents items', theme),
                        _buildMetric('Standard Parts', '$totalStandards items', theme),
                        _buildMetric('Inventory Mapped', '$mappedCount / $totalItems', theme),
                      ],
                    ),
                    if (draft != null && draft.toolNo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Tool No: ${draft.toolNo} | Customer: ${draft.customer} | Sheet: ${draft.materialSheet}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.hub_outlined, size: 16),
                    label: const Text('Review & Edit Material Mapping'),
                    onPressed: _openMappingEditor,
                  ),
                  if (_parsedResult?.warnings.isNotEmpty ?? false)
                    Text(
                      '${_parsedResult!.warnings.length} warnings detected',
                      style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(_isLoading ? 'Processing...' : 'Confirm & Save BOM'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_bomDraft == null || _isLoading) ? null : _saveBom,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildMetric(String title, String val, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
