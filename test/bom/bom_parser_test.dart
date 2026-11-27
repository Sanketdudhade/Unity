import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/bom/data/services/bom_excel_parser.dart';

void main() {
  group('BomExcelParser Tests', () {
    test('Correctly parses CSV sample BOM file with exact fields and sections', () {
      final file = File('test/fixtures/sample_bom.csv');
      expect(file.existsSync(), isTrue);

      final csvContent = file.readAsStringSync();
      final result = BomExcelParser.parseCsvString(
        csvString: csvContent,
        fileName: 'sample_bom.csv',
        productId: 'prod_test_001',
        productCode: '408201',
        productName: 'PATCH PLATE',
        uploadedByUid: 'admin_test',
        uploadedByName: 'Sanket Dudhade',
      );

      expect(result.isValid, isTrue, reason: 'Errors: ${result.errors}');
      final bom = result.bom;

      // 1. Verify Header extraction
      expect(bom.partNoExtracted, equals('408201'));
      expect(bom.partNameExtracted, equals('PATCH PLATE'));
      expect(bom.toolName, equals('TRIM DIE -2'));
      expect(bom.designedBy, equals('MALLINATH'));
      expect(bom.customer, equals('RTPL'));
      expect(bom.date, equals('2023-06-14'));
      expect(bom.materialThickness, equals('1.0 MM'));

      // 2. Verify Main Components count and extraction
      expect(bom.mainComponents.isNotEmpty, isTrue);
      final firstComp = bom.mainComponents.first;
      expect(firstComp.detNo, equals('1'));
      expect(firstComp.nameOfPart, equals('LOWER CASTING'));
      expect(firstComp.qty, equals(1));
      expect(firstComp.material, equals('FG300'));
      expect(firstComp.finishHeight, equals('175'));
      expect(firstComp.finishWidth, equals('750'));
      expect(firstComp.finishLength, equals('1100'));
      expect(firstComp.sectionName, contains('CASTING'));

      // Verify component with diameter Ø symbol
      final pieButton = bom.mainComponents.firstWhere((c) => c.nameOfPart.contains('PIE BUTTON'));
      expect(pieButton.finishHeight, contains('Ø'));
      expect(pieButton.material, equals('D2 IMP'));

      // Verify another component with row size
      final locator = bom.mainComponents.firstWhere((c) => c.nameOfPart == 'LOCATOR');
      expect(locator.qty, equals(1));
      expect(locator.material, equals('MS'));
      expect(locator.rowHeight, equals('65'));
      expect(locator.rowWidth, equals('185'));
      expect(locator.rowLength, equals('225'));

      // 3. Verify Standard BOM items
      expect(bom.standardItems.isNotEmpty, isTrue);
      expect(bom.standardItems.length, equals(11));

      final punch1 = bom.standardItems.firstWhere((s) => s.nameOfPart == 'PIE PUNCH-1');
      expect(punch1.vendor, equals('Misumi'));
      expect(punch1.partCode, equals('SPAL10-80-P8.14'));
      expect(punch1.qty, equals(2));

      final spring = bom.standardItems.firstWhere((s) => s.nameOfPart.contains('UPPER SPRING YELLOW'));
      expect(spring.qty, equals(11));
      expect(spring.partCode, equals('241.17.50.064'));
    });

    test('Correctly parses binary .xlsx sample BOM archive', () {
      final file = File('test/fixtures/TRIM DIE-2 546761408201 PATCH PLATE BOM.xlsx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final result = BomExcelParser.parseBytes(
        bytes: bytes,
        fileName: 'TRIM DIE-2 546761408201 PATCH PLATE BOM.xlsx',
        productId: 'prod_test_001',
        productCode: '408201',
        productName: 'PATCH PLATE',
        uploadedByUid: 'admin_test',
        uploadedByName: 'Sanket Dudhade',
      );

      expect(result.isValid, isTrue, reason: 'Errors: ${result.errors}');
      final bom = result.bom;

      expect(bom.partNoExtracted, equals('408201'));
      expect(bom.partNameExtracted, equals('PATCH PLATE'));
      expect(bom.toolName, equals('TRIM DIE -2'));
      expect(bom.mainComponents.length, anyOf(equals(22), equals(23)));
      expect(bom.standardItems.length, equals(11));
    });
  });
}
