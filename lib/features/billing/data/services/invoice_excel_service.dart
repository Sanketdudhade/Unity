import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../models/invoice_model.dart';

class InvoiceExcelService {
  InvoiceExcelService._();

  /// Generates standard Excel (.xlsx) file matching the reference invoice.
  static Uint8List generateInvoiceXlsx(InvoiceModel invoice) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>''';
    _addFile(archive, '[Content_Types].xml', contentTypesXml);

    // 2. _rels/.rels
    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    _addFile(archive, '_rels/.rels', rootRels);

    // 3. xl/_rels/workbook.xml.rels
    const wbRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>''';
    _addFile(archive, 'xl/_rels/workbook.xml.rels', wbRels);

    // 4. xl/workbook.xml
    const workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Tax Invoice" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    _addFile(archive, 'xl/workbook.xml', workbookXml);

    // Shared Strings collector
    final List<String> sharedStrings = [];
    final Map<String, int> stringMap = {};

    int getStrIndex(String text) {
      if (stringMap.containsKey(text)) return stringMap[text]!;
      final idx = sharedStrings.length;
      sharedStrings.add(text);
      stringMap[text] = idx;
      return idx;
    }

    String cellRef(int colIndex, int rowIndex) {
      String colLetter = '';
      int temp = colIndex;
      while (temp >= 0) {
        colLetter = String.fromCharCode((temp % 26) + 65) + colLetter;
        temp = (temp ~/ 26) - 1;
      }
      return '$colLetter$rowIndex';
    }

    final sheet1Rows = StringBuffer();
    int r = 1;

    void addRow(List<dynamic> values) {
      sheet1Rows.write('<row r="$r">');
      for (int c = 0; c < values.length; c++) {
        final val = values[c];
        final ref = cellRef(c, r);
        if (val is num) {
          sheet1Rows.write('<c r="$ref"><v>$val</v></c>');
        } else {
          final sVal = val?.toString() ?? '';
          if (sVal.isNotEmpty) {
            final sIdx = getStrIndex(sVal);
            sheet1Rows.write('<c r="$ref" t="s"><v>$sIdx</v></c>');
          }
        }
      }
      sheet1Rows.write('</row>');
      r++;
    }

    final comp = invoice.companySnapshot;
    final cust = invoice.customerSnapshot;
    final isIntraState = cust.stateCode.trim() == comp.stateCode.trim();

    // 1. Header
    addRow(['TAX INVOICE']);
    addRow([comp.companyName.toUpperCase()]);
    addRow([comp.registeredAddress]);
    addRow(['GSTIN/UIN:', comp.gstin, 'PAN:', comp.pan, 'State:', comp.state, 'Code:', comp.stateCode]);
    addRow(['Email:', comp.email]);
    addRow([]); // Blank line

    // 2. Invoice & Customer Meta
    addRow(['INVOICE DETAILS', '', '', 'BUYER (BILL TO)']);
    addRow(['Invoice No:', invoice.invoiceNumber, '', 'Name:', cust.customerName]);
    addRow(['Dated:', invoice.invoiceDate.toIso8601String().split('T').first, '', 'Address:', cust.billingAddress]);
    addRow(['Delivery Note:', invoice.deliveryNote, '', 'GSTIN/UIN:', cust.gstin]);
    addRow(['Payment Terms:', invoice.modeOfPayment ?? '', '', 'State:', cust.stateName, 'Code:', cust.stateCode]);
    addRow(["Buyer's Order No:", invoice.buyerOrderNumber ?? '', '', 'Place of Supply:', cust.placeOfSupply]);
    addRow(['Vehicle No:', invoice.motorVehicleNumber ?? '', '', 'Email:', cust.email]);
    addRow(['Destination:', invoice.destination, '', 'Phone:', cust.phone]);
    addRow([]); // Blank line

    // 3. Line Items Table Header
    addRow([
      'Sl No.',
      'Description of Goods',
      'HSN/SAC',
      'Quantity',
      'Unit',
      'Rate',
      'Discount %',
      'Taxable Amount',
      if (isIntraState) ...['CGST %', 'CGST Amt', 'SGST %', 'SGST Amt'] else ...['IGST %', 'IGST Amt'],
      'Total Item Value',
    ]);

    // Items
    for (int i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      addRow([
        i + 1,
        item.description,
        item.hsnSac,
        item.quantity,
        item.unit,
        item.rate,
        item.discountPercent,
        item.taxableAmount,
        if (isIntraState) ...[
          item.gstRate / 2,
          item.cgstAmount,
          item.gstRate / 2,
          item.sgstAmount,
        ] else ...[
          item.gstRate,
          item.igstAmount,
        ],
        item.totalAmount,
      ]);
    }
    addRow([]); // Blank line

    // 4. Totals Summary
    addRow(['SUMMARY']);
    addRow(['Total Quantity:', invoice.totalQuantity]);
    addRow(['Total Taxable Value:', invoice.taxableAmount]);
    if (invoice.cgstAmount > 0) addRow(['Central Tax (CGST):', invoice.cgstAmount]);
    if (invoice.sgstAmount > 0) addRow(['State Tax (SGST):', invoice.sgstAmount]);
    if (invoice.igstAmount > 0) addRow(['Integrated Tax (IGST):', invoice.igstAmount]);
    addRow(['Total Tax:', invoice.totalTax]);
    if (invoice.otherCharges > 0) addRow(['Other Charges:', invoice.otherCharges]);
    if (invoice.roundOff != 0) addRow(['Rounding Adjustment:', invoice.roundOff]);
    addRow(['Grand Total:', invoice.grandTotal]);
    addRow([]);

    // 5. Amount in Words
    addRow(['Amount in Words:', invoice.amountInWords]);
    addRow(['Tax in Words:', invoice.taxAmountInWords]);
    addRow([]);

    // 6. Bank Details & Signatory
    addRow(['BANK DETAILS']);
    addRow(['Bank Name:', comp.bankName]);
    addRow(['Account No:', comp.accountNumber]);
    addRow(['Branch & IFSC:', '${comp.branch} / ${comp.ifscCode}']);
    addRow([]);
    addRow(['Declaration:', comp.declaration]);
    addRow(['for ${comp.companyName.toUpperCase()}', '', '', 'Authorised Signatory:', comp.authorisedSignatory]);

    // 5. xl/worksheets/sheet1.xml
    final sheet1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    $sheet1Rows
  </sheetData>
</worksheet>''';
    _addFile(archive, 'xl/worksheets/sheet1.xml', sheet1Xml);

    // 6. xl/sharedStrings.xml
    final ssSb = StringBuffer();
    ssSb.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    ssSb.write('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${sharedStrings.length}" uniqueCount="${sharedStrings.length}">\n');
    for (final s in sharedStrings) {
      ssSb.write('  <si><t>${_xmlEscape(s)}</t></si>\n');
    }
    ssSb.write('</sst>');
    _addFile(archive, 'xl/sharedStrings.xml', ssSb.toString());

    final zipEncoder = ZipEncoder();
    final encodedData = zipEncoder.encode(archive);
    return Uint8List.fromList(encodedData);
  }

  static void _addFile(Archive archive, String filename, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(filename, bytes.length, bytes));
  }

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
