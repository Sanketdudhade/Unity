import 'package:file_picker/file_picker.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/bom/presentation/providers/bom_providers.dart';
import 'package:unity/features/production/data/models/jobwork_po_model.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/data/services/jobwork_po_excel_service.dart';
import 'package:unity/features/production/data/services/jobwork_po_pdf_service.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/products/presentation/providers/product_providers.dart';

/// Modal dialog for creating, managing, and exporting Jobwork Purchase Orders
/// for Step 4 (M&G: Milling & Grinding) and Step 9 (VMC: Vertical Machining Centre).
class JobworkPoDialog extends ConsumerStatefulWidget {
  final ProductionOrder order;
  final OrderProcessModel process;

  const JobworkPoDialog({
    super.key,
    required this.order,
    required this.process,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductionOrder order,
    required OrderProcessModel process,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => JobworkPoDialog(order: order, process: process),
    );
  }

  @override
  ConsumerState<JobworkPoDialog> createState() => _JobworkPoDialogState();
}

class _JobworkPoDialogState extends ConsumerState<JobworkPoDialog> {
  bool _isCreating = false;
  bool _isSaving = false;
  JobworkPoModel? _editingPo;

  bool get isVmc =>
      widget.process.name.toUpperCase().contains('VMC') || widget.process.sequence == 9;

  // Header controllers
  final _poNumberCtrl = TextEditingController();
  final _suppliersRefCtrl = TextEditingController();
  final _otherRefCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  final _deliveryNoteCtrl = TextEditingController();
  final _dispatchedThroughCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _cityPortLoadingCtrl = TextEditingController();
  final _cityPortDischargeCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Vendor controllers
  final _vendorNameCtrl = TextEditingController();
  final _vendorAddressCtrl = TextEditingController();
  final _vendorGstinCtrl = TextEditingController();

