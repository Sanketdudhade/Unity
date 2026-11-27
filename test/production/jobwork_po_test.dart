import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/production/data/models/jobwork_po_model.dart';
import 'package:unity/features/production/data/services/jobwork_po_excel_service.dart';
import 'package:unity/features/production/data/services/jobwork_po_pdf_service.dart';

void main() {
  group('Jobwork PO Tests', () {
    test('JobworkPoModel serializes and calculates totals properly', () {
      final items = [
        const JobworkPoItemModel(
          srNo: 1,
          description: 'Top Plate',
          thk: '36',
          width: '60',
          length: '120',
          grade: 'MS',
          nos: 4,
          milling: 21.6,
          grinding: 21.6,
          rate: 170.0,
          total: 680.0,
        ),
        const JobworkPoItemModel(
          srNo: 2,
          description: 'Die Insert',
          thk: '122',
          width: '78',
          length: '215',
          grade: 'D2IMP',
          nos: 1,
          milling: 67.08,
          grinding: 67.08,
          rate: 180.0,
          total: 180.0,
        ),
      ];

      final po = JobworkPoModel(
        id: 'po_test_01',
        poNumber: '345/2026-27',
        orderId: 'WO-861853',
        orderNumber: 'WO-861853',
        productName: 'AH141225',
        processId: 'proc_4',
        date: DateTime(2026, 10, 7),
        suppliersRef: 'UT-3077',
        paymentTerms: 'PAYMENT = 90 DAYS',
        vendorName: 'SANKET ENGINEERING',
        vendorAddress: 'Plot No B-15/2/41, Waluj MIDC, Aurangabad',
        vendorGstin: '27BAFPK2942H1ZQ',
        items: items,
        subTotal: 860.0,
        taxRate: 18.0,
        cgstAmount: 77.4,
        sgstAmount: 77.4,
        grandTotal: 1014.8,
      );

      expect(po.totalNos, 5);
      expect(po.subTotal, 860.0);
      expect(po.grandTotal, 1014.8);

      final map = po.toMap();
      expect(map['poNumber'], '345/2026-27');
      expect(map['vendorName'], 'SANKET ENGINEERING');
      expect(map['items'], isA<List>());
      expect((map['items'] as List).length, 2);

      final reconstructed = JobworkPoModel.fromMap(map, 'po_test_01');
      expect(reconstructed.id, 'po_test_01');
      expect(reconstructed.poNumber, '345/2026-27');
      expect(reconstructed.items.length, 2);
      expect(reconstructed.items[0].description, 'Top Plate');
      expect(reconstructed.items[1].grade, 'D2IMP');
      expect(reconstructed.totalNos, 5);
    });

    test('JobworkPoPdfService generates valid PDF bytes', () async {
      final po = JobworkPoModel(
        id: 'po_pdf_01',
        poNumber: '345/2026-27',
        orderId: 'WO-861853',
        orderNumber: 'WO-861853',
        productName: 'AH141225',
        processId: 'proc_4',
        date: DateTime(2026, 10, 7),
        suppliersRef: 'UT-3077',
        paymentTerms: 'PAYMENT = 90 DAYS',
        vendorName: 'SANKET ENGINEERING',
        vendorAddress: 'Plot No B-15/2/41, Waluj MIDC, Aurangabad',
        vendorGstin: '27BAFPK2942H1ZQ',
        items: const [
          JobworkPoItemModel(
            srNo: 1,
            description: 'Punch Plate',
            thk: '36',
            width: '60',
            length: '120',
            grade: 'MS',
            nos: 4,
            rate: 170.0,
            total: 680.0,
          ),
        ],
        subTotal: 680.0,
        taxRate: 18.0,
        cgstAmount: 61.2,
        sgstAmount: 61.2,
        grandTotal: 802.4,
      );

      final bytes = await JobworkPoPdfService.generatePdf(po);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('JobworkPoExcelService generates valid Excel .xlsx bytes', () {
      final po = JobworkPoModel(
        id: 'po_xlsx_01',
        poNumber: '345/2026-27',
        orderId: 'WO-861853',
        orderNumber: 'WO-861853',
        productName: 'AH141225',
        processId: 'proc_4',
        date: DateTime(2026, 10, 7),
        suppliersRef: 'UT-3077',
        paymentTerms: 'PAYMENT = 90 DAYS',
        vendorName: 'SANKET ENGINEERING',
        vendorAddress: 'Plot No B-15/2/41, Waluj MIDC, Aurangabad',
        vendorGstin: '27BAFPK2942H1ZQ',
        items: const [
          JobworkPoItemModel(
            srNo: 1,
            description: 'Punch Plate',
            thk: '36',
            width: '60',
            length: '120',
            grade: 'MS',
            nos: 4,
            rate: 170.0,
            total: 680.0,
          ),
        ],
        subTotal: 680.0,
        taxRate: 18.0,
        cgstAmount: 61.2,
        sgstAmount: 61.2,
        grandTotal: 802.4,
      );

      final bytes = JobworkPoExcelService.generateXlsx(po);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}
