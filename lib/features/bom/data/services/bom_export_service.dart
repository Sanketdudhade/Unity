import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';
import 'package:unity/features/products/data/models/product_model.dart';

/// Pure-Dart generator for BOM Excel (.xlsx) and CSV (.csv) exports.
class BomExportService {
  BomExportService._();

  /// Generates a standardized, multi-section CSV string with proper escaping and UTF-8 encoding.
  static Uint8List generateBomCsv({
    required ProductModel product,
    required ProductBomModel bom,
  }) {
    final buffer = StringBuffer();

    // Helper for escaping CSV fields
    String escape(String value) {
      if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
        return '"${value.replaceAll('"', '""')}"';
      }
      return value;
    }

    // 1. Header Information Block
    buffer.writeln('BILL OF MATERIAL');
    buffer.writeln('PROJECT:,,TOOL NO:,${escape(bom.toolNo.isNotEmpty ? bom.toolNo : product.partCode)}');
    buffer.writeln('PART NO / REV.:,${escape(product.partCode)},TOOL NAME:,${escape(bom.toolName.isNotEmpty ? bom.toolName : product.name)}');
    buffer.writeln('PART NAME:,${escape(product.name)},DESIGNED BY:,${escape(bom.designedBy)}');
    buffer.writeln('MATERIAL (SHEET):,${escape(bom.materialSheet)},DATE:,${escape(bom.date.isNotEmpty ? bom.date : DateTime.now().toString().split(' ').first)}');
    buffer.writeln('MATERIAL THICKNESS:,${escape(bom.materialThickness)},CUSTOMER:,${escape(bom.customer.isNotEmpty ? bom.customer : product.customerReference)}');
    buffer.writeln('');

    // 2. Main Manufacturing Components Section
    buffer.writeln('MAIN COMPONENTS / MACHINED PARTS');
    buffer.writeln([
      'Det No.',
      'Name of Part',
      'Qty',
      'Material',
      'Finish Height',
      'Finish Width',
      'Finish Length',
      'Row Height',
      'Row Width',
      'Row Length',
      'Material Vendor',
      'Material In',
      'Milling/Grinding',
      'Jig Boring',
      'VMC',
      'Wire Cut',
      'Hardening',
      'Assly',
      'Inventory SKU',
      'Inventory Mapping Status',
    ].map(escape).join(','));

    for (final c in bom.mainComponents) {
      buffer.writeln([
        c.detNo,
        c.nameOfPart,
        c.qty.toString(),
        c.material,
        c.finishHeight,
        c.finishWidth,
        c.finishLength,
        c.rowHeight,
        c.rowWidth,
        c.rowLength,
        c.materialVendor,
        c.materialIn,
        c.millingGrinding,
        c.jigBoring,
        c.vmc,
        c.wireCut,
        c.hardening,
        c.assly,
        c.inventoryMaterialSku ?? '',
        c.mappingStatus.label,
      ].map(escape).join(','));
    }

    buffer.writeln('');

    // 3. Standard BOM List Section
    buffer.writeln('STD BOM LIST / OFF-THE-SHELF PARTS');
    buffer.writeln([
      'Det No.',
      'Name of Part',
      'Vendor / Supplier',
      'Part Code',
      'Qty',
      'Inventory SKU',
      'Inventory Mapping Status',
    ].map(escape).join(','));

    for (final s in bom.standardItems) {
      buffer.writeln([
        s.detNo,
        s.nameOfPart,
        s.vendor,
        s.partCode,
        s.qty.toString(),
        s.inventoryMaterialSku ?? '',
        s.mappingStatus.label,
      ].map(escape).join(','));
    }

