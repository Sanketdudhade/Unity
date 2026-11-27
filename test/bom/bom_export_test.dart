import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/bom/data/services/bom_excel_parser.dart';
import 'package:unity/features/bom/data/services/bom_export_service.dart';
import 'package:unity/features/products/data/models/product_model.dart';

void main() {
  group('BomExportService Tests', () {
    test('Correctly exports BOM to Excel (.xlsx) and CSV (.csv)', () {
      final file = File('test/fixtures/sample_bom.csv');
      final csvContent = file.readAsStringSync();
      final parsed = BomExcelParser.parseCsvString(
        csvString: csvContent,
        fileName: 'sample_bom.csv',
        productId: 'prod_408201',
        productCode: '408201',
        productName: 'PATCH PLATE',
        uploadedByUid: 'admin_test',
        uploadedByName: 'Sanket Dudhade',
      );

      final product = ProductModel(
        id: 'prod_408201',
        partCode: '408201',
        name: 'PATCH PLATE',
        description: 'Automotive Patch Plate',
        unit: 'PCS',
        revision: 'Rev A',
        customerReference: 'RTPL',
        drawingNumber: 'DWG-408201',
        isActive: true,
      );

      // 1. Test CSV Generation
      final csvBytes = BomExportService.generateBomCsv(
        product: product,
        bom: parsed.bom,
      );

      expect(csvBytes.isNotEmpty, isTrue);
      // Starts with UTF-8 BOM EF BB BF
      expect(csvBytes[0], equals(0xEF));
      expect(csvBytes[1], equals(0xBB));
      expect(csvBytes[2], equals(0xBF));

      final csvStr = String.fromCharCodes(csvBytes.skip(3));
      expect(csvStr.contains('BILL OF MATERIAL'), isTrue);
      expect(csvStr.contains('PATCH PLATE'), isTrue);
      expect(csvStr.contains('MAIN COMPONENTS / MACHINED PARTS'), isTrue);
      expect(csvStr.contains('STD BOM LIST / OFF-THE-SHELF PARTS'), isTrue);
      expect(csvStr.contains('LOWER CASTING'), isTrue);
      expect(csvStr.contains('Misumi'), isTrue);

      // 2. Test Excel (.xlsx) Generation
      final xlsxBytes = BomExportService.generateBomXlsx(
        product: product,
        bom: parsed.bom,
      );

      expect(xlsxBytes.isNotEmpty, isTrue);
      // Valid ZIP archive starts with PK\x03\x04
      expect(xlsxBytes[0], equals(0x50));
      expect(xlsxBytes[1], equals(0x4B));
      expect(xlsxBytes[2], equals(0x03));
      expect(xlsxBytes[3], equals(0x04));

      // Re-parse the generated xlsx file using our own parser to ensure round-trip integrity!
      final reParsed = BomExcelParser.parseBytes(
        bytes: xlsxBytes,
        fileName: 'export_test.xlsx',
        productId: product.id,
        productCode: product.partCode,
        productName: product.name,
        uploadedByUid: 'admin',
        uploadedByName: 'Admin',
      );

      expect(reParsed.isValid, isTrue, reason: 'Re-parsing generated XLSX failed: ${reParsed.errors}');
      expect(reParsed.bom.mainComponents.length, equals(parsed.bom.mainComponents.length));
      expect(reParsed.bom.standardItems.length, equals(parsed.bom.standardItems.length));
    });
  });
}
