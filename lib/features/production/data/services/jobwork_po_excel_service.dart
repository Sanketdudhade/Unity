import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import '../models/jobwork_po_model.dart';

/// Service creating standard Excel (.xlsx) documents replicating the reference M/G and VMC Purchase Orders.
class JobworkPoExcelService {
  JobworkPoExcelService._();

  static Uint8List generateXlsx(JobworkPoModel po) {
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
    final sheetName = po.isVmc ? 'PURCHASE ORDER' : 'M-G JOBWORK PO';
    final workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="$sheetName" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    _addFile(archive, 'xl/workbook.xml', workbookXml);

    // Shared Strings collector
    final List<String> sharedStrings = [];
    final Map<String, int> stringMap = {};

    int getOrAddString(String text) {
      if (stringMap.containsKey(text)) return stringMap[text]!;
      final idx = sharedStrings.length;
      sharedStrings.add(text);
      stringMap[text] = idx;
      return idx;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(po.date);

    // 5. xl/worksheets/sheet1.xml
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sb.writeln('  <sheetData>');

    int r = 1;

    void writeEmptyRow() {
      sb.writeln('    <row r="$r"/>');
      r++;
    }

    void writeStringCell(String col, String val) {
      final sIdx = getOrAddString(val);
      sb.writeln('      <c r="$col$r" t="s"><v>$sIdx</v></c>');
    }

    void writeNumCell(String col, num val) {
      sb.writeln('      <c r="$col$r"><v>$val</v></c>');
    }

    if (po.isVmc) {
      // VMC layout based on PO_VMC.xlsx
      writeEmptyRow(); // 1
      writeEmptyRow(); // 2
      writeEmptyRow(); // 3

      // Row 4: Title
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'PURCHASE ORDER');
      sb.writeln('    </row>');
      r++;

      // Row 5: PO No & Dated
      sb.writeln('    <row r="$r">');
      writeStringCell('D', 'Po No :${po.poNumber}');
      writeStringCell('H', 'Dated');
      sb.writeln('    </row>');
      r++;

      // Row 6: Company & Date Value
      sb.writeln('    <row r="$r">');
      writeStringCell('B', po.companyName);
      writeStringCell('H', dateStr);
      sb.writeln('    </row>');
      r++;

      // Row 7: Delivery Note & Terms
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'E-70/14');
      writeStringCell('D', 'Delivery Note');
      writeStringCell('H', 'Mode/Terms of Payment');
      sb.writeln('    </row>');
      r++;

      // Row 8: MIDC WALUJ
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'MIDC WALUJ,');
      sb.writeln('    </row>');
      r++;