    // Include UTF-8 BOM so Excel opens with proper character rendering
    final bytes = utf8.encode(buffer.toString());
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes]);
  }

  /// Generates a valid Office Open XML (.xlsx) spreadsheet binary from BOM data.
  /// Uses pure Dart archive packaging and XML structures.
  static Uint8List generateBomXlsx({
    required ProductModel product,
    required ProductBomModel bom,
  }) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>''';
    _addFile(archive, '[Content_Types].xml', contentTypes);

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
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>''';
    _addFile(archive, 'xl/_rels/workbook.xml.rels', wbRels);

    // 4. xl/workbook.xml
    const workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Main Components" sheetId="1" r:id="rId1"/>
    <sheet name="Standard BOM List" sheetId="2" r:id="rId2"/>
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

    String xmlEscape(String text) {
      return text
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');
    }

    // Helper to format a cell
    String cellRef(int colIndex, int rowIndex) {
      String colLetter = '';
      int temp = colIndex;
      while (temp >= 0) {
        colLetter = String.fromCharCode((temp % 26) + 65) + colLetter;
        temp = (temp ~/ 26) - 1;
      }
      return '$colLetter$rowIndex';
    }

    // 5. Build Sheet 1: Main Components
    final sheet1Rows = StringBuffer();
    int r1 = 1;

    void addRow(StringBuffer sb, int rowNum, List<dynamic> values) {
      sb.write('<row r="$rowNum">');
      for (int c = 0; c < values.length; c++) {
        final val = values[c];
        final ref = cellRef(c, rowNum);
        if (val is num) {
          sb.write('<c r="$ref"><v>$val</v></c>');
        } else {
          final sVal = val.toString();
          if (sVal.isNotEmpty) {
            final sIdx = getStrIndex(sVal);
            sb.write('<c r="$ref" t="s"><v>$sIdx</v></c>');
          }
        }
      }
      sb.write('</row>');
    }

    // Header info rows on Sheet 1
    addRow(sheet1Rows, r1++, ['BILL OF MATERIAL - MANUFACTURING COMPONENTS']);
    addRow(sheet1Rows, r1++, ['PRODUCT CODE:', product.partCode, 'PRODUCT NAME:', product.name]);
    addRow(sheet1Rows, r1++, ['TOOL NO:', bom.toolNo.isNotEmpty ? bom.toolNo : product.partCode, 'TOOL NAME:', bom.toolName.isNotEmpty ? bom.toolName : product.name]);
    addRow(sheet1Rows, r1++, ['CUSTOMER:', bom.customer.isNotEmpty ? bom.customer : product.customerReference, 'DESIGNED BY:', bom.designedBy]);
    addRow(sheet1Rows, r1++, ['MATERIAL (SHEET):', bom.materialSheet, 'THICKNESS:', bom.materialThickness]);
    addRow(sheet1Rows, r1++, ['BOM VERSION:', 'V${bom.version}', 'DATE:', bom.date.isNotEmpty ? bom.date : DateTime.now().toString().split(' ').first]);
    addRow(sheet1Rows, r1++, []); // Empty separator

    // Column headers for Sheet 1
    addRow(sheet1Rows, r1++, [
      'Det No.',
      'Name of Part',
      'Qty',
      'Material',
      'Finish H',
      'Finish W',
      'Finish L',
      'Row H',
      'Row W',
      'Row L',
      'Material Vendor',
      'Milling/Grinding',
      'Jig Boring',
      'VMC',
      'Wire Cut',
      'Hardening',
      'Assly',
      'Stock SKU',
      'Mapping Status',
    ]);

    for (final comp in bom.mainComponents) {
      addRow(sheet1Rows, r1++, [
        comp.detNo,
        comp.nameOfPart,
        comp.qty,
        comp.material,
        comp.finishHeight,
        comp.finishWidth,
        comp.finishLength,
        comp.rowHeight,
        comp.rowWidth,
        comp.rowLength,
        comp.materialVendor,
        comp.millingGrinding,
        comp.jigBoring,
        comp.vmc,
        comp.wireCut,
        comp.hardening,
        comp.assly,
        comp.inventoryMaterialSku ?? '',
        comp.mappingStatus.label,
      ]);
    }

    final sheet1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    $sheet1Rows
  </sheetData>
</worksheet>''';
    _addFile(archive, 'xl/worksheets/sheet1.xml', sheet1Xml);

    // 6. Build Sheet 2: Standard BOM List
    final sheet2Rows = StringBuffer();
    int r2 = 1;

    addRow(sheet2Rows, r2++, ['STD BOM LIST']);
    addRow(sheet2Rows, r2++, [
      'Det No.',
      'Name of Part',
      'Vendor',
      'Part Code',
      'Qty',
      'Stock SKU',
      'Mapping Status',
    ]);

    for (final std in bom.standardItems) {
      addRow(sheet2Rows, r2++, [
        std.detNo,
        std.nameOfPart,
        std.vendor,
        std.partCode,
        std.qty,
        std.inventoryMaterialSku ?? '',
        std.mappingStatus.label,
      ]);
    }

    final sheet2Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    $sheet2Rows
  </sheetData>
</worksheet>''';
    _addFile(archive, 'xl/worksheets/sheet2.xml', sheet2Xml);

    // 7. xl/sharedStrings.xml
    final ssBuilder = StringBuffer();
    ssBuilder.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    ssBuilder.write('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${sharedStrings.length}" uniqueCount="${sharedStrings.length}">\n');
    for (final s in sharedStrings) {
      ssBuilder.write('  <si><t>${xmlEscape(s)}</t></si>\n');
    }
    ssBuilder.write('</sst>');
    _addFile(archive, 'xl/sharedStrings.xml', ssBuilder.toString());

    // Encode to ZIP (.xlsx format)
    final zipEncoder = ZipEncoder();
    final output = zipEncoder.encode(archive);
    return Uint8List.fromList(output ?? []);
  }

  static void _addFile(Archive archive, String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }
}
