import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/invoice_model.dart';
import '../../data/services/indian_currency_formatter.dart';
import '../../data/services/invoice_excel_service.dart';
import '../../data/services/invoice_pdf_service.dart';
import '../providers/billing_providers.dart';
import '../widgets/record_payment_dialog.dart';

class InvoiceDetailsScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends ConsumerState<InvoiceDetailsScreen> {
  final _pdfService = InvoicePdfService();
  bool _isProcessing = false;

  Future<void> _exportExcel(InvoiceModel invoice) async {
    setState(() => _isProcessing = true);
    try {
      final bytes = InvoiceExcelService.generateInvoiceXlsx(invoice);
      final cleanNum = invoice.invoiceNumber.replaceAll('/', '_');
      final fileName = 'Invoice_$cleanNum.xlsx';

      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save Invoice Excel (.xlsx)',
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
          SnackBar(content: Text('Failed to export Excel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showCancelDialog(InvoiceModel invoice) async {
    final reasonCtrl = TextEditingController();
    final authState = ref.read(authStateProvider);
    final userId = authState.user?.id ?? 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel invoice ${invoice.invoiceNumber}? This action preserves the audit record and cannot be undone.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason for Cancellation *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, Keep Active'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      setState(() => _isProcessing = true);
      try {
        final repo = ref.read(billingRepositoryProvider);
        await repo.cancelInvoice(
          invoiceId: invoice.id,
          reason: reasonCtrl.text.trim(),
          userId: userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice marked as cancelled.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel invoice: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final paymentsAsync = ref.watch(invoicePaymentsStreamProvider(widget.invoiceId));
    final authState = ref.watch(authStateProvider);
    final userId = authState.user?.id ?? 'admin';

    return invoicesAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Invoice Details')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (invoices) {
        final invoiceList = invoices.where((inv) => inv.id == widget.invoiceId).toList();
        if (invoiceList.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Invoice Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Invoice record could not be found.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.goNamed(RouteNames.adminBilling),
                    child: const Text('Back to Invoices'),
                  ),
                ],
              ),
            ),
          );
        }

        final invoice = invoiceList.first;
        final isIntraState = invoice.customerSnapshot.stateCode.trim() ==
            invoice.companySnapshot.stateCode.trim();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              invoice.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              Builder(
                builder: (context) {
                  final isCompact = MediaQuery.sizeOf(context).width < 750;

                  if (isCompact) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (invoice.outstandingAmount > 0.01 &&
                            invoice.invoiceStatus != InvoiceRecordStatus.cancelled)
                          IconButton(
                            icon: const Icon(Icons.payment, color: Colors.green),
                            tooltip: 'Record Payment',
                            onPressed: () => RecordPaymentDialog.show(
                              context,
                              invoice: invoice,
                              userId: userId,
                            ),
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Invoice Actions',
                          itemBuilder: (ctx) => [
                            if (invoice.invoiceStatus == InvoiceRecordStatus.draft)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Draft'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'print',
                              child: Row(
                                children: [
                                  Icon(Icons.print, size: 18),
                                  SizedBox(width: 8),
                                  Text('Print'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, size: 18),
                                  SizedBox(width: 8),
                                  Text('Download PDF'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'excel',
                              child: Row(
                                children: [
                                  Icon(Icons.table_chart, size: 18),
                                  SizedBox(width: 8),
                                  Text('Download Excel'),
                                ],
                              ),
                            ),
                            if (invoice.invoiceStatus != InvoiceRecordStatus.cancelled)
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Cancel Invoice', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                          ],
                          onSelected: (val) {
                            switch (val) {
                              case 'edit':
                                context.goNamed(
                                  RouteNames.adminBillingCreate,
                                  queryParameters: {'editId': invoice.id},
                                );
                                break;
                              case 'print':
                                if (!_isProcessing) _pdfService.printInvoice(invoice);
                                break;
                              case 'pdf':
                                if (!_isProcessing) _pdfService.sharePdf(invoice);
                                break;
                              case 'excel':
                                if (!_isProcessing) _exportExcel(invoice);
                                break;
                              case 'cancel':
                                _showCancelDialog(invoice);
                                break;
                            }
                          },
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (invoice.invoiceStatus == InvoiceRecordStatus.draft) ...[
                        OutlinedButton.icon(
                          onPressed: () => context.goNamed(
                            RouteNames.adminBillingCreate,
                            queryParameters: {'editId': invoice.id},
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Draft'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _pdfService.printInvoice(invoice),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _pdfService.sharePdf(invoice),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Download PDF'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _exportExcel(invoice),
                        icon: const Icon(Icons.table_chart, size: 16),
                        label: const Text('Download Excel'),
                      ),
                      const SizedBox(width: 8),
                      if (invoice.invoiceStatus != InvoiceRecordStatus.cancelled) ...[
                        if (invoice.outstandingAmount > 0.01) ...[
                          FilledButton.icon(
                            onPressed: () => RecordPaymentDialog.show(
                              context,
                              invoice: invoice,
                              userId: userId,
                            ),
                            icon: const Icon(Icons.payment, size: 16),
                            label: const Text('Record Payment'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                  SizedBox(width: 8),
                                  Text('Cancel Invoice', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (val) {
                            if (val == 'cancel') _showCancelDialog(invoice);
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cancellation Banner if applicable
                    if (invoice.invoiceStatus == InvoiceRecordStatus.cancelled) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'THIS INVOICE HAS BEEN CANCELLED',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reason: ${invoice.cancellationReason ?? "Cancelled by Administrator"}',
                                    style: TextStyle(color: Colors.red[900], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Top Status Row
                    _buildStatusBanner(invoice),
                    const SizedBox(height: 16),

                    // Rendered Invoice Document View
                    _buildDocumentCard(invoice, isIntraState),
                    const SizedBox(height: 24),

                    // Payment History Section
                    _buildPaymentsSection(invoice, paymentsAsync, userId),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(InvoiceModel invoice) {
    final isOverdue = invoice.paymentStatus != InvoicePaymentStatus.paid &&
        invoice.dueDate != null &&
        invoice.dueDate!.isBefore(DateTime.now());

    Color badgeColor;
    String statusLabel;
    if (invoice.invoiceStatus == InvoiceRecordStatus.cancelled) {
      badgeColor = Colors.red;
      statusLabel = 'CANCELLED';
    } else if (invoice.invoiceStatus == InvoiceRecordStatus.draft) {
      badgeColor = Colors.grey;
      statusLabel = 'DRAFT';
    } else if (invoice.paymentStatus == InvoicePaymentStatus.paid) {
      badgeColor = Colors.green;
      statusLabel = 'PAID IN FULL';
    } else if (isOverdue) {
      badgeColor = Colors.deepOrange;
      statusLabel = 'PAYMENT OVERDUE';
    } else if (invoice.paymentStatus == InvoicePaymentStatus.partial) {
      badgeColor = Colors.orange;
      statusLabel = 'PARTIALLY PAID';
    } else {
      badgeColor = Colors.blue;
      statusLabel = 'PAYMENT PENDING';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'FY: ${invoice.financialYear}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 16),
            Text(
              'Date: ${invoice.invoiceDate.day}/${invoice.invoiceDate.month}/${invoice.invoiceDate.year}',
              style: const TextStyle(fontSize: 13),
            ),
            const Spacer(),
            Text(
              'Grand Total: ${IndianCurrencyFormatter.format(invoice.grandTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 16),
            Text(
              'Balance: ${IndianCurrencyFormatter.format(invoice.outstandingAmount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: invoice.outstandingAmount > 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(InvoiceModel invoice, bool isIntraState) {
    final comp = invoice.companySnapshot;
    final cust = invoice.customerSnapshot;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TAX INVOICE Header
            Center(
              child: Text(
                'TAX INVOICE',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Company & Invoice Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company (Supplier)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comp.companyName.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(comp.registeredAddress, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('GSTIN/UIN: ${comp.gstin}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('State Name: ${comp.state}, Code: ${comp.stateCode}',
                          style: const TextStyle(fontSize: 12)),
                      Text('PAN: ${comp.pan}', style: const TextStyle(fontSize: 12)),
                      Text('Email: ${comp.email}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Metadata
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rowKV('Invoice No.', invoice.invoiceNumber, isBold: true),
                      _rowKV('Dated', '${invoice.invoiceDate.day}/${invoice.invoiceDate.month}/${invoice.invoiceDate.year}'),
                      if (invoice.deliveryNote.isNotEmpty) _rowKV('Delivery Note', invoice.deliveryNote),
                      if (invoice.modeOfPayment != null) _rowKV('Mode/Terms of Payment', invoice.modeOfPayment!),
                      if (invoice.buyerOrderNumber != null) _rowKV("Buyer's Order No.", invoice.buyerOrderNumber!),
                      if (invoice.motorVehicleNumber != null) _rowKV('Motor Vehicle No.', invoice.motorVehicleNumber!),
                      if (invoice.destination.isNotEmpty) _rowKV('Destination', invoice.destination),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Customer (Buyer)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buyer (Bill to):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(cust.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(cust.billingAddress, style: const TextStyle(fontSize: 12)),
                      Text('GSTIN/UIN: ${cust.gstin}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text('State: ${cust.stateName}, Code: ${cust.stateCode}',
                          style: const TextStyle(fontSize: 12)),
                      if (cust.placeOfSupply.isNotEmpty)
                        Text('Place of Supply: ${cust.placeOfSupply}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Items Table
            Table(
              border: TableBorder.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.8,
              ),
              columnWidths: const {
                0: FixedColumnWidth(36), // Sl
                1: FlexColumnWidth(4), // Desc
                2: FixedColumnWidth(80), // HSN
                3: FixedColumnWidth(60), // Qty
                4: FixedColumnWidth(80), // Rate
                5: FixedColumnWidth(50), // Unit
                6: FixedColumnWidth(55), // Disc
                7: FixedColumnWidth(100), // Amount
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  children: [
                    _thCell('Sl'),
                    _thCell('Description of Goods', align: TextAlign.left),
                    _thCell('HSN/SAC'),
                    _thCell('Qty'),
                    _thCell('Rate (₹)'),
                    _thCell('Per'),
                    _thCell('Disc %'),
                    _thCell('Amount (₹)', align: TextAlign.right),
                  ],
                ),
                for (int i = 0; i < invoice.items.length; i++)
                  TableRow(
                    children: [
                      _tdCell('${i + 1}'),
                      _tdCell(invoice.items[i].description, align: TextAlign.left, isBold: true),
                      _tdCell(invoice.items[i].hsnSac),
                      _tdCell(invoice.items[i].quantity.toStringAsFixed(0)),
                      _tdCell(IndianCurrencyFormatter.format(invoice.items[i].rate, includeSymbol: false)),
                      _tdCell(invoice.items[i].unit),
                      _tdCell(invoice.items[i].discountPercent > 0
                          ? '${invoice.items[i].discountPercent.toStringAsFixed(1)}%'
                          : '-'),
                      _tdCell(IndianCurrencyFormatter.format(invoice.items[i].taxableAmount, includeSymbol: false),
                          align: TextAlign.right),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Totals & Tax Summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amount in Words:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(invoice.amountInWords,
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      const Text('Tax in Words:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(invoice.taxAmountInWords,
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 16),
                      // Bank Details
                      Text('Bank Name: ${comp.bankName}', style: const TextStyle(fontSize: 12)),
                      Text('A/c No: ${comp.accountNumber} • IFSC: ${comp.ifscCode}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _summaryKV('Total Quantity', '${invoice.totalQuantity.toStringAsFixed(0)} PCS'),
                        _summaryKV('Taxable Value', IndianCurrencyFormatter.format(invoice.taxableAmount)),
                        if (invoice.cgstAmount > 0)
                          _summaryKV('Central Tax (CGST)', IndianCurrencyFormatter.format(invoice.cgstAmount)),
                        if (invoice.sgstAmount > 0)
                          _summaryKV('State Tax (SGST)', IndianCurrencyFormatter.format(invoice.sgstAmount)),
                        if (invoice.igstAmount > 0)
                          _summaryKV('Integrated Tax (IGST)', IndianCurrencyFormatter.format(invoice.igstAmount)),
                        if (invoice.otherCharges > 0)
                          _summaryKV('Other Charges', IndianCurrencyFormatter.format(invoice.otherCharges)),
                        if (invoice.roundOff != 0)
                          _summaryKV('Rounding Adjustment', IndianCurrencyFormatter.format(invoice.roundOff)),
                        const Divider(),
                        _summaryKV(
                          'Grand Total',
                          IndianCurrencyFormatter.format(invoice.grandTotal),
                          isBold: true,
                          fontSize: 16,
                        ),
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

  Widget _buildPaymentsSection(
    InvoiceModel invoice,
    AsyncValue<List<dynamic>> paymentsAsync,
    String userId,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Payment History & Transactions',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                if (invoice.outstandingAmount > 0.01 &&
                    invoice.invoiceStatus != InvoiceRecordStatus.cancelled)
                  FilledButton.tonalIcon(
                    onPressed: () => RecordPaymentDialog.show(
                      context,
                      invoice: invoice,
                      userId: userId,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Record Payment'),
                  ),
              ],
            ),
            const Divider(height: 24),
            paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading payments: $err'),
              data: (payments) {
                if (payments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No payments recorded yet for this invoice.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Table(
                  border: TableBorder.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(2), // Date
                    1: FlexColumnWidth(2), // Method
                    2: FlexColumnWidth(2), // Amount
                    3: FlexColumnWidth(3), // Ref
                    4: FlexColumnWidth(2), // Notes
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      ),
                      children: [
                        _thCell('Date'),
                        _thCell('Payment Method'),
                        _thCell('Amount', align: TextAlign.right),
                        _thCell('Reference / UTR'),
                        _thCell('Notes'),
                      ],
                    ),
                    for (final p in payments)
                      TableRow(
                        children: [
                          _tdCell('${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}'),
                          _tdCell(p.paymentMethod),
                          _tdCell(IndianCurrencyFormatter.format(p.amount), align: TextAlign.right, isBold: true),
                          _tdCell(p.transactionReference ?? '-'),
                          _tdCell(p.notes ?? '-'),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowKV(String k, String v, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text('$k:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryKV(String k, String v, {bool isBold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            v,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tdCell(String text, {TextAlign align = TextAlign.center, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