  // Items in active PO
  final List<JobworkPoItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    _resetDefaults();
  }

  void _resetDefaults() {
    final year = DateTime.now().year;
    final nextYear = (year + 1) % 100;

    if (isVmc) {
      _poNumberCtrl.text = '011/$year-$nextYear';
      _suppliersRefCtrl.text = '';
      _otherRefCtrl.text = '';
      _paymentTermsCtrl.text = 'PAYMENT = 90 DAYS';
      _deliveryNoteCtrl.text = '';
      _dispatchedThroughCtrl.text = '';
      _destinationCtrl.text = 'Pune';
      _cityPortLoadingCtrl.text = '';
      _cityPortDischargeCtrl.text = '';
      _vendorNameCtrl.text = 'S.S Engineering';
      _vendorAddressCtrl.text =
          'Gat No.50, Dehu-Alandi Road, Talwade, Pune Maharashtra 411062, India.';
      _vendorGstinCtrl.text = '27AJKPI1882P1ZJ';
    } else {
      _poNumberCtrl.text = '345/$year-$nextYear';
      _suppliersRefCtrl.text = 'UT-3077';
      _otherRefCtrl.text = '';
      _paymentTermsCtrl.text = 'PAYMENT = 90 DAYS';
      _deliveryNoteCtrl.text = '';
      _dispatchedThroughCtrl.text = '';
      _destinationCtrl.text = 'Waluj MIDC, Aurangabad';
      _cityPortLoadingCtrl.text = '';
      _cityPortDischargeCtrl.text = '';
      _vendorNameCtrl.text = 'SANKET ENGINEERING';
      _vendorAddressCtrl.text = 'Plot No B-15/2/41, Waluj MIDC, Aurangabad';
      _vendorGstinCtrl.text = '27BAFPK2942H1ZQ';
    }
  }

  @override
  void dispose() {
    _poNumberCtrl.dispose();
    _suppliersRefCtrl.dispose();
    _otherRefCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _deliveryNoteCtrl.dispose();
    _dispatchedThroughCtrl.dispose();
    _destinationCtrl.dispose();
    _cityPortLoadingCtrl.dispose();
    _cityPortDischargeCtrl.dispose();
    _vendorNameCtrl.dispose();
    _vendorAddressCtrl.dispose();
    _vendorGstinCtrl.dispose();
    super.dispose();
  }

  void _startCreateNewPo([JobworkPoModel? existing]) {
    setState(() {
      _isCreating = true;
      _editingPo = existing;
      if (existing != null) {
        _poNumberCtrl.text = existing.poNumber;
        _suppliersRefCtrl.text = existing.suppliersRef;
        _otherRefCtrl.text = existing.otherReference;
        _paymentTermsCtrl.text = existing.paymentTerms;
        _deliveryNoteCtrl.text = existing.deliveryNote;
        _dispatchedThroughCtrl.text = existing.dispatchedThrough;
        _destinationCtrl.text = existing.destination;
        _cityPortLoadingCtrl.text = existing.cityPortLoading;
        _cityPortDischargeCtrl.text = existing.cityPortDischarge;
        _vendorNameCtrl.text = existing.vendorName;
        _vendorAddressCtrl.text = existing.vendorAddress;
        _vendorGstinCtrl.text = existing.vendorGstin;
        _selectedDate = existing.date;
        _items.clear();
        _items.addAll(existing.items);
      } else {
        _resetDefaults();
        _items.clear();
      }
    });
  }

  void _recalcItems() {
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      final tot = it.rate * it.nos;
      _items[i] = it.copyWith(srNo: i + 1, total: tot);
    }
  }

  double get _subTotal => _items.fold(0.0, (sum, it) => sum + it.total);
  int get _totalNos => _items.fold(0, (sum, it) => sum + it.nos);
  double get _cgst => _subTotal * 0.09;
  double get _sgst => _subTotal * 0.09;
  double get _grandTotal => _subTotal + _cgst + _sgst;

  Future<void> _showAddBomComponentsPicker(ProductModel product) async {
    final boms = ref.read(productBomsStreamProvider(product.id)).value ?? [];
    if (boms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No BOM imported for this product yet. Import BOM first.')),
      );
      return;
    }

    final activeBom = boms.firstWhere((b) => b.isActive, orElse: () => boms.first);
    final components = activeBom.mainComponents;

    if (components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active BOM has no component items.')),
      );
      return;
    }

    final Set<String> selectedIds = {};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPickerState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.playlist_add_check_rounded, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Text('Select BOM Components (${components.length})', style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 420,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVmc
                            ? 'Select components for VMC Purchase Order:'
                            : 'Select components to add to M/G Jobwork PO:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      TextButton(
                        onPressed: () {
                          setPickerState(() {
                            if (selectedIds.length == components.length) {
                              selectedIds.clear();
                            } else {
                              selectedIds.addAll(components.map((c) => c.id));
                            }
                          });
                        },
                        child: Text(selectedIds.length == components.length ? 'Deselect All' : 'Select All'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: components.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final comp = components[idx];
                        final isSelected = selectedIds.contains(comp.id);
                        final thk = comp.rowHeight.isNotEmpty ? comp.rowHeight : comp.finishHeight;
                        final w = comp.rowWidth.isNotEmpty ? comp.rowWidth : comp.finishWidth;
                        final l = comp.rowLength.isNotEmpty ? comp.rowLength : comp.finishLength;

                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          title: Text(
                            comp.nameOfPart,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Dims: ${thk.isEmpty ? "-" : thk} × ${w.isEmpty ? "-" : w} × ${l.isEmpty ? "-" : l} mm • Grade: ${comp.material.isEmpty ? "MS" : comp.material} • Qty: ${comp.qty}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onChanged: (val) {
                            setPickerState(() {
                              if (val == true) {
                                selectedIds.add(comp.id);
                              } else {
                                selectedIds.remove(comp.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Add Selected (${selectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && selectedIds.isNotEmpty) {
      setState(() {
        for (final comp in components.where((c) => selectedIds.contains(c.id))) {
          if (isVmc) {
            const defaultRate = 700.0;
            final total = defaultRate * comp.qty;
            _items.add(JobworkPoItemModel(
              srNo: _items.length + 1,
              bomComponentId: comp.id,
              description: comp.nameOfPart,
              hsnCode: '998898',
              nos: comp.qty,
              per: 'NOS',
              rate: defaultRate,
              total: total,
            ));
          } else {
            final thk = comp.rowHeight.isNotEmpty ? comp.rowHeight : comp.finishHeight;
            final w = comp.rowWidth.isNotEmpty ? comp.rowWidth : comp.finishWidth;
            final l = comp.rowLength.isNotEmpty ? comp.rowLength : comp.finishLength;
            final grade = comp.material.isNotEmpty ? comp.material : 'MS';
            final defaultRate = grade.toUpperCase().contains('D2') ? 180.0 : 170.0;
            final total = defaultRate * comp.qty;

            _items.add(JobworkPoItemModel(
              srNo: _items.length + 1,
              bomComponentId: comp.id,
              description: comp.nameOfPart,
              thk: thk,
              width: w,
              length: l,
              grade: grade,
              nos: comp.qty,
              milling: 20.0,
              grinding: 20.0,
              rate: defaultRate,
              total: total,
            ));
          }
        }
        _recalcItems();
      });
    }
  }

  void _addCustomItem() {
    setState(() {
      if (isVmc) {
        _items.add(JobworkPoItemModel(
          srNo: _items.length + 1,
          description: 'New Component',
          hsnCode: '998898',
          nos: 1,
          per: 'NOS',
          rate: 700.0,
          total: 700.0,
        ));
      } else {
        _items.add(JobworkPoItemModel(
          srNo: _items.length + 1,
          description: 'New Component',
          thk: '25',
          width: '50',
          length: '100',
          grade: 'MS',
          nos: 1,
          milling: 20.0,
          grinding: 20.0,
          rate: 170.0,
          total: 170.0,
        ));
      }
      _recalcItems();
    });
  }

  Future<void> _handleSavePo(String orgId) async {
    final poNum = _poNumberCtrl.text.trim();
    if (poNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter PO Number.')));
      return;
    }
    if (_vendorNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Vendor Name.')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one component to PO.')));
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      _recalcItems();
      final po = JobworkPoModel(
        id: _editingPo?.id ?? 'po_${DateTime.now().millisecondsSinceEpoch}',
        poNumber: poNum,
        orderId: widget.order.id,
        orderNumber: widget.order.orderNumber,
        productName: widget.order.productName,
        processId: widget.process.id,
        poType: isVmc ? 'VMC' : 'M_G',
        date: _selectedDate,
        deliveryNote: _deliveryNoteCtrl.text.trim(),
        suppliersRef: _suppliersRefCtrl.text.trim(),
        otherReference: _otherRefCtrl.text.trim(),
        paymentTerms: _paymentTermsCtrl.text.trim(),
        dispatchedThrough: _dispatchedThroughCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        cityPortLoading: _cityPortLoadingCtrl.text.trim(),
        cityPortDischarge: _cityPortDischargeCtrl.text.trim(),
        vendorName: _vendorNameCtrl.text.trim(),
        vendorAddress: _vendorAddressCtrl.text.trim(),
        vendorGstin: _vendorGstinCtrl.text.trim(),
        items: List.from(_items),
        subTotal: _subTotal,
        taxRate: 18.0,
        cgstAmount: _cgst,
        sgstAmount: _sgst,
        grandTotal: _grandTotal,
        termsAndConditions: isVmc
            ? const [
                'PAYMENT = 90 DAYS',
                'DELIVERY PERIOD AS PER DISCUSS',
                'TAXES - AS A APPLICABLE  18% (C GST & S GST )',
              ]
            : const [
                'PAYMENT = 90 DAYS',
                'DELIVERY PERIOD AS PER DISCUSS',
                'TAXES - AS APPLICABLE 18% (C GST & S GST)',
              ],
        createdAt: _editingPo?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(productionRepositoryProvider).saveJobworkPo(orgId, po);
      ref.invalidate(jobworkPosStreamProvider(widget.order.id));

      setState(() {
        _isSaving = false;
        _isCreating = false;
        _editingPo = null;
      });

      messenger.showSnackBar(
        SnackBar(content: Text('${isVmc ? "VMC" : "M/G Jobwork"} PO "$poNum" saved successfully!')),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save PO: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleExportExcel(JobworkPoModel po) async {
    try {
      final bytes = JobworkPoExcelService.generateXlsx(po);
      final cleanNum = po.poNumber.replaceAll('/', '_');
      final prefix = po.isVmc ? 'VMC_PO' : 'Jobwork_PO';
      final fileName = '${prefix}_$cleanNum.xlsx';

      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save ${po.isVmc ? "VMC" : "Jobwork"} PO Excel (.xlsx)',
        fileName: fileName,
        bytes: bytes,
      );

      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $fileName successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? 'org_unity_001';
    final isAdmin = user?.role.isAdmin ?? false;

    final products = ref.watch(productsStreamProvider).value ?? [];
    final target = widget.order.productName.trim().toLowerCase();
    final matchingProduct = products.firstWhere(
      (p) => p.name.trim().toLowerCase() == target || p.partCode.trim().toLowerCase() == target,
      orElse: () => ProductModel(
        id: widget.order.productName.trim().replaceAll(RegExp(r'\s+'), '_'),
        partCode: widget.order.productName.trim(),
        name: widget.order.productName.trim(),
        unit: widget.order.unit,
      ),
    );

    final posAsync = ref.watch(jobworkPosStreamProvider(widget.order.id));
    final allPos = posAsync.value ?? [];
    // Filter to show POs matching this stage / type
    final pos = allPos
        .where((p) => p.processId == widget.process.id || (isVmc ? p.isVmc : !p.isVmc))
        .toList();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = screenWidth < 700;

    final badgeColor = isVmc ? const Color(0xFF0F766E) : const Color(0xFFEA580C);
    final titleText = isVmc
        ? 'VMC Purchase Order (Vertical Machining Centre)'
        : 'M/G Jobwork Purchase Order (Milling & Grinding)';

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: isMobile ? 16 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: min(850.0, screenHeight - 32),
        ),
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Step ${widget.process.sequence}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.order.orderNumber} • ${widget.order.productName} • Jobwork Supplier Contract',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!_isCreating && isAdmin)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(isVmc ? 'Create VMC PO' : 'Create New PO'),
                      onPressed: () => _startCreateNewPo(),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body: List vs Create Form
            Expanded(
              child: _isCreating
                  ? _buildCreatePoForm(context, orgId, matchingProduct, isDark)
                  : _buildPoListView(context, orgId, pos, isDark, isAdmin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoListView(
    BuildContext context,
    String orgId,
    List<JobworkPoModel> pos,
    bool isDark,
    bool isAdmin,
  ) {
    final theme = Theme.of(context);

    if (pos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 54, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                isVmc
                    ? 'No VMC Purchase Orders Created Yet'
                    : 'No M/G Jobwork Purchase Orders Created Yet',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                isVmc
                    ? 'Generate a Purchase Order for VMC by selecting components from product BOM.'
                    : 'Generate a jobwork PO for Milling & Grinding by selecting components from product BOM.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (isAdmin)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(isVmc ? 'Create VMC PO Now' : 'Create M/G Jobwork PO Now'),
                  onPressed: () => _startCreateNewPo(),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: pos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final po = pos[i];
        final dateFormat = DateFormat('yyyy-MM-dd');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.request_quote_rounded, color: Color(0xFF0F766E), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('PO No: ${po.poNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(po.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        if (po.isVmc) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('VMC', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vendor: ${po.vendorName} • Dated: ${dateFormat.format(po.date)} • Terms: ${po.paymentTerms}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      '${po.items.length} Component Items • Total NOS: ${po.totalNos} • Amount: Rs. ${po.subTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print / PDF'),
                onPressed: () => JobworkPoPdfService.printPo(po),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.table_chart_rounded, size: 16),
                label: const Text('Excel'),
                onPressed: () => _handleExportExcel(po),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete PO',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Purchase Order?'),
                        content: Text('Are you sure you want to delete PO ${po.poNumber}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(productionRepositoryProvider).deleteJobworkPo(orgId, po.id);
                      ref.invalidate(jobworkPosStreamProvider(widget.order.id));
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreatePoForm(
    BuildContext context,
    String orgId,
    ProductModel product,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Controls (Back button & Save)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to PO List'),
                onPressed: () => setState(() => _isCreating = false),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: _isSaving ? null : () => _handleSavePo(orgId),
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_isSaving ? 'Saving...' : (isVmc ? 'Save & Issue VMC PO' : 'Save & Issue M/G Jobwork PO')),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Company & PO Info Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Buyer details
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('UNITY TECHNOLOGIES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('E-70/14, MIDC WALUJ, AURANGABAD 431136.', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                          Text('E-mail: unitytech17@gmail.com', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                          Text('GSTIN/UIN: 27AXEPD7534P1Z1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // PO Metadata Fields
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _poNumberCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'PO Number *',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) setState(() => _selectedDate = picked);
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(labelText: 'Dated', isDense: true, border: OutlineInputBorder()),
                                    child: Text(dateFormat.format(_selectedDate), style: const TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _suppliersRefCtrl,
                                  decoration: InputDecoration(
                                    labelText: isVmc ? "Supplier's Ref." : "Supplier's Ref.",
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _paymentTermsCtrl,
                                  decoration: const InputDecoration(labelText: 'Mode/Terms of Payment', isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          if (isVmc) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _otherRefCtrl,
                                    decoration: const InputDecoration(labelText: 'Other Reference(s)', isDense: true, border: OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _destinationCtrl,
                                    decoration: const InputDecoration(labelText: 'Destination', isDense: true, border: OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vendor ("To,") Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business_rounded, size: 18, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Text(
                      isVmc ? 'Vendor / Jobwork Party (To, S.S Engineering)' : 'Vendor / Jobwork Party ("To,")',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _vendorNameCtrl,
                        decoration: const InputDecoration(labelText: 'Party / Vendor Name *', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _vendorGstinCtrl,
                        decoration: const InputDecoration(labelText: 'Vendor GSTIN', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _vendorAddressCtrl,
                        decoration: const InputDecoration(labelText: 'Address & Location', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Line Items Section Header & Add Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_rows_rounded, size: 20, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text('Component Items (${_items.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: const Text('Add Component from BOM'),
                    onPressed: () => _showAddBomComponentsPicker(product),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Custom Item'),
                    onPressed: _addCustomItem,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Line Items Table
          if (_items.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 10),
                  const Text('No Components Added Yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Click "Add Component from BOM" to populate parts from the engineering BOM.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: isVmc ? _buildVmcDataTable(isDark) : _buildMgDataTable(isDark),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Sub Total and Tax Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Text('TOTAL NOS: $_totalNos NOS', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(width: 14),
                    const Text('E. & O.E', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TOTAL AMOUNT: Rs. ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F766E))),
                    const SizedBox(height: 2),
                    Text('Taxes: 18% CGST & SGST applicable as per terms (Rs. ${(_cgst + _sgst).toStringAsFixed(2)})', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    Text(
                      'GRAND TOTAL (incl. Tax): Rs. ${_grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bottom Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _isCreating = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _isSaving ? null : () => _handleSavePo(orgId),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_isSaving ? 'Saving...' : (isVmc ? 'Save & Issue VMC PO' : 'Save & Issue M/G Jobwork PO')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the table for VMC Purchase Orders:
  /// SR NO | Description of Goods | HSN CODE | Quantity NOS | Rate | per | Amount | Actions
  Widget _buildVmcDataTable(bool isDark) {
    return DataTable(
      columnSpacing: 14,
      headingRowHeight: 40,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      columns: const [
        DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Description of Goods (Part Name)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('HSN CODE', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Quantity (NOS)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('per', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('')),
      ],
      rows: _items.asMap().entries.map((entry) {
        final idx = entry.key;
        final it = entry.value;

        return DataRow(
          cells: [
            DataCell(Text('${it.srNo}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(
              SizedBox(
                width: 260,
                child: TextFormField(
                  initialValue: it.description,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  onChanged: (val) {
                    _items[idx] = it.copyWith(description: val);
                  },
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: it.hsnCode.isNotEmpty ? it.hsnCode : '998898',
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _items[idx] = it.copyWith(hsnCode: val),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: it.nos.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    final n = int.tryParse(val) ?? 1;
                    setState(() {
                      _items[idx] = it.copyWith(nos: n, total: it.rate * n);
                    });
                  },
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: it.rate > 0 ? it.rate.toStringAsFixed(0) : '0',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    final r = double.tryParse(val) ?? 0.0;
                    setState(() {
                      _items[idx] = it.copyWith(rate: r, total: r * it.nos);
                    });
                  },
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 50,
                child: TextFormField(
                  initialValue: it.per.isNotEmpty ? it.per : 'NOS',
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _items[idx] = it.copyWith(per: val),
                ),
              ),
            ),
            DataCell(
              Text(
                it.total.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
              ),
            ),
            DataCell(
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _items.removeAt(idx);
                    _recalcItems();
                  });
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Builds the table for M/G Purchase Orders:
  /// SR NO | DESCRIPTION | THK | WIDTH | LENGTH | GRADE | NOS | MILLING | GRINDING | RATE | TOTAL
  Widget _buildMgDataTable(bool isDark) {
    return DataTable(
      columnSpacing: 12,
      headingRowHeight: 40,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 56,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      columns: const [
        DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('DESCRIPTION (Part Name)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('THK (mm)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('WIDTH', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('LENGTH', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('GRADE', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('NOS (Qty)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('MILLING', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('GRINDING', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('RATE (Rs)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('TOTAL (Rs)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('')),
      ],
      rows: _items.asMap().entries.map((entry) {
        final idx = entry.key;
        final it = entry.value;

        return DataRow(
          cells: [
            DataCell(Text('${it.srNo}', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(
              SizedBox(
                width: 140,
                child: TextFormField(
                  initialValue: it.description,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  onChanged: (val) {
                    _items[idx] = it.copyWith(description: val);
                  },
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 50,
                child: TextFormField(
                  initialValue: it.thk,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _items[idx] = it.copyWith(thk: val),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 50,
                child: TextFormField(
                  initialValue: it.width,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _items[idx] = it.copyWith(width: val),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 50,
                child: TextFormField(
                  initialValue: it.length,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _items[idx] = it.copyWith(length: val),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: it.grade,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => _items[idx] = it.copyWith(grade: val),
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 45,
                child: TextFormField(
                  initialValue: it.nos.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    final n = int.tryParse(val) ?? 1;
                    setState(() {
                      _items[idx] = it.copyWith(nos: n, total: it.rate * n);
                    });
                  },
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 55,
                child: TextFormField(
                  initialValue: it.milling > 0 ? it.milling.toStringAsFixed(1) : '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    final m = double.tryParse(val) ?? 0.0;
                    _items[idx] = it.copyWith(milling: m);
                  },
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 55,
                child: TextFormField(
                  initialValue: it.grinding > 0 ? it.grinding.toStringAsFixed(1) : '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) {
                    final g = double.tryParse(val) ?? 0.0;
                    _items[idx] = it.copyWith(grinding: g);
                  },
                ),
              ),
            ),
            DataCell(
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: it.rate > 0 ? it.rate.toStringAsFixed(1) : '',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    final r = double.tryParse(val) ?? 0.0;
                    setState(() {
                      _items[idx] = it.copyWith(rate: r, total: r * it.nos);
                    });
                  },
                ),
              ),
            ),
            DataCell(
              Text(
                it.total.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            DataCell(
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _items.removeAt(idx);
                    _recalcItems();
                  });
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
