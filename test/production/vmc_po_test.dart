import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/production/data/models/jobwork_po_model.dart';
import 'package:unity/features/production/data/services/jobwork_po_excel_service.dart';
import 'package:unity/features/production/data/services/jobwork_po_pdf_service.dart';

void main() {
  group('VMC Purchase Order (PO) Tests', () {
    final vmcItems = [
      const JobworkPoItemModel(
        srNo: 1,
        bomComponentId: 'comp_1',
        description: 'UT-3001 UPPER PLATE',
        hsnCode: '998898',
        nos: 6,
        rate: 700.0,
        per: 'NOS',
        total: 4200.0,
      ),
      const JobworkPoItemModel(
        srNo: 2,
        bomComponentId: 'comp_2',
        description: 'UT-2996 LOWER PLATE 2D',
        hsnCode: '998898',
        nos: 15,
        rate: 700.0,
        per: 'NOS',
        total: 10500.0,
      ),
      const JobworkPoItemModel(
        srNo: 3,
        bomComponentId: 'comp_3',
        description: 'UT-2994 LOWER PLATE 2D',
        hsnCode: '998898',
        nos: 17,
        rate: 700.0,
        per: 'NOS',
        total: 11900.0,
      ),
    ];

    final vmcPo = JobworkPoModel(
      id: 'po_vmc_test_001',
      poNumber: '011/2026-27',
      orderId: 'wo_861853',
      orderNumber: 'WO-861853',
      productName: 'AH141225',
      processId: 'ncut_9',
      poType: 'VMC',
      date: DateTime(2026, 11, 23),
      deliveryNote: 'Urgent',
      suppliersRef: 'UT-3001',
      otherReference: 'VMC-REF-01',
      paymentTerms: 'PAYMENT = 90 DAYS',
      dispatchedThrough: 'By Road',
      destination: 'Pune Maharashtra 411062',
      cityPortLoading: 'Waluj MIDC',
      cityPortDischarge: 'Talwade Pune',
      vendorName: 'S.S Engineering',
      vendorAddress: 'Gat No.50, Dehu-Alandi Road, Talwade, Pune Maharashtra 411062, India.',
      vendorGstin: '27AJKPI1882P1ZJ',
      companyName: 'UNITY TECHNOLOGIES',
      companyAddress: 'E-70/14, MIDC WALUJ, AURANGABAD 431136.',
      companyGstin: '27AXEPD7534P1Z1',
      companyEmail: 'unitytech17@gmail.com',
      items: vmcItems,
      subTotal: 26600.0,
      taxRate: 18.0,
      cgstAmount: 2394.0,
      sgstAmount: 2394.0,
      grandTotal: 31388.0,
    );

    test('JobworkPoModel recognizes VMC type and calculates totals', () {
      expect(vmcPo.isVmc, isTrue);
      expect(vmcPo.poType, equals('VMC'));
      expect(vmcPo.totalNos, equals(38));
      expect(vmcPo.subTotal, equals(26600.0));
      expect(vmcPo.vendorName, equals('S.S Engineering'));
      expect(vmcPo.vendorGstin, equals('27AJKPI1882P1ZJ'));
      expect(vmcPo.items.first.description, equals('UT-3001 UPPER PLATE'));
      expect(vmcPo.items.first.hsnCode, equals('998898'));
      expect(vmcPo.items.first.per, equals('NOS'));
    });

    test('JobworkPoModel serializes and deserializes accurately', () {
      final map = vmcPo.toMap();
      expect(map['poType'], equals('VMC'));
      expect(map['poNumber'], equals('011/2026-27'));
      expect(map['vendorName'], equals('S.S Engineering'));
      expect(map['vendorGstin'], equals('27AJKPI1882P1ZJ'));

      final itemsMap = map['items'] as List;
      expect(itemsMap.length, equals(3));
      expect(itemsMap.first['hsnCode'], equals('998898'));
      expect(itemsMap.first['per'], equals('NOS'));

      final reconstructed = JobworkPoModel.fromMap(map, vmcPo.id);
      expect(reconstructed.id, equals(vmcPo.id));
      expect(reconstructed.isVmc, isTrue);
      expect(reconstructed.poNumber, equals('011/2026-27'));
      expect(reconstructed.items.length, equals(3));
      expect(reconstructed.items.first.description, equals('UT-3001 UPPER PLATE'));
      expect(reconstructed.items.first.hsnCode, equals('998898'));
      expect(reconstructed.items.first.per, equals('NOS'));
      expect(reconstructed.items.first.rate, equals(700.0));
    });

    test('JobworkPoPdfService generates valid PDF document for VMC', () async {
      final pdfBytes = await JobworkPoPdfService.generatePdf(vmcPo);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      // PDF header check (%PDF-)
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('JobworkPoExcelService generates valid XLSX archive for VMC with proper sheet & rows', () {
      final xlsxBytes = JobworkPoExcelService.generateXlsx(vmcPo);
      expect(xlsxBytes, isNotEmpty);
      expect(xlsxBytes.length, greaterThan(500));

      final archive = ZipDecoder().decodeBytes(xlsxBytes);
      final fileNames = archive.files.map((f) => f.name).toList();

      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('xl/workbook.xml'));
      expect(fileNames, contains('xl/worksheets/sheet1.xml'));
      expect(fileNames, contains('xl/sharedStrings.xml'));

      // Check workbook contains sheet name "PURCHASE ORDER"
      final wbFile = archive.findFile('xl/workbook.xml')!;
      final wbXml = utf8.decode(wbFile.content as List<int>);
      expect(wbXml, contains('PURCHASE ORDER'));

      // Check sharedStrings contains VMC components and vendor
      final ssFile = archive.findFile('xl/sharedStrings.xml')!;
      final ssXml = utf8.decode(ssFile.content as List<int>);
      expect(ssXml, contains('S.S Engineering'));
      expect(ssXml, contains('UT-3001 UPPER PLATE'));
      expect(ssXml, contains('998898'));
      expect(ssXml, contains('Description of Goods'));
    });
  });
}
