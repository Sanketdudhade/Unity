import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:unity/features/bom/data/models/bom_component_item.dart';
import 'package:unity/features/bom/data/models/bom_standard_item.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';

/// Result container for BOM parsing and pre-flight validation.
class ParsedBomResult {
  final ProductBomModel bom;
  final List<String> errors;
  final List<String> warnings;
  final int totalRowsParsed;

  const ParsedBomResult({
    required this.bom,
    this.errors = const [],
    this.warnings = const [],
    this.totalRowsParsed = 0,
  });

  bool get isValid => errors.isEmpty && bom.totalItemsCount > 0;
}

/// Dynamic, resilient parser for Excel (.xlsx) and CSV Bill of Material documents.
/// Built with zero external native dependencies using Dart standard OpenXML/Archive + XML.
class BomExcelParser {
  BomExcelParser._();

  /// Parses an uploaded file (either .xlsx binary or .csv bytes) and associates it with [productId].
  static ParsedBomResult parseBytes({
    required Uint8List bytes,
    required String fileName,
    required String productId,
    required String productCode,
    required String productName,
    required String uploadedByUid,
    required String uploadedByName,
  }) {
    List<List<String>> grid = [];

    // 1. Check if the file is an OpenXML ZIP container (starts with PK\x03\x04)
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      grid = _parseXlsxArchive(bytes);
    } else {
      // 2. Fallback to standard RFC 4180 / CSV text decoding
      grid = _parseCsvBytes(bytes);
    }

