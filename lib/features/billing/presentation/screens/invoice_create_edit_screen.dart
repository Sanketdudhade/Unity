import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/products/presentation/providers/product_providers.dart';
import '../../data/models/company_billing_config_model.dart';
import '../../data/models/customer_billing_model.dart';
import '../../data/models/invoice_item_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/services/indian_currency_formatter.dart';
import '../../data/services/invoice_number_service.dart';
import '../providers/billing_providers.dart';
import '../widgets/company_billing_config_dialog.dart';

class InvoiceCreateEditScreen extends ConsumerStatefulWidget {
  final String? invoiceId;

  const InvoiceCreateEditScreen({super.key, this.invoiceId});

  @override
  ConsumerState<InvoiceCreateEditScreen> createState() =>
      _InvoiceCreateEditScreenState();
}

class _InvoiceCreateEditScreenState extends ConsumerState<InvoiceCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // State
  bool _isLoading = false;
  bool _isSaving = false;
  String? _prospectiveInvoiceNumber;

  // Invoice Details
  DateTime _invoiceDate = DateTime.now();
  DateTime? _dueDate;
  final _deliveryNoteCtrl = TextEditingController();
  final _modeOfPaymentCtrl = TextEditingController(text: 'Immediate');
  final _buyerOrderNumberCtrl = TextEditingController();
  DateTime? _buyerOrderDate;
  final _dispatchDocCtrl = TextEditingController();
  final _dispatchedThroughCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _motorVehicleNumberCtrl = TextEditingController();
  final _termsOfDeliveryCtrl = TextEditingController();

  // Customer Details
  CustomerBillingModel? _selectedCustomer;
  final _customerNameCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _customerGstinCtrl = TextEditingController();
  final _customerStateCtrl = TextEditingController(text: 'Maharashtra');
  final _customerStateCodeCtrl = TextEditingController(text: '27');
  final _customerPlaceOfSupplyCtrl = TextEditingController(text: 'Maharashtra');
  final _customerEmailCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  bool _saveCustomerForFuture = true;

  // Line items
  final List<_EditableLineItem> _items = [];

  // Summary adjustments
  final _otherChargesCtrl = TextEditingController(text: '0.00');

  // E-Invoice
  final _irnCtrl = TextEditingController();
  final _ackNoCtrl = TextEditingController();
  final _ackDateCtrl = TextEditingController();

  // Editing existing draft
  InvoiceModel? _existingDraft;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    if (widget.invoiceId != null) {
      final repo = ref.read(billingRepositoryProvider);
      _existingDraft = await repo.getInvoice(widget.invoiceId!);
      if (_existingDraft != null) {
        _populateExisting(_existingDraft!);
      }
    } else {
      // New Invoice: Add 1 default row
      _addNewItem();
      // Fetch prospective invoice number
      final authState = ref.read(authStateProvider);
      final orgId = authState.user?.organizationId ?? 'org_unity_001';
      final numService = InvoiceNumberService(orgId: orgId);
      _prospectiveInvoiceNumber = await numService.peekNextInvoiceNumber(date: _invoiceDate);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _populateExisting(InvoiceModel inv) {
    _invoiceDate = inv.invoiceDate;
    _dueDate = inv.dueDate;
    _deliveryNoteCtrl.text = inv.deliveryNote;
    _modeOfPaymentCtrl.text = inv.modeOfPayment ?? '';
    _buyerOrderNumberCtrl.text = inv.buyerOrderNumber ?? '';
    _buyerOrderDate = inv.buyerOrderDate;
    _dispatchDocCtrl.text = inv.dispatchDocNumber ?? '';
    _dispatchedThroughCtrl.text = inv.dispatchedThrough;
    _destinationCtrl.text = inv.destination;
    _motorVehicleNumberCtrl.text = inv.motorVehicleNumber ?? '';
    _termsOfDeliveryCtrl.text = inv.termsOfDelivery;

    // Customer
    final cust = inv.customerSnapshot;
    _customerNameCtrl.text = cust.customerName;
    _customerAddressCtrl.text = cust.billingAddress;
    _customerGstinCtrl.text = cust.gstin;
    _customerStateCtrl.text = cust.stateName;
    _customerStateCodeCtrl.text = cust.stateCode;
    _customerPlaceOfSupplyCtrl.text = cust.placeOfSupply;
    _customerEmailCtrl.text = cust.email;
    _customerPhoneCtrl.text = cust.phone;

    // Items
    _items.clear();
    for (final item in inv.items) {
      _items.add(_EditableLineItem(
        description: item.description,
        hsnSac: item.hsnSac,
        quantity: item.quantity,
        unit: item.unit,
        rate: item.rate,
        discountPercent: item.discountPercent,
        gstRate: item.gstRate,
        productId: item.productId,
      ));
    }

    _otherChargesCtrl.text = inv.otherCharges.toStringAsFixed(2);
    _irnCtrl.text = inv.irn;
    _ackNoCtrl.text = inv.acknowledgementNumber ?? '';
    _ackDateCtrl.text = inv.acknowledgementDate ?? '';
  }

  void _addNewItem() {
    _items.add(_EditableLineItem(
      description: '',
      hsnSac: '8466',
      quantity: 1,
      unit: 'PCS',
      rate: 0,
      discountPercent: 0,
      gstRate: 18,
    ));
    setState(() {});
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
      });
    }
  }

  void _selectSavedCustomer(CustomerBillingModel? cust) {
    setState(() {
      _selectedCustomer = cust;
      if (cust != null) {
        _customerNameCtrl.text = cust.customerName;
        _customerAddressCtrl.text = cust.billingAddress;
        _customerGstinCtrl.text = cust.gstin;
        _customerStateCtrl.text = cust.stateName;
        _customerStateCodeCtrl.text = cust.stateCode;
        _customerPlaceOfSupplyCtrl.text = cust.placeOfSupply;
        _customerEmailCtrl.text = cust.email ?? '';
        _customerPhoneCtrl.text = cust.phone ?? '';
      }
    });
  }

  // --- Calculations ---
  bool _isIntraState(CompanyBillingConfigModel comp) {
    return _customerStateCodeCtrl.text.trim() == comp.stateCode.trim();
  }

  List<InvoiceItemModel> _buildCalculatedItems(bool isIntraState) {
    return _items.map((e) {
      return InvoiceItemModel.calculate(
        productId: e.productId,
        description: e.descriptionCtrl.text.trim(),
        hsnSac: e.hsnCtrl.text.trim(),
        quantity: double.tryParse(e.qtyCtrl.text.trim()) ?? 1,
        unit: e.unitCtrl.text.trim().toUpperCase(),
        rate: double.tryParse(e.rateCtrl.text.trim()) ?? 0,
        discountPercent: double.tryParse(e.discCtrl.text.trim()) ?? 0,
        gstRate: e.gstRate,
        isIntraState: isIntraState,
      );
    }).toList();
  }

  double _calculateTotalTaxable(List<InvoiceItemModel> items) {
    return items.fold(0.0, (acc, item) => acc + item.taxableAmount);
  }

  double _calculateTotalCgst(List<InvoiceItemModel> items) {
    return items.fold(0.0, (acc, item) => acc + item.cgstAmount);
  }

  double _calculateTotalSgst(List<InvoiceItemModel> items) {
    return items.fold(0.0, (acc, item) => acc + item.sgstAmount);
  }

  double _calculateTotalIgst(List<InvoiceItemModel> items) {
    return items.fold(0.0, (acc, item) => acc + item.igstAmount);
  }

  double _calculateTotalQuantity(List<InvoiceItemModel> items) {
    return items.fold(0.0, (acc, item) => acc + item.quantity);
  }

  Future<void> _submitInvoice({required bool isDraft}) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the validation errors in the form.')),
      );
      return;
    }

    if (_items.isEmpty || _items.every((it) => it.descriptionCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one valid line item.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final compAsync = ref.read(companyBillingConfigProvider);
      final comp = compAsync.value ?? CompanyBillingConfigModel.defaultConfig();
      final isIntra = _isIntraState(comp);

      final calculatedItems = _buildCalculatedItems(isIntra);
      final totalQty = _calculateTotalQuantity(calculatedItems);
      final taxable = _calculateTotalTaxable(calculatedItems);
      final cgst = isIntra ? _calculateTotalCgst(calculatedItems) : 0.0;
      final sgst = isIntra ? _calculateTotalSgst(calculatedItems) : 0.0;
      final igst = !isIntra ? _calculateTotalIgst(calculatedItems) : 0.0;
      final totalTax = cgst + sgst + igst;

      final otherCharges = double.tryParse(_otherChargesCtrl.text.trim()) ?? 0.0;
      final rawTotal = taxable + totalTax + otherCharges;
      final roundedTotal = rawTotal.roundToDouble();
      final roundOff = (roundedTotal - rawTotal);

      final amountInWords = IndianCurrencyFormatter.convertToWords(roundedTotal);
      final taxInWords = IndianCurrencyFormatter.convertToWords(totalTax);

      final custSnapshot = CustomerBillingModel(
        id: _selectedCustomer?.id ?? '',
        customerName: _customerNameCtrl.text.trim(),
        billingAddress: _customerAddressCtrl.text.trim(),
        gstin: _customerGstinCtrl.text.trim().toUpperCase(),
        stateName: _customerStateCtrl.text.trim(),
        stateCode: _customerStateCodeCtrl.text.trim(),
        placeOfSupply: _customerPlaceOfSupplyCtrl.text.trim().isNotEmpty
            ? _customerPlaceOfSupplyCtrl.text.trim()
            : _customerStateCtrl.text.trim(),
        email: _customerEmailCtrl.text.trim(),
        phone: _customerPhoneCtrl.text.trim(),
      );

      // Save customer for reuse if requested
      final repo = ref.read(billingRepositoryProvider);
      if (_saveCustomerForFuture) {
        await repo.saveCustomer(custSnapshot);
      }

      final authState = ref.read(authStateProvider);
      final userId = authState.user?.id ?? 'admin';

      final invoiceRecord = InvoiceModel(
        id: _existingDraft?.id ?? '',
        invoiceNumber: _existingDraft?.invoiceNumber ?? '',
        financialYear: InvoiceNumberService.getFinancialYear(_invoiceDate),
        companySnapshot: comp,
        customerId: _selectedCustomer?.id,
        customerSnapshot: custSnapshot,
        invoiceDate: _invoiceDate,
        dueDate: _dueDate,
        deliveryNote: _deliveryNoteCtrl.text.trim(),
        modeOfPayment: _modeOfPaymentCtrl.text.trim().isNotEmpty
            ? _modeOfPaymentCtrl.text.trim()
            : null,
        buyerOrderNumber: _buyerOrderNumberCtrl.text.trim().isNotEmpty
            ? _buyerOrderNumberCtrl.text.trim()
            : null,
        buyersOrderDate: _buyerOrderDate,
        dispatchDocNumber: _dispatchDocCtrl.text.trim().isNotEmpty
            ? _dispatchDocCtrl.text.trim()
            : null,
        dispatchedThrough: _dispatchedThroughCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        motorVehicleNumber: _motorVehicleNumberCtrl.text.trim().isNotEmpty
            ? _motorVehicleNumberCtrl.text.trim()
            : null,
        termsOfDelivery: _termsOfDeliveryCtrl.text.trim(),
        items: calculatedItems,
        totalQuantity: totalQty,
        taxableAmount: taxable,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
        totalTax: totalTax,
        otherCharges: otherCharges,
        roundOff: roundOff,
        grandTotal: roundedTotal,
        amountInWords: amountInWords,
        taxAmountInWords: taxInWords,
        paymentStatus: InvoicePaymentStatus.pending,
        totalPaid: _existingDraft?.totalPaid ?? 0.0,
        outstandingAmount: roundedTotal - (_existingDraft?.totalPaid ?? 0.0),
        invoiceStatus: isDraft ? InvoiceRecordStatus.draft : InvoiceRecordStatus.issued,
        irn: _irnCtrl.text.trim(),
        acknowledgementNumber: _ackNoCtrl.text.trim().isNotEmpty
            ? _ackNoCtrl.text.trim()
            : null,
        acknowledgementDate: _ackDateCtrl.text.trim().isNotEmpty
            ? _ackDateCtrl.text.trim()
            : null,
      );

      String invoiceId;
      if (_existingDraft != null && _existingDraft!.invoiceStatus == InvoiceRecordStatus.draft) {
        invoiceId = _existingDraft!.id;
        await repo.updateDraftInvoice(invoiceRecord, userId: userId);
      } else {
        invoiceId = await repo.createInvoice(invoiceRecord, userId: userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDraft
                  ? 'Invoice saved as Draft.'
                  : 'Invoice issued and generated successfully!',
            ),
          ),
        );
        context.goNamed(RouteNames.adminBillingDetails, pathParameters: {'id': invoiceId});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final compConfig = ref.watch(companyBillingConfigProvider).value ??
        CompanyBillingConfigModel.defaultConfig();
    final savedCustomers = ref.watch(billingCustomersStreamProvider).value ?? [];
    final activeProducts = ref.watch(activeProductsProvider);

    final isIntraState = _isIntraState(compConfig);
    final calculatedItems = _buildCalculatedItems(isIntraState);
    final totalTaxable = _calculateTotalTaxable(calculatedItems);
    final totalCgst = isIntraState ? _calculateTotalCgst(calculatedItems) : 0.0;
    final totalSgst = isIntraState ? _calculateTotalSgst(calculatedItems) : 0.0;
    final totalIgst = !isIntraState ? _calculateTotalIgst(calculatedItems) : 0.0;
    final totalTax = totalCgst + totalSgst + totalIgst;
    final otherCharges = double.tryParse(_otherChargesCtrl.text.trim()) ?? 0.0;
    final rawTotal = totalTaxable + totalTax + otherCharges;
    final roundedTotal = rawTotal.roundToDouble();
    final roundOff = roundedTotal - rawTotal;
    final amountWords = IndianCurrencyFormatter.convertToWords(roundedTotal);
    final taxWords = IndianCurrencyFormatter.convertToWords(totalTax);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.invoiceId != null ? 'Edit Draft Invoice' : 'Create Tax Invoice',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _submitInvoice(isDraft: true),
            icon: const Icon(Icons.drafts_outlined, size: 18),
            label: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isSaving ? null : () => _submitInvoice(isDraft: false),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Issue Invoice'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Company Profile Bar
                  _buildCompanyCard(compConfig),
                  const SizedBox(height: 16),

                  // 2. Invoice Meta Info
                  _buildInvoiceDetailsCard(),
                  const SizedBox(height: 16),

                  // 3. Customer / Buyer Details
                  _buildCustomerCard(savedCustomers),
                  const SizedBox(height: 16),

                  // 4. Line Items Table
                  _buildLineItemsCard(activeProducts),
                  const SizedBox(height: 16),

                  // 5. Tax Summary & Grand Total
                  _buildTaxSummaryCard(
                    isIntraState: isIntraState,
                    taxable: totalTaxable,
                    cgst: totalCgst,
                    sgst: totalSgst,
                    igst: totalIgst,
                    totalTax: totalTax,
                    roundOff: roundOff,
                    grandTotal: roundedTotal,
                    amountInWords: amountWords,
                    taxInWords: taxWords,
                  ),
                  const SizedBox(height: 16),

                  // 6. E-Invoice & Statutory (Optional)
                  _buildEInvoiceCard(),
                  const SizedBox(height: 24),

                  // Bottom Action Bar
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : () => _submitInvoice(isDraft: true),
                        icon: const Icon(Icons.drafts_outlined, size: 18),
                        label: const Text('Save as Draft'),
                      ),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : () => _submitInvoice(isDraft: false),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Issue & Generate Invoice'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Cards ---

  Widget _buildCompanyCard(CompanyBillingConfigModel comp) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.business, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comp.companyName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(comp.registeredAddress, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    children: [
                      Text('GSTIN: ${comp.gstin}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('PAN: ${comp.pan}', style: const TextStyle(fontSize: 12)),
                      Text('State: ${comp.state} (${comp.stateCode})',
                          style: const TextStyle(fontSize: 12)),
                      Text('A/c: ${comp.bankName} (${comp.accountNumber})',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => CompanyBillingConfigDialog.show(context, comp),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit Settings', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDetailsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Invoice Metadata',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _existingDraft != null
                        ? 'Invoice No: ${_existingDraft!.invoiceNumber}'
                        : 'Preview No: ${_prospectiveInvoiceNumber ?? "UT/2026-27/0104"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _invoiceDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Invoice Date *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Icon(Icons.calendar_today, size: 16),
                      ),
                      child: Text(
                        '${_invoiceDate.day.toString().padLeft(2, '0')}/${_invoiceDate.month.toString().padLeft(2, '0')}/${_invoiceDate.year}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? _invoiceDate.add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _dueDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Payment Due Date',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_dueDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() => _dueDate = null),
                              ),
                            const Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                      child: Text(
                        _dueDate != null
                            ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                            : 'Select Due Date (Optional)',
                        style: TextStyle(
                          fontSize: 13,
                          color: _dueDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modeOfPaymentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Terms / Mode of Payment',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyerOrderNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: "Buyer's Order No.",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _deliveryNoteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Note',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _motorVehicleNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motor Vehicle No.',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _destinationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(List<CustomerBillingModel> savedCustomers) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Customer / Buyer Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (savedCustomers.isNotEmpty) ...[
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<CustomerBillingModel>(
                      value: _selectedCustomer,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Saved Customer',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Enter New Customer...'),
                        ),
                        ...savedCustomers.map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.customerName, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: _selectSavedCustomer,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _customerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer / Buyer Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _customerGstinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer GSTIN / UIN *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      // Automatically detect state code from first 2 digits of GSTIN
                      if (val.length >= 2) {
                        final code = val.substring(0, 2);
                        if (int.tryParse(code) != null) {
                          _customerStateCodeCtrl.text = code;
                          setState(() {});
                        }
                      }
                    },
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerAddressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Billing Address *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                if (isNarrow) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _customerStateCtrl,
                              decoration: const InputDecoration(
                                labelText: 'State Name *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _customerStateCodeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'State Code *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _customerPlaceOfSupplyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Place of Supply',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _customerPhoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _customerStateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'State Name *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _customerStateCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'State Code * (e.g. 27)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _customerPlaceOfSupplyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Place of Supply',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _customerPhoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _saveCustomerForFuture,
                  onChanged: (v) => setState(() => _saveCustomerForFuture = v ?? true),
                ),
                const Text(
                  'Save customer details for reuse in future invoices',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsCard(List<dynamic> activeProducts) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Invoice Line Items',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const Divider(height: 24),
            for (int i = 0; i < _items.length; i++) ...[
              _buildItemRow(i, activeProducts),
              if (i < _items.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, List<dynamic> activeProducts) {
    final item = _items[index];
    final qty = double.tryParse(item.qtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(item.rateCtrl.text.trim()) ?? 0;
    final disc = double.tryParse(item.discCtrl.text.trim()) ?? 0;
    final gross = qty * rate;
    final taxable = max(0.0, gross - (gross * disc / 100));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            // Product picker shortcut button
            if (activeProducts.isNotEmpty)
              PopupMenuButton<dynamic>(
                tooltip: 'Select from Product Catalog',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'From Catalog',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => activeProducts.map<PopupMenuEntry<dynamic>>((p) {
                  return PopupMenuItem(
                    value: p,
                    child: Text('${p.name} (${p.partCode})'),
                  );
                }).toList(),
                onSelected: (p) {
                  setState(() {
                    item.productId = p.id;
                    item.descriptionCtrl.text = '${p.name} - ${p.partCode}';
                    item.unitCtrl.text = p.unit.isNotEmpty ? p.unit : 'PCS';
                  });
                },
              ),
            const Spacer(),
            if (_items.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                tooltip: 'Remove item',
                onPressed: () => _removeItem(index),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: item.descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description of Goods *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: item.hsnCtrl,
                decoration: const InputDecoration(
                  labelText: 'HSN/SAC',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: item.qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: item.unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: item.rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Rate (₹)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: item.discCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Disc %',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<double>(
                value: item.gstRate,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'GST Rate',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('0%')),
                  DropdownMenuItem(value: 5.0, child: Text('5%')),
                  DropdownMenuItem(value: 12.0, child: Text('12%')),
                  DropdownMenuItem(value: 18.0, child: Text('18%')),
                  DropdownMenuItem(value: 28.0, child: Text('28%')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => item.gstRate = val);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Taxable Value', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    IndianCurrencyFormatter.format(taxable),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaxSummaryCard({
    required bool isIntraState,
    required double taxable,
    required double cgst,
    required double sgst,
    required double igst,
    required double totalTax,
    required double roundOff,
    required double grandTotal,
    required String amountInWords,
    required String taxInWords,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Tax Calculation & Invoice Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isIntraState
                        ? Colors.green.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isIntraState
                        ? 'INTRA-STATE TRANSACTION (CGST + SGST)'
                        : 'INTER-STATE TRANSACTION (IGST)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isIntraState ? Colors.green[800] : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Words breakdown
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amount in Words:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        amountInWords,
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tax in Words:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        taxInWords,
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right: Numbers Table
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _calcRow('Total Taxable Value', taxable),
                        if (isIntraState) ...[
                          _calcRow('Central Tax (CGST)', cgst),
                          _calcRow('State Tax (SGST)', sgst),
                        ] else ...[
                          _calcRow('Integrated Tax (IGST)', igst),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Other Charges (Freight/Pkg):', style: TextStyle(fontSize: 12)),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: _otherChargesCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  prefixText: '₹ ',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _calcRow('Rounding Adjustment', roundOff),
                        const Divider(),
                        _calcRow('Grand Total', grandTotal, isBold: true, fontSize: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEInvoiceCard() {
    return ExpansionTile(
      title: const Text(
        'Optional Statutory E-Invoice Details',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: const Text(
        'IRN and Acknowledgement details (leave empty if not generating via GST portal)',
        style: TextStyle(fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _irnCtrl,
                decoration: const InputDecoration(
                  labelText: 'Invoice Reference Number (IRN)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _ackNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Acknowledgement No.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _ackDateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Acknowledgement Date',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _calcRow(String label, double val, {bool isBold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            IndianCurrencyFormatter.format(val),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableLineItem {
  String? productId;
  final TextEditingController descriptionCtrl;
  final TextEditingController hsnCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController discCtrl;
  double gstRate;

  _EditableLineItem({
    this.productId,
    required String description,
    required String hsnSac,
    required double quantity,
    required String unit,
    required double rate,
    required double discountPercent,
    required this.gstRate,
  })  : descriptionCtrl = TextEditingController(text: description),
        hsnCtrl = TextEditingController(text: hsnSac),
        qtyCtrl = TextEditingController(text: quantity.toStringAsFixed(0)),
        unitCtrl = TextEditingController(text: unit),
        rateCtrl = TextEditingController(text: rate > 0 ? rate.toStringAsFixed(2) : ''),
        discCtrl = TextEditingController(text: discountPercent > 0 ? discountPercent.toStringAsFixed(1) : '');
}
