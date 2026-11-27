import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_model.dart';
import 'indian_currency_formatter.dart';

class InvoicePdfService {
  /// Generates the standard A4 GST Tax Invoice PDF.
  Future<Uint8List> generatePdf(InvoiceModel invoice) async {
    final pdf = pw.Document();

    final isIntraState = invoice.customerSnapshot.stateCode.trim() ==
        invoice.companySnapshot.stateCode.trim();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeaderTitle(invoice),
                _buildCompanyAndInvoiceDetails(invoice),
                _buildCustomerDetails(invoice),
                _buildItemsTable(invoice),
                _buildTotalsSection(invoice),
                _buildTaxBreakdownTable(invoice, isIntraState),
                _buildAmountInWordsSection(invoice),
                _buildFooterAndDeclaration(invoice),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print invoice directly to printer dialog
  Future<void> printInvoice(InvoiceModel invoice) async {
    final bytes = await generatePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Invoice_${invoice.invoiceNumber.replaceAll('/', '_')}',
    );
  }

  /// Share or save PDF
  Future<void> sharePdf(InvoiceModel invoice) async {
    final bytes = await generatePdf(invoice);
    final filename = 'Invoice_${invoice.invoiceNumber.replaceAll('/', '_')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  pw.Widget _buildHeaderTitle(InvoiceModel invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Center(
        child: pw.Text(
          'TAX INVOICE',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildCompanyAndInvoiceDetails(InvoiceModel invoice) {
    final company = invoice.companySnapshot;
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Company Details
          pw.Expanded(
            flex: 5,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    company.companyName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    company.registeredAddress,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text('GSTIN/UIN: ${company.gstin}',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('State Name: ${company.state}, Code: ${company.stateCode}',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('PAN: ${company.pan}',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('E-Mail: ${company.email}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ),
          // Right: Invoice Meta Grid
          pw.Expanded(
            flex: 5,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _metaRow('Invoice No.', invoice.invoiceNumber, isBold: true),
                  _metaRow('Dated', _formatDate(invoice.invoiceDate)),
                  _metaRow('Delivery Note', invoice.deliveryNote),
                  _metaRow('Mode/Terms of Payment', invoice.modeOfPayment ?? ''),
                  _metaRow("Buyer's Order No.", invoice.buyerOrderNumber ?? ''),
                  _metaRow('Motor Vehicle No.', invoice.motorVehicleNumber ?? ''),
                  _metaRow('Destination', invoice.destination),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _metaRow(String label, String value, {bool isBold = false}) {
    if (value.trim().isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 105,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCustomerDetails(InvoiceModel invoice) {
    final cust = invoice.customerSnapshot;
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Buyer (Bill to):',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  cust.customerName,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(cust.billingAddress,
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text('GSTIN/UIN: ${cust.gstin}',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('State: ${cust.stateName}, Code: ${cust.stateCode}',
                    style: const pw.TextStyle(fontSize: 8)),
                if (cust.placeOfSupply.isNotEmpty)
                  pw.Text('Place of Supply: ${cust.placeOfSupply}',
                      style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(InvoiceModel invoice) {
    return pw.Table(
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(24), // Sl
        1: pw.FlexColumnWidth(5), // Description
        2: pw.FixedColumnWidth(55), // HSN/SAC
        3: pw.FixedColumnWidth(40), // Qty
        4: pw.FixedColumnWidth(48), // Rate
        5: pw.FixedColumnWidth(32), // Unit
        6: pw.FixedColumnWidth(35), // Disc %
        7: pw.FixedColumnWidth(60), // Amount
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.black, width: 1),
            ),
          ),
          children: [
            _th('Sl'),
            _th('Description of Goods', align: pw.TextAlign.left),
            _th('HSN/SAC'),
            _th('Qty'),
            _th('Rate'),
            _th('Per'),
            _th('Dis %'),
            _th('Amount', align: pw.TextAlign.right),
          ],
        ),
        // Rows
        for (var i = 0; i < invoice.items.length; i++)
          pw.TableRow(
            children: [
              _td('${i + 1}'),
              _td(invoice.items[i].description, align: pw.TextAlign.left, isBold: true),
              _td(invoice.items[i].hsnSac),
              _td(invoice.items[i].quantity.toStringAsFixed(0)),
              _td(IndianCurrencyFormatter.format(invoice.items[i].rate, includeSymbol: false)),
              _td(invoice.items[i].unit),
              _td(invoice.items[i].discountPercent > 0
                  ? '${invoice.items[i].discountPercent.toStringAsFixed(1)}%'
                  : '-'),
              _td(IndianCurrencyFormatter.format(invoice.items[i].taxableAmount, includeSymbol: false),
                  align: pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  pw.Widget _buildTotalsSection(InvoiceModel invoice) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Quantity: ${invoice.totalQuantity.toStringAsFixed(0)}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: PdfColors.black, width: 0.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _summaryRow('Taxable Value', invoice.taxableAmount),
                  if (invoice.cgstAmount > 0)
                    _summaryRow('CGST', invoice.cgstAmount),
                  if (invoice.sgstAmount > 0)
                    _summaryRow('SGST', invoice.sgstAmount),
                  if (invoice.igstAmount > 0)
                    _summaryRow('IGST', invoice.igstAmount),
                  if (invoice.otherCharges > 0)
                    _summaryRow('Other Charges', invoice.otherCharges),
                  if (invoice.roundOff != 0)
                    _summaryRow('Round Off', invoice.roundOff),
                  pw.Divider(thickness: 0.5, color: PdfColors.black),
                  _summaryRow('Grand Total', invoice.grandTotal, isBold: true, fontSize: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTaxBreakdownTable(InvoiceModel invoice, bool isIntraState) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Table(
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
        ),
        columnWidths: isIntraState
            ? const {
                0: pw.FlexColumnWidth(2), // HSN/SAC
                1: pw.FlexColumnWidth(2.5), // Taxable Value
                2: pw.FlexColumnWidth(2.5), // CGST
                3: pw.FlexColumnWidth(2.5), // SGST
                4: pw.FlexColumnWidth(2.5), // Total Tax
              }
            : const {
                0: pw.FlexColumnWidth(3), // HSN/SAC
                1: pw.FlexColumnWidth(3), // Taxable Value
                2: pw.FlexColumnWidth(3), // IGST
                3: pw.FlexColumnWidth(3), // Total Tax
              },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _th('HSN/SAC'),
              _th('Taxable Value'),
              if (isIntraState) ...[
                _th('Central Tax'),
                _th('State Tax'),
              ] else ...[
                _th('Integrated Tax'),
              ],
              _th('Total Tax'),
            ],
          ),
          for (final item in invoice.items)
            pw.TableRow(
              children: [
                _td(item.hsnSac),
                _td(IndianCurrencyFormatter.format(item.taxableAmount, includeSymbol: false)),
                if (isIntraState) ...[
                  _td('${(item.gstRate / 2).toStringAsFixed(1)}% : ${IndianCurrencyFormatter.format(item.cgstAmount, includeSymbol: false)}'),
                  _td('${(item.gstRate / 2).toStringAsFixed(1)}% : ${IndianCurrencyFormatter.format(item.sgstAmount, includeSymbol: false)}'),
                ] else ...[
                  _td('${item.gstRate.toStringAsFixed(1)}% : ${IndianCurrencyFormatter.format(item.igstAmount, includeSymbol: false)}'),
                ],
                _td(IndianCurrencyFormatter.format(item.cgstAmount + item.sgstAmount + item.igstAmount, includeSymbol: false)),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _buildAmountInWordsSection(InvoiceModel invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 8),
              children: [
                pw.TextSpan(
                  text: 'Amount Chargeable (in words): ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(text: invoice.amountInWords),
              ],
            ),
          ),
          pw.SizedBox(height: 2),
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 8),
              children: [
                pw.TextSpan(
                  text: 'Tax Amount (in words): ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(text: invoice.taxAmountInWords),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooterAndDeclaration(InvoiceModel invoice) {
    final company = invoice.companySnapshot;
    return pw.Expanded(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Bank details & Declaration
          pw.Expanded(
            flex: 6,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Company Bank Details:',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Bank Name: ${company.bankName}',
                      style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('A/c No.: ${company.accountNumber}',
                      style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('Branch & IFSC: ${company.branch} & ${company.ifscCode}',
                      style: const pw.TextStyle(fontSize: 7.5)),
                  pw.SizedBox(height: 6),
                  pw.Text('Declaration:',
                      style: pw.TextStyle(
                          fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    company.declaration,
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ),
          // Right: Signatory
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('for ${company.companyName.toUpperCase()}',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 35),
                  pw.Text(company.authorisedSignatory,
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Authorised Signatory',
                      style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(String label, double val, {bool isBold = false, double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            IndianCurrencyFormatter.format(val),
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _td(String text,
      {pw.TextAlign align = pw.TextAlign.center, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = _monthName(dt.month);
    final year = dt.year;
    return '$day-$month-$year';
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