      // Row 9: Supplier's Ref & Other Ref
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'AURANGABAD 431136.');
      writeStringCell('D', "Supplier's Ref.");
      writeStringCell('H', 'Other Reference(s)');
      sb.writeln('    </row>');
      r++;

      // Row 10: Email
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'E-mail : ${po.companyEmail}');
      if (po.suppliersRef.isNotEmpty) writeStringCell('D', po.suppliersRef);
      if (po.otherReference.isNotEmpty) writeStringCell('H', po.otherReference);
      sb.writeln('    </row>');
      r++;

      // Row 11: GSTIN & Destination
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'GSTIN/UIN');
      writeStringCell('C', po.companyGstin);
      writeStringCell('D', 'Despatch through');
      writeStringCell('H', 'Destination');
      sb.writeln('    </row>');
      r++;

      // Row 12
      sb.writeln('    <row r="$r">');
      if (po.dispatchedThrough.isNotEmpty) writeStringCell('D', po.dispatchedThrough);
      if (po.destination.isNotEmpty) writeStringCell('H', po.destination);
      sb.writeln('    </row>');
      r++;

      writeEmptyRow(); // 13

      // Row 14: To, Vendor Name
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'To,');
      writeStringCell('C', po.vendorName);
      sb.writeln('    </row>');
      r++;

      // Row 15: Vendor Address line 1 & Port of Loading / Discharge
      sb.writeln('    <row r="$r">');
      writeStringCell('C', po.vendorAddress.isNotEmpty ? po.vendorAddress : 'Gat No.50, Dehu-Alandi Road, Talwade');
      writeStringCell('D', 'City/Port of Loading');
      writeStringCell('H', 'City/Port of Discharge');
      sb.writeln('    </row>');
      r++;

      // Row 16: City
      sb.writeln('    <row r="$r">');
      writeStringCell('C', 'Pune Maharashtra 411062');
      if (po.cityPortLoading.isNotEmpty) writeStringCell('D', po.cityPortLoading);
      if (po.cityPortDischarge.isNotEmpty) writeStringCell('H', po.cityPortDischarge);
      sb.writeln('    </row>');
      r++;

      // Row 17: Country
      sb.writeln('    <row r="$r">');
      writeStringCell('C', 'India.');
      sb.writeln('    </row>');
      r++;

      // Row 18: Vendor GSTIN
      sb.writeln('    <row r="$r">');
      writeStringCell('C', 'GSTIN ${po.vendorGstin.isNotEmpty ? po.vendorGstin : "27AJKPI1882P1ZJ"}');
      sb.writeln('    </row>');
      r++;

      writeEmptyRow(); // 19
      writeEmptyRow(); // 20

      // Row 21: Table Header
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'SR NO');
      writeStringCell('C', 'Description of Goods');
      writeStringCell('D', 'HSN CODE');
      writeStringCell('E', 'Quantity           NOS');
      writeStringCell('F', 'Rate');
      writeStringCell('G', 'per');
      writeStringCell('H', 'Amount');
      sb.writeln('    </row>');
      r++;

      // Rows 22+: Table Data
      for (final it in po.items) {
        sb.writeln('    <row r="$r">');
        writeNumCell('B', it.srNo);
        writeStringCell('C', it.description);
        writeStringCell('D', it.hsnCode.isNotEmpty ? it.hsnCode : '998898');
        writeNumCell('E', it.nos);
        writeNumCell('F', it.rate);
        writeStringCell('G', it.per.isNotEmpty ? it.per : 'NOS');
        writeNumCell('H', it.total);
        sb.writeln('    </row>');
        r++;
      }

      writeEmptyRow();

      // TOTAL Row
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'TOTAL');
      writeNumCell('H', po.subTotal);
      sb.writeln('    </row>');
      r++;

      // E. & O.E
      sb.writeln('    <row r="$r">');
      writeStringCell('H', 'E. & O.E');
      sb.writeln('    </row>');
      r++;

      writeEmptyRow();
      writeEmptyRow();

      // Terms & Conditions
      sb.writeln('    <row r="$r">');
      writeStringCell('C', 'TERMS AND CONDITION');
      sb.writeln('    </row>');
      r++;

      sb.writeln('    <row r="$r">');
      writeStringCell('B', '*');
      writeStringCell('C', po.paymentTerms.isNotEmpty ? po.paymentTerms : 'PAYMENT =90 DAYS');
      sb.writeln('    </row>');
      r++;

      sb.writeln('    <row r="$r">');
      writeStringCell('B', '1');
      writeStringCell('C', 'DELIVERY PERIOD AS PER DISCUSS');
      sb.writeln('    </row>');
      r++;

      sb.writeln('    <row r="$r">');
      writeStringCell('B', '2');
      writeStringCell('C', 'TAXES - AS A APPLICABLE  18%                                           (C GST & S GST )');
      sb.writeln('    </row>');
      r++;

      writeEmptyRow();
      writeEmptyRow();

      // Footer
      sb.writeln('    <row r="$r">');
      writeStringCell('B', "Company's VAT TIN:");
      writeStringCell('G', 'For : ${po.companyName}');
      sb.writeln('    </row>');
      r++;

      sb.writeln('    <row r="$r">');
      writeStringCell('B', "Company's CST No. :");
      sb.writeln('    </row>');
      r++;

      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'Declaration');
      writeStringCell('G', '              Authorised Signatory');
      sb.writeln('    </row>');
      r++;

      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'THIS IS COMPUTER GENERATED INVOICE HENCE SIGNATURE IS NOT REQUIRED');
      sb.writeln('    </row>');
      r++;
    } else {
      // M/G layout based on PO_M&G.xlsx
      writeEmptyRow();

      // Row 2: Title
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'M/G  JOBWORK PO');
      sb.writeln('    </row>');
      r++;

      // Row 3: PO Number & Date
      sb.writeln('    <row r="$r">');
      writeStringCell('F', 'Po No :${po.poNumber}');
      writeStringCell('I', 'Dated');
      writeStringCell('K', dateStr);
      sb.writeln('    </row>');
      r++;

      // Row 4: Company Name
      sb.writeln('    <row r="$r">');
      writeStringCell('B', po.companyName);
      sb.writeln('    </row>');
      r++;

      // Row 5: Address line 1 & Delivery note
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'E-70/14');
      writeStringCell('E', 'Delivery Note');
      writeStringCell('H', 'Mode/Terms of Payment');
      writeStringCell('K', po.paymentTerms);
      sb.writeln('    </row>');
      r++;

      // Row 6: Address line 2 & Supplier Ref
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'MIDC WALUJ,');
      writeStringCell('E', "Supplier's Ref.");
      writeStringCell('H', po.suppliersRef);
      sb.writeln('    </row>');
      r++;

      // Row 7: Address line 3
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'AURANGABAD 431136.');
      writeStringCell('E', 'Dispatched Through');
      writeStringCell('H', po.dispatchedThrough.isNotEmpty ? po.dispatchedThrough : '-');
      sb.writeln('    </row>');
      r++;

      // Row 8: Email & GSTIN
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'E-mail : ${po.companyEmail}');
      sb.writeln('    </row>');
      r++;

      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'GSTIN/UIN : ${po.companyGstin}');
      writeStringCell('G', 'City/Port of Discharge');
      writeStringCell('I', po.destination);
      sb.writeln('    </row>');
      r++;

      writeEmptyRow();

      // Row 11: Vendor "To,"
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'To,');
      writeStringCell('C', po.vendorName);
      sb.writeln('    </row>');
      r++;

      if (po.vendorAddress.isNotEmpty) {
        sb.writeln('    <row r="$r">');
        writeStringCell('C', po.vendorAddress);
        sb.writeln('    </row>');
        r++;
      }

      if (po.vendorGstin.isNotEmpty) {
        sb.writeln('    <row r="$r">');
        writeStringCell('C', po.vendorGstin);
        sb.writeln('    </row>');
        r++;
      }

      writeEmptyRow();

      // Table Header
      sb.writeln('    <row r="$r">');
      writeStringCell('B', 'SR NO');
      writeStringCell('C', 'DESCRIPTION');
      writeStringCell('D', 'THINK');
      writeStringCell('E', 'WIDTH');
      writeStringCell('F', 'LENGTH');
      writeStringCell('G', 'GRADE');
      writeStringCell('H', 'NOS');
      writeStringCell('I', 'MILLING');
      writeStringCell('J', 'GRINDING');
      writeStringCell('K', 'RATE');
      writeStringCell('L', 'TOTAL');
      sb.writeln('    </row>');
      r++;

      // Table Data Rows
      for (final it in po.items) {
        sb.writeln('    <row r="$r">');
        writeNumCell('B', it.srNo);
        writeStringCell('C', it.description);
        writeStringCell('D', it.thk);
        writeStringCell('E', it.width);
        writeStringCell('F', it.length);
        writeStringCell('G', it.grade);
        writeNumCell('H', it.nos);
        writeNumCell('I', it.milling);
        writeNumCell('J', it.grinding);
        writeNumCell('K', it.rate);
        writeNumCell('L', it.total);
        sb.writeln('    </row>');
        r++;
      }

      writeEmptyRow();

      // Subtotal Row
      sb.writeln('    <row r="$r">');
      writeNumCell('H', po.totalNos);
      writeStringCell('I', 'SUB TOTAL');
      writeNumCell('L', po.subTotal);
      sb.writeln('    </row>');
      r++;

      if (po.taxRate > 0) {
        sb.writeln('    <row r="$r">');
        writeStringCell('I', 'TAX (18%)');
        writeNumCell('L', po.cgstAmount + po.sgstAmount);
        sb.writeln('    </row>');
        r++;

        sb.writeln('    <row r="$r">');
        writeStringCell('I', 'GRAND TOTAL');
        writeNumCell('L', po.grandTotal);
        sb.writeln('    </row>');
        r++;
      }

      writeEmptyRow();

      // Terms
      for (final term in po.termsAndConditions) {
        sb.writeln('    <row r="$r">');
        writeStringCell('B', '* $term');
        sb.writeln('    </row>');
        r++;
      }

      writeEmptyRow();
      sb.writeln('    <row r="$r">');
      writeStringCell('I', 'For : ${po.companyName}');
      sb.writeln('    </row>');
      r++;
      sb.writeln('    <row r="$r">');
      writeStringCell('I', 'Authorised Signatory');
      sb.writeln('    </row>');
      r++;
    }

    sb.writeln('  </sheetData>');
    sb.writeln('</worksheet>');

    _addFile(archive, 'xl/worksheets/sheet1.xml', sb.toString());

    // 6. xl/sharedStrings.xml
    final ss = StringBuffer();
    ss.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    ss.writeln('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${sharedStrings.length}" uniqueCount="${sharedStrings.length}">');
    for (final str in sharedStrings) {
      final escaped = _escapeXml(str);
      ss.writeln('  <si><t>$escaped</t></si>');
    }
    ss.writeln('</sst>');
    _addFile(archive, 'xl/sharedStrings.xml', ss.toString());

    final zipEncoder = ZipEncoder();
    final encodedBytes = zipEncoder.encode(archive);
    return Uint8List.fromList(encodedBytes);
  }

  static void _addFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
