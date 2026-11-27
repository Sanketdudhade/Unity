import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/jobwork_po_model.dart';

/// PDF Generator replicating the official M/G and VMC Purchase Order document structures.
class JobworkPoPdfService {
  JobworkPoPdfService._();

  static Future<Uint8List> generatePdf(JobworkPoModel po) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final formattedDate = dateFormat.format(po.date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Outer Box
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Title Bar
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      po.isVmc ? 'PURCHASE ORDER' : 'M/G  JOBWORK PO',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1),
                    ),
                  ),

                  // Top Section: Company Info & PO Metadata
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left: Unity Technologies Header
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                po.companyName,
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(po.companyAddress, style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text('E-mail : ${po.companyEmail}', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text('GSTIN/UIN : ${po.companyGstin}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),

                      // Right: PO Number & References Grid
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildMetadataRow('Po No :', po.poNumber, 'Dated :', formattedDate),
                              _buildMetadataRow('Delivery Note :', po.deliveryNote, 'Payment :', po.paymentTerms),
                              _buildMetadataRow(
                                "Supplier's Ref. :",
                                po.suppliersRef,
                                po.isVmc ? 'Other Ref. :' : 'Dispatch :',
                                po.isVmc ? po.otherReference : po.dispatchedThrough,
                              ),
                              _buildMetadataRow('Destination :', po.destination, po.isVmc ? 'Dispatch :' : '', po.isVmc ? po.dispatchedThrough : ''),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  pw.Container(height: 1, color: PdfColors.black),

                  // Vendor Section ("To,")
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('To,\n', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                po.vendorName,
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                              ),
                              if (po.vendorAddress.isNotEmpty)
                                pw.Text(po.vendorAddress, style: const pw.TextStyle(fontSize: 8.5)),
                              if (po.vendorGstin.isNotEmpty)
                                pw.Text('GSTIN : ${po.vendorGstin}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Work Order : ${po.orderNumber}', style: const pw.TextStyle(fontSize: 8.5)),
                            pw.Text('Part : ${po.productName}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            if (po.isVmc && po.cityPortLoading.isNotEmpty)
                              pw.Text('Port of Loading : ${po.cityPortLoading}', style: const pw.TextStyle(fontSize: 8)),
                            if (po.isVmc && po.cityPortDischarge.isNotEmpty)
                              pw.Text('Port of Discharge : ${po.cityPortDischarge}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Line Items Table
                  if (po.isVmc) _buildVmcItemsTable(po) else _buildMgItemsTable(po),

                  // Sub Total & Taxes
                  _buildTotalsSection(po),

                  // Terms & Signatory Section
                  _buildTermsAndSignature(po),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetadataRow(String l1, String v1, String l2, String v2) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 65, child: pw.Text(l1, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(v1, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          if (l2.isNotEmpty) ...[
            pw.SizedBox(width: 50, child: pw.Text(l2, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
            pw.Expanded(child: pw.Text(v2, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        ],
      ),
    );
  }

  /// Builds the table for VMC Purchase Orders:
  /// SR NO | Description of Goods | HSN CODE | Quantity NOS | Rate | per | Amount
  static pw.Widget _buildVmcItemsTable(JobworkPoModel po) {
    const headers = [
      'SR NO',
      'Description of Goods',
      'HSN CODE',
      'Quantity NOS',
      'Rate',
      'per',
      'Amount',
    ];

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.black, width: 1),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(32), // SR NO
        1: pw.FlexColumnWidth(4.0), // Description of Goods
        2: pw.FixedColumnWidth(65), // HSN CODE
        3: pw.FixedColumnWidth(60), // Quantity NOS
        4: pw.FixedColumnWidth(48), // Rate
        5: pw.FixedColumnWidth(38), // per
        6: pw.FixedColumnWidth(58), // Amount
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
          ),
          children: headers.map((h) {
            final isNum = ['SR NO', 'HSN CODE', 'Quantity NOS', 'Rate', 'Amount'].contains(h);
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              alignment: isNum ? pw.Alignment.center : pw.Alignment.centerLeft,
              child: pw.Text(
                h,
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            );
          }).toList(),
        ),

        // Item Rows
        ...po.items.map((item) {
          return pw.TableRow(
            children: [
              _cell(item.srNo.toString(), align: pw.Alignment.center),
              _cell(item.description, align: pw.Alignment.centerLeft),
              _cell(item.hsnCode.isNotEmpty ? item.hsnCode : '998898', align: pw.Alignment.center),
              _cell(item.nos.toString(), align: pw.Alignment.center),
              _cell(item.rate > 0 ? item.rate.toStringAsFixed(0) : '0', align: pw.Alignment.centerRight),
              _cell(item.per.isNotEmpty ? item.per : 'NOS', align: pw.Alignment.center),
              _cell(item.total.toStringAsFixed(0), align: pw.Alignment.centerRight, bold: true),
            ],
          );
        }),
      ],
    );
  }

  /// Builds the table for M/G Purchase Orders:
  /// SR NO | DESCRIPTION | THK | WIDTH | LENGTH | GRADE | NOS | MILLING | GRINDING | RATE | TOTAL
  static pw.Widget _buildMgItemsTable(JobworkPoModel po) {
    const headers = [
      'SR NO',
      'DESCRIPTION',
      'THK',
      'WIDTH',
      'LENGTH',
      'GRADE',
      'NOS',
      'MILLING',
      'GRINDING',
      'RATE',
      'TOTAL',
    ];

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.black, width: 1),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(3.0),
        2: pw.FixedColumnWidth(32),
        3: pw.FixedColumnWidth(34),
        4: pw.FixedColumnWidth(36),
        5: pw.FixedColumnWidth(36),
        6: pw.FixedColumnWidth(28),
        7: pw.FixedColumnWidth(38),
        8: pw.FixedColumnWidth(40),
        9: pw.FixedColumnWidth(36),
        10: pw.FixedColumnWidth(48),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
          ),
          children: headers.map((h) {
            final isNum = ['SR NO', 'THK', 'WIDTH', 'LENGTH', 'NOS', 'MILLING', 'GRINDING', 'RATE', 'TOTAL'].contains(h);
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              alignment: isNum ? pw.Alignment.center : pw.Alignment.centerLeft,
              child: pw.Text(
                h,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
            );
          }).toList(),
        ),
        ...po.items.map((item) {
          return pw.TableRow(
            children: [
              _cell(item.srNo.toString(), align: pw.Alignment.center),
              _cell(item.description, align: pw.Alignment.centerLeft),
              _cell(item.thk, align: pw.Alignment.center),
              _cell(item.width, align: pw.Alignment.center),
              _cell(item.length, align: pw.Alignment.center),
              _cell(item.grade, align: pw.Alignment.center),
              _cell(item.nos.toString(), align: pw.Alignment.center),
              _cell(item.milling > 0 ? item.milling.toStringAsFixed(1) : '-', align: pw.Alignment.centerRight),
              _cell(item.grinding > 0 ? item.grinding.toStringAsFixed(1) : '-', align: pw.Alignment.centerRight),
              _cell(item.rate > 0 ? item.rate.toStringAsFixed(1) : '-', align: pw.Alignment.centerRight),
              _cell(item.total.toStringAsFixed(1), align: pw.Alignment.centerRight, bold: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, {pw.Alignment align = pw.Alignment.centerLeft, bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _buildTotalsSection(JobworkPoModel po) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Text('TOTAL : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('${po.totalNos} NOS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(width: 14),
              pw.Text('E. & O.E', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                children: [
                  pw.Text('SUB TOTAL : ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 8),
                  pw.Text('Rs. ${po.subTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (po.taxRate > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text('CGST (9%) + SGST (9%) : ', style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(width: 8),
                    pw.Text('Rs. ${(po.cgstAmount + po.sgstAmount).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text('GRAND TOTAL : ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 8),
                    pw.Text('Rs. ${po.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermsAndSignature(JobworkPoModel po) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Terms and Conditions & Company details
              pw.Expanded(
                flex: 6,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TERMS AND CONDITION', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ...po.termsAndConditions.map((term) => pw.Text('* $term', style: const pw.TextStyle(fontSize: 7.5))),
                    if (po.isVmc) ...[
                      pw.SizedBox(height: 8),
                      pw.Text("Company's VAT TIN:", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.Text("Company's CST No. :", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ],
                ),
              ),

              // Right: Authorized Signatory
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('For : ${po.companyName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 28),
                    pw.Text('Authorised Signatory', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.5),
          pw.Center(
            child: pw.Text(
              'THIS IS COMPUTER GENERATED INVOICE HENCE SIGNATURE IS NOT REQUIRED',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printPo(JobworkPoModel po) async {
    final bytes = await generatePdf(po);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Jobwork_PO_${po.poNumber.replaceAll('/', '_')}',
    );
  }
}
