import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/billing/data/models/company_billing_config_model.dart';
import 'package:unity/features/billing/data/models/customer_billing_model.dart';
import 'package:unity/features/billing/data/models/invoice_item_model.dart';
import 'package:unity/features/billing/data/models/invoice_model.dart';
import 'package:unity/features/billing/data/models/invoice_payment_model.dart';
import 'package:unity/features/billing/data/services/indian_currency_formatter.dart';
import 'package:unity/features/billing/data/services/invoice_number_service.dart';

void main() {
  group('IndianCurrencyFormatter Tests', () {
    test('Formats currency in Indian numbering system', () {
      expect(IndianCurrencyFormatter.format(0), '₹ 0.00');
      expect(IndianCurrencyFormatter.format(100), '₹ 100.00');
      expect(IndianCurrencyFormatter.format(1000), '₹ 1,000.00');
      expect(IndianCurrencyFormatter.format(33344), '₹ 33,344.00');
      expect(IndianCurrencyFormatter.format(39345.92), '₹ 39,345.92');
      expect(IndianCurrencyFormatter.format(100000), '₹ 1,00,000.00');
      expect(IndianCurrencyFormatter.format(1234567.89), '₹ 12,34,567.89');
    });

    test('Converts amounts into Indian currency words', () {
      final words1 = IndianCurrencyFormatter.convertToWords(39345.92);
      expect(words1, 'INR Thirty Nine Thousand Three Hundred Forty Five and Ninety Two Paise Only');

      final words2 = IndianCurrencyFormatter.convertToWords(1000);
      expect(words2, 'INR One Thousand Only');

      final words3 = IndianCurrencyFormatter.convertToWords(150000);
      expect(words3, 'INR One Lakh Fifty Thousand Only');

      final wordsZero = IndianCurrencyFormatter.convertToWords(0);
      expect(wordsZero, 'INR Zero Only');
    });
  });

  group('Invoice Number & FY Tests', () {
    test('Calculates financial year correctly for different dates', () {
      final nov2026 = DateTime(2026, 11, 20);
      expect(InvoiceNumberService.getFinancialYear(nov2026), '2026-27');

      final apr2026 = DateTime(2026, 4, 1);
      expect(InvoiceNumberService.getFinancialYear(apr2026), '2026-27');

      final mar2027 = DateTime(2027, 3, 31);
      expect(InvoiceNumberService.getFinancialYear(mar2027), '2026-27');

      final apr2027 = DateTime(2027, 4, 1);
      expect(InvoiceNumberService.getFinancialYear(apr2027), '2027-28');
    });
  });

  group('Tax Calculation Tests', () {
    test('Intra-state calculation applies CGST and SGST correctly', () {
      // Example from prompt:
      // Taxable: 33,344
      // CGST @ 9% = 3,000.96
      // SGST @ 9% = 3,000.96
      // Total GST = 6,001.92
      // Total = 39,345.92
      final item = InvoiceItemModel.calculate(
        description: 'CNC Machine Parts',
        hsnSac: '8466',
        quantity: 1,
        unit: 'PCS',
        rate: 33344,
        discountPercent: 0,
        gstRate: 18,
        isIntraState: true,
      );

      expect(item.grossAmount, 33344.0);
      expect(item.taxableAmount, 33344.0);
      expect(item.cgstRate, 9.0);
      expect(item.sgstRate, 9.0);
      expect(item.igstRate, 0.0);
      expect(double.parse(item.cgstAmount.toStringAsFixed(2)), 3000.96);
      expect(double.parse(item.sgstAmount.toStringAsFixed(2)), 3000.96);
      expect(item.igstAmount, 0.0);
      expect(double.parse(item.totalAmount.toStringAsFixed(2)), 39345.92);
    });

    test('Inter-state calculation applies IGST correctly without CGST/SGST', () {
      final item = InvoiceItemModel.calculate(
        description: 'Injection Mould Tool',
        hsnSac: '8480',
        quantity: 2,
        rate: 20000,
        discountPercent: 10, // 40,000 - 4,000 = 36,000 taxable
        gstRate: 18,
        isIntraState: false,
      );

      expect(item.grossAmount, 40000.0);
      expect(item.discountAmount, 4000.0);
      expect(item.taxableAmount, 36000.0);
      expect(item.cgstAmount, 0.0);
      expect(item.sgstAmount, 0.0);
      expect(item.igstRate, 18.0);
      expect(item.igstAmount, 6480.0);
      expect(item.totalAmount, 42480.0);
    });
  });

  group('Model Serialization Tests', () {
    test('CompanyBillingConfigModel default config is complete', () {
      final config = CompanyBillingConfigModel.defaultConfig();
      expect(config.companyName, 'Unity Technologies');
      expect(config.stateCode, '27');
      expect(config.gstin, '27AXEPD7534P1Z1');
      expect(config.pan, 'AXEPD7534P');

      final map = config.toMap();
      final revived = CompanyBillingConfigModel.fromMap(map);
      expect(revived.companyName, config.companyName);
      expect(revived.bankName, config.bankName);
      expect(revived.ifscCode, config.ifscCode);
    });

    test('CustomerBillingModel serializes and deserializes', () {
      final customer = CustomerBillingModel(
        id: 'cust-123',
        customerName: 'Bajaj Auto Ltd',
        billingAddress: 'Waluj MIDC, Aurangabad',
        gstin: '27AAACB0000A1Z1',
        stateName: 'Maharashtra',
        stateCode: '27',
        placeOfSupply: 'Maharashtra',
        email: 'billing@bajajauto.co.in',
      );

      final map = customer.toMap();
      final revived = CustomerBillingModel.fromMap(map, 'cust-123');
      expect(revived.id, 'cust-123');
      expect(revived.customerName, 'Bajaj Auto Ltd');
      expect(revived.stateCode, '27');
    });

    test('InvoicePaymentModel serializes and deserializes', () {
      final payment = InvoicePaymentModel(
        id: 'pay-1',
        invoiceId: 'inv-1',
        amount: 25000.0,
        paymentDate: DateTime(2026, 11, 20),
        paymentMethod: 'NEFT / RTGS',
        transactionReference: 'UTR123456789',
        recordedBy: 'admin-1',
      );

      final map = payment.toMap();
      final revived = InvoicePaymentModel.fromMap(map, 'pay-1');
      expect(revived.id, 'pay-1');
      expect(revived.amount, 25000.0);
      expect(revived.paymentMethod, 'NEFT / RTGS');
      expect(revived.transactionReference, 'UTR123456789');
    });

    test('InvoiceModel serializes and deserializes with historical snapshot', () {
      final invoice = InvoiceModel(
        id: 'inv-001',
        invoiceNumber: 'UT/2026-27/0104',
        financialYear: '2026-27',
        companySnapshot: CompanyBillingConfigModel.defaultConfig(),
        customerSnapshot: CustomerBillingModel(
          id: 'cust-1',
          customerName: 'Tata Motors Ltd',
          billingAddress: 'Pune',
          gstin: '27AAACT0000T1Z1',
          stateName: 'Maharashtra',
          stateCode: '27',
          placeOfSupply: 'Maharashtra',
        ),
        invoiceDate: DateTime(2026, 11, 20),
        items: [
          InvoiceItemModel(
            description: 'Stamping Die',
            hsnSac: '8466',
            quantity: 1,
            unit: 'PCS',
            rate: 50000,
            discountPercent: 0,
            discountAmount: 0,
            taxableAmount: 50000,
            gstRate: 18,
            cgstRate: 9,
            cgstAmount: 4500,
            sgstRate: 9,
            sgstAmount: 4500,
            igstRate: 0,
            igstAmount: 0,
            totalAmount: 59000,
          ),
        ],
        totalQuantity: 1,
        taxableAmount: 50000,
        cgstAmount: 4500,
        sgstAmount: 4500,
        igstAmount: 0,
        totalTax: 9000,
        grandTotal: 59000,
        amountInWords: 'INR Fifty Nine Thousand Only',
        taxAmountInWords: 'INR Nine Thousand Only',
        paymentStatus: InvoicePaymentStatus.pending,
        totalPaid: 0,
        outstandingAmount: 59000,
        invoiceStatus: InvoiceRecordStatus.issued,
      );

      final map = invoice.toMap();
      final revived = InvoiceModel.fromMap(map, 'inv-001');
      expect(revived.id, 'inv-001');
      expect(revived.invoiceNumber, 'UT/2026-27/0104');
      expect(revived.companySnapshot.companyName, 'Unity Technologies');
      expect(revived.customerSnapshot.customerName, 'Tata Motors Ltd');
      expect(revived.items.length, 1);
      expect(revived.grandTotal, 59000.0);
      expect(revived.paymentStatusEnum, InvoicePaymentStatus.pending);
      expect(revived.invoiceStatus, InvoiceRecordStatus.issued);
    });
  });
}