    return _extractBomFromGrid(
      grid: grid,
      fileName: fileName,
      productId: productId,
      productCode: productCode,
      productName: productName,
      uploadedByUid: uploadedByUid,
      uploadedByName: uploadedByName,
    );
  }

  /// Parses raw CSV string directly.
  static ParsedBomResult parseCsvString({
    required String csvString,
    required String fileName,
    required String productId,
    required String productCode,
    required String productName,
    required String uploadedByUid,
    required String uploadedByName,
  }) {
    final grid = _parseCsvLines(csvString);
    return _extractBomFromGrid(
      grid: grid,
      fileName: fileName,
      productId: productId,
      productCode: productCode,
      productName: productName,
      uploadedByUid: uploadedByUid,
      uploadedByName: uploadedByName,
    );
  }

  /// Decodes OpenXML .xlsx archive extracting shared strings and worksheet cells.
  static List<List<String>> _parseXlsxArchive(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract shared strings
      final sharedStrings = <String>[];
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml') ??
          archive.findFile('xl/SharedStrings.xml');

      if (sharedStringsFile != null) {
        final xmlDoc = XmlDocument.parse(utf8.decode(sharedStringsFile.content as List<int>));
        for (final si in xmlDoc.findAllElements('si')) {
          final tNodes = si.findAllElements('t');
          final text = tNodes.map((n) => n.innerText).join('');
          sharedStrings.add(text);
        }
      }

      // Parse all worksheet XML files and append their rows
      final sheetFiles = archive.where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')).toList();
      sheetFiles.sort((a, b) => a.name.compareTo(b.name));

      if (sheetFiles.isEmpty) {
        return [];
      }

      final List<List<String>> combinedGrid = [];

      for (final sheetFile in sheetFiles) {
        final sheetXml = XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
        final rowsMap = <int, Map<int, String>>{};
        int maxCol = 0;

        for (final rowElem in sheetXml.findAllElements('row')) {
          final rAttr = rowElem.getAttribute('r');
          int rowIdx = rAttr != null ? (int.tryParse(rAttr) ?? 1) - 1 : rowsMap.length;

          rowsMap.putIfAbsent(rowIdx, () => {});

          for (final cElem in rowElem.findAllElements('c')) {
            final rRef = cElem.getAttribute('r') ?? '';
            final tType = cElem.getAttribute('t');
            final vElem = cElem.findElements('v').firstOrNull;
            final rawVal = vElem?.innerText ?? '';

            int colIdx = _colLetterToIndex(rRef);
            if (colIdx > maxCol) maxCol = colIdx;

            String cellText = '';
            if (tType == 's') {
              final sIdx = int.tryParse(rawVal);
              if (sIdx != null && sIdx >= 0 && sIdx < sharedStrings.length) {
                cellText = sharedStrings[sIdx];
              }
            } else if (tType == 'inlineStr') {
              cellText = cElem.findAllElements('t').map((n) => n.innerText).join('');
            } else {
              cellText = rawVal;
            }

            rowsMap[rowIdx]![colIdx] = cellText;
          }
        }

        final sortedRowKeys = rowsMap.keys.toList()..sort();
        if (sortedRowKeys.isNotEmpty) {
          final totalRows = sortedRowKeys.last + 1;
          final totalCols = maxCol + 1;

          for (int r = 0; r < totalRows; r++) {
            final row = List<String>.filled(totalCols, '');
            if (rowsMap.containsKey(r)) {
              rowsMap[r]!.forEach((col, val) {
                if (col < totalCols) row[col] = val.trim();
              });
            }
            combinedGrid.add(row);
          }
        }
      }

      return combinedGrid;
    } catch (_) {
      return [];
    }
  }

  static int _colLetterToIndex(String cellRef) {
    final colChars = cellRef.replaceAll(RegExp(r'[0-9]'), '').toUpperCase();
    if (colChars.isEmpty) return 0;
    int col = 0;
    for (int i = 0; i < colChars.length; i++) {
      col = col * 26 + (colChars.codeUnitAt(i) - 64);
    }
    return (col - 1).clamp(0, 500);
  }

  static List<List<String>> _parseCsvBytes(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    return _parseCsvLines(content);
  }

  static List<List<String>> _parseCsvLines(String content) {
    final List<List<String>> rows = [];
    final lines = LineSplitter.split(content).toList();

    for (final line in lines) {
      final cells = <String>[];
      final buffer = StringBuffer();
      bool inQuotes = false;

      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (char == ',' && !inQuotes) {
          cells.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      cells.add(buffer.toString().trim());
      rows.add(cells);
    }

    return rows;
  }

  /// Core extraction logic operating on a uniform 2D grid of strings.
  static ParsedBomResult _extractBomFromGrid({
    required List<List<String>> grid,
    required String fileName,
    required String productId,
    required String productCode,
    required String productName,
    required String uploadedByUid,
    required String uploadedByName,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (grid.isEmpty) {
      errors.add('The uploaded workbook contains no readable data.');
      return ParsedBomResult(
        bom: ProductBomModel(
          id: 'BOM_${productId}_v1',
          productId: productId,
          productCode: productCode,
          productName: productName,
        ),
        errors: errors,
      );
    }

    // 1. Extract Product Header Information
    String partNoExtracted = '';
    String partNameExtracted = '';
    String toolNo = '';
    String toolName = '';
    String designedBy = '';
    String dateExtracted = '';
    String customer = '';
    String project = '';
    String materialSheet = '';
    String materialThickness = '';

    String? findValueInRow(List<String> row, int matchColIdx) {
      for (int c = matchColIdx + 1; c < row.length; c++) {
        final val = row[c].trim();
        if (val.isNotEmpty && !val.contains(':') && val != 'TOOL NO' && val != 'TOOL NAME' && val != 'CUSTOMER') {
          return val;
        }
      }
      return null;
    }

    int headerRowIdx = -1;

    for (int r = 0; r < grid.length && r < 15; r++) {
      final row = grid[r];
      for (int c = 0; c < row.length; c++) {
        final cell = row[c].trim().toUpperCase();

        if (cell.startsWith('PART NO') || cell.contains('PART NO / REV')) {
          partNoExtracted = findValueInRow(row, c) ?? partNoExtracted;
        } else if (cell.startsWith('PART NAME')) {
          partNameExtracted = findValueInRow(row, c) ?? partNameExtracted;
        } else if (cell.startsWith('TOOL NAME')) {
          toolName = findValueInRow(row, c) ?? toolName;
        } else if (cell == 'TOOL NO' || cell.startsWith('TOOL NO:')) {
          toolNo = findValueInRow(row, c) ?? toolNo;
        } else if (cell.startsWith('DESIGNED BY')) {
          designedBy = findValueInRow(row, c) ?? designedBy;
        } else if (cell.startsWith('DATE')) {
          dateExtracted = findValueInRow(row, c) ?? dateExtracted;
        } else if (cell.startsWith('CUSTOMER')) {
          customer = findValueInRow(row, c) ?? customer;
        } else if (cell.startsWith('PROJECT')) {
          project = findValueInRow(row, c) ?? project;
        } else if (cell.startsWith('MATERIAL (SHEET)')) {
          materialSheet = findValueInRow(row, c) ?? materialSheet;
        } else if (cell.startsWith('MATERIAL THICKNESS')) {
          materialThickness = findValueInRow(row, c) ?? materialThickness;
        } else if (cell == 'DET NO.' || cell == 'DET NO' || cell == 'DET. NO.' || cell == 'DETAIL NO') {
          headerRowIdx = r;
        }
      }
    }

    // 2. Validate extracted product identity against selected product
    if (partNoExtracted.isNotEmpty && productCode.isNotEmpty) {
      final cleanExtracted = partNoExtracted.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final cleanTarget = productCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      if (!cleanTarget.contains(cleanExtracted) && !cleanExtracted.contains(cleanTarget)) {
        warnings.add(
          'Extracted Part Number ($partNoExtracted) does not strictly match selected Product Code ($productCode).',
        );
      }
    }

    if (partNameExtracted.isNotEmpty && productName.isNotEmpty) {
      final cleanExtracted = partNameExtracted.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final cleanTarget = productName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      if (!cleanTarget.contains(cleanExtracted) && !cleanExtracted.contains(cleanTarget)) {
        warnings.add(
          'Extracted Part Name ($partNameExtracted) differs from selected Product Name ($productName).',
        );
      }
    }

    if (headerRowIdx == -1) {
      // Fallback search anywhere in the first 25 rows
      for (int r = 0; r < grid.length && r < 25; r++) {
        final row = grid[r];
        for (final cell in row) {
          final norm = cell.trim().toUpperCase();
          if (norm.contains('DET NO') || norm.contains('NAME OF PART')) {
            headerRowIdx = r;
            break;
          }
        }
        if (headerRowIdx != -1) break;
      }
    }

    if (headerRowIdx == -1) {
      errors.add('Could not locate the main component table header ("Det No.", "Name of Part").');
      return ParsedBomResult(
        bom: ProductBomModel(
          id: 'BOM_${productId}_v1',
          productId: productId,
          productCode: productCode,
          productName: productName,
          partNoExtracted: partNoExtracted,
          partNameExtracted: partNameExtracted,
          toolName: toolName,
        ),
        errors: errors,
        warnings: warnings,
      );
    }

    // 3. Map Columns
    final headerRow = grid[headerRowIdx];
    int colDetNo = 0;
    int colName = 1;
    int colQty = 2;
    int colMaterial = 3;
    int colFinishH = 4;
    int colFinishW = 5;
    int colFinishL = 6;
    int colRowH = 8;
    int colRowW = 9;
    int colRowL = 10;
    int colVendor = 11;
    int colMaterialIn = 12;
    int colMilling = 13;
    int colJigBoring = 14;
    int colVmc = 15;
    int colWireCut = 16;
    int colHardening = 17;
    int colAssly = 18;

    for (int c = 0; c < headerRow.length; c++) {
      final text = headerRow[c].trim().toUpperCase();
      if (text.contains('DET NO')) colDetNo = c;
      if (text.contains('NAME OF PART') || text == 'PART NAME') colName = c;
      if (text == 'QTY' || text.contains('QTY.')) colQty = c;
      if (text == 'MATERIAL') colMaterial = c;
      if (text.contains('MATERIAL VENDOR') || text == 'VENDOR') colVendor = c;
      if (text.contains('MATERIAL IN')) colMaterialIn = c;
      if (text.contains('MILLING')) colMilling = c;
      if (text.contains('JIG BORING')) colJigBoring = c;
      if (text.contains('VMC')) colVmc = c;
      if (text.contains('WIRE CUT') || text == 'W/C') colWireCut = c;
      if (text.contains('HARDENING')) colHardening = c;
      if (text.contains('ASSLY') || text.contains('ASSEMBLY')) colAssly = c;
    }

    // 4. Parse Rows (Main Components & Standard Items)
    final mainComponents = <BomComponentItem>[];
    final standardItems = <BomStandardItem>[];
    String currentSection = 'GENERAL';
    bool inStandardBom = false;

    // Track standard list header indices
    int stdColDetNo = 0;
    int stdColName = 1;
    int stdColVendor = 3;
    int stdColPartCode = 5;
    int stdColQty = 7;

    String getCell(List<String> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].trim();
    }

    final startRow = headerRowIdx + 1;

    for (int r = startRow; r < grid.length; r++) {
      final row = grid[r];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      final joinedRow = row.map((c) => c.trim().toUpperCase()).join(' ');

      // Check for Standard BOM List transition
      if (joinedRow.contains('STD BOM LIST') || joinedRow.contains('STANDARD BOM')) {
        inStandardBom = true;
        continue;
      }

      if (inStandardBom) {
        // Check for Standard BOM sub-header
        if (joinedRow.contains('NAME OF PART') && (joinedRow.contains('PART CODE') || joinedRow.contains('QTY'))) {
          for (int c = 0; c < row.length; c++) {
            final t = row[c].trim().toUpperCase();
            if (t.contains('DET NO')) stdColDetNo = c;
            if (t.contains('NAME OF PART')) stdColName = c;
            if (t.contains('VENDOR') || t.contains('SUPPLIER')) stdColVendor = c;
            if (t.contains('PART CODE')) stdColPartCode = c;
            if (t.contains('QTY')) stdColQty = c;
          }
          continue;
        }

        // Standard BOM item extraction
        final detNo = getCell(row, stdColDetNo);
        String nameOfPart = getCell(row, stdColName);

        // Fallback: look in adjacent columns if name column was merged
        if (nameOfPart.isEmpty && stdColName + 1 < row.length) {
          nameOfPart = getCell(row, stdColName + 1);
        }

        if (nameOfPart.isEmpty) continue;

        // Skip non-item separator text
        if (nameOfPart.toUpperCase().contains('NAME OF PART') ||
            nameOfPart.toUpperCase().contains('STD BOM') ||
            nameOfPart.toUpperCase().contains('STANDARD BOM') ||
            nameOfPart.toUpperCase().contains('PRODUCT CODE') ||
            nameOfPart.toUpperCase().contains('BOM VERSION')) {
          continue;
        }

        String vendor = getCell(row, stdColVendor);
        String partCode = getCell(row, stdColPartCode);
        String qtyStr = getCell(row, stdColQty);

        // If partCode is empty, search row for part code pattern
        if (partCode.isEmpty) {
          for (int c = 2; c < row.length; c++) {
            final val = row[c].trim();
            if (val.isNotEmpty && val != nameOfPart && val != vendor && int.tryParse(val) == null) {
              if (vendor.isEmpty && (val.equalsIgnoreCase('Misumi') || val.length < 8)) {
                vendor = val;
              } else {
                partCode = val;
              }
            }
          }
        }

        // If qty is empty, search for numeric value
        int qty = int.tryParse(qtyStr) ?? 0;
        if (qty == 0) {
          for (int c = row.length - 1; c >= 2; c--) {
            final parsed = int.tryParse(row[c].trim());
            if (parsed != null && parsed > 0) {
              qty = parsed;
              break;
            }
          }
        }
        if (qty == 0) qty = 1;

        standardItems.add(
          BomStandardItem(
            id: 'STD_${productId}_${standardItems.length + 1}',
            detNo: detNo.isNotEmpty ? detNo : '${standardItems.length + 37}',
            nameOfPart: nameOfPart,
            vendor: vendor.isNotEmpty ? vendor : 'Standard Supplier',
            partCode: partCode,
            qty: qty,
          ),
        );
        continue;
      }

      // --- Main Component Parsing ---
      final detNo = getCell(row, colDetNo);
      final nameOfPart = getCell(row, colName);

      // Section header detection:
      // If detNo is empty or not a number, and qty is empty, but column 1 has text, it's a section header!
      if (detNo.isEmpty || int.tryParse(detNo) == null) {
        final text1 = getCell(row, 1);
        final text0 = getCell(row, 0);
        final candidate = text1.isNotEmpty ? text1 : text0;

        if (candidate.isNotEmpty &&
            !candidate.toUpperCase().contains('FINISH SIZE') &&
            !candidate.toUpperCase().contains('ROW SIZE') &&
            !candidate.toUpperCase().contains('DET NO') &&
            !candidate.toUpperCase().contains('NAME OF PART')) {
          currentSection = candidate.replaceAll(RegExp(r'^,\s*'), '').trim();
          continue;
        }
      }

      // Skip sub-headers like "H, W, L"
      if (nameOfPart.isEmpty || nameOfPart.toUpperCase() == 'NAME OF PART' || nameOfPart == 'H' || nameOfPart == 'W') {
        continue;
      }

      // Parse quantity
      int qty = int.tryParse(getCell(row, colQty)) ?? 1;
      if (qty <= 0) qty = 1;

      final material = getCell(row, colMaterial);
      final finishH = getCell(row, colFinishH);
      final finishW = getCell(row, colFinishW);
      final finishL = getCell(row, colFinishL);
      final rowH = getCell(row, colRowH);
      final rowW = getCell(row, colRowW);
      final rowL = getCell(row, colRowL);
      final vendor = getCell(row, colVendor);
      final materialIn = getCell(row, colMaterialIn);
      final milling = getCell(row, colMilling);
      final jigBoring = getCell(row, colJigBoring);
      final vmc = getCell(row, colVmc);
      final wireCut = getCell(row, colWireCut);
      final hardening = getCell(row, colHardening);
      final assly = getCell(row, colAssly);

      mainComponents.add(
        BomComponentItem(
          id: 'CMP_${productId}_${mainComponents.length + 1}',
          detNo: detNo.isNotEmpty ? detNo : '${mainComponents.length + 1}',
          nameOfPart: nameOfPart,
          sectionName: currentSection,
          qty: qty,
          material: material,
          finishHeight: finishH,
          finishWidth: finishW,
          finishLength: finishL,
          rowHeight: rowH,
          rowWidth: rowW,
          rowLength: rowL,
          materialVendor: vendor,
          materialIn: materialIn,
          millingGrinding: milling,
          jigBoring: jigBoring,
          vmc: vmc,
          wireCut: wireCut,
          hardening: hardening,
          assly: assly,
        ),
      );
    }

    if (mainComponents.isEmpty && standardItems.isEmpty) {
      errors.add('No valid BOM component records or standard items were extracted.');
    }

    final bom = ProductBomModel(
      id: 'BOM_${productId}_v1',
      productId: productId,
      productCode: productCode,
      productName: productName,
      partNoExtracted: partNoExtracted,
      partNameExtracted: partNameExtracted,
      toolNo: toolNo,
      toolName: toolName,
      designedBy: designedBy,
      date: dateExtracted,
      customer: customer,
      project: project,
      materialSheet: materialSheet,
      materialThickness: materialThickness,
      revision: 'Rev 1',
      version: 1,
      uploadedFileName: fileName,
      uploadedByUid: uploadedByUid,
      uploadedByName: uploadedByName,
      uploadedAt: DateTime.now(),
      mainComponents: mainComponents,
      standardItems: standardItems,
    );

    return ParsedBomResult(
      bom: bom,
      errors: errors,
      warnings: warnings,
      totalRowsParsed: grid.length,
    );
  }
}

extension _StringExt on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
