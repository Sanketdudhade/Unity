import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/core/utils/formatters.dart';
import 'package:unity/features/inventory/data/models/material_model.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/data/models/stock_movement_model.dart';

void main() {
  group('Phase 4: MaterialModel & Integer Base Unit Scaling', () {
    test('MaterialModel parses valid map with decimal scale (KG, scale = 1000)', () {
      final now = DateTime(2026, 10, 15, 10, 0);
      final rawData = {
        'sku': 'MAT-SS-316L',
        'name': 'Stainless Steel 316L Sheet',
        'category': 'SHEET_METAL',
        'unit': 'KG',
        'unitScale': 1000,
        'minimumStock': 25000, // 25.000 KG
        'reorderQuantity': 50000, // 50.000 KG
        'defaultLocation': 'Warehouse A - Bay 04',
        'unitCost': 45000, // ₹450.00 in paise
        'notes': 'High corrosion resistance for marine enclosures',
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
      };

      final material = MaterialModel.fromMap('mat_101', rawData);

      expect(material.id, equals('mat_101'));
      expect(material.sku, equals('MAT-SS-316L'));
      expect(material.name, equals('Stainless Steel 316L Sheet'));
      expect(material.category, equals('SHEET_METAL'));
      expect(material.unit, equals('KG'));
      expect(material.unitScale, equals(1000));
      expect(material.minimumStock, equals(25000));
      expect(material.formattedMinimumStock, equals('25.000'));
      expect(material.formattedReorderQuantity, equals('50.000'));
      expect(material.unitCost, equals(45000));
      expect(material.isActive, isTrue);
      expect(material.createdAt, equals(now));
    });

    test('MaterialModel parses discrete unit items (PCS, scale = 1)', () {
      final rawData = {
        'sku': 'MAT-BOLT-M8',
        'name': 'Hex Bolt M8x25 Grade 8.8',
        'category': 'FASTENER',
        'unit': 'PCS',
        'unitScale': 1,
        'minimumStock': 100, // 100 pieces
        'reorderQuantity': 500,
      };

      final material = MaterialModel.fromMap('mat_102', rawData);

      expect(material.sku, equals('MAT-BOLT-M8'));
      expect(material.unit, equals('PCS'));
      expect(material.unitScale, equals(1));
      expect(material.minimumStock, equals(100));
      expect(material.formattedMinimumStock, equals('100'));
      expect(material.formattedReorderQuantity, equals('500'));
    });

    test('MaterialModel backward compatibility parses legacy minStockLevel field', () {
      final rawData = {
        'sku': 'MAT-ALUM-6061',
        'name': 'Aluminum Bar 6061',
        'unit': 'KG',
        'unitScale': 1000,
        'minStockLevel': 15.5, // legacy floating point representation
      };

      final material = MaterialModel.fromMap('mat_103', rawData);

      expect(material.minimumStock, equals(15500)); // converted to base units cleanly
      expect(material.formattedMinimumStock, equals('15.500'));
    });

    test('MaterialModel serializes toMap correctly for Firestore transmission', () {
      const material = MaterialModel(
        id: 'mat_104',
        sku: 'MAT-COPPER-PIPE',
        name: 'Copper Tube Ø12mm',
        category: 'RAW_MATERIAL',
        unit: 'METER',
        unitScale: 1000,
        minimumStock: 12500, // 12.500 M
        reorderQuantity: 30000,
        defaultLocation: 'Rack C-02',
      );

      final map = material.toMap();

      expect(map['sku'], equals('MAT-COPPER-PIPE'));
      expect(map['unitScale'], equals(1000));
      expect(map['minimumStock'], equals(12500));
      expect(map['defaultLocation'], equals('Rack C-02'));
      expect(map['isActive'], isTrue);
    });
  });

  group('Phase 4: StockBalanceModel & Invariant Checking', () {
    test('Calculates available quantity and detects low-stock conditions accurately', () {
      const balance = StockBalanceModel(
        id: 'mat_101_MAIN',
        materialId: 'mat_101',
        materialSku: 'MAT-SS-316L',
        materialName: 'Stainless Steel Sheet',
        locationId: 'MAIN',
        currentQuantity: 30000, // 30.000 KG
        allocatedQuantity: 12000, // 12.000 KG reserved
        availableQuantity: 18000, // 18.000 KG unallocated
        unit: 'KG',
        unitScale: 1000,
        minimumStock: 25000, // 25.000 KG safety threshold
      );

      expect(balance.currentQuantity, equals(30000));
      expect(balance.allocatedQuantity, equals(12000));
      expect(balance.availableQuantity, equals(18000));
      expect(balance.formattedCurrent, equals('30.000'));
      expect(balance.formattedAllocated, equals('12.000'));
      expect(balance.formattedAvailable, equals('18.000'));
      expect(balance.isLowStock, isFalse); // 30 > 25
    });

    test('Detects isLowStock as true when currentQuantity breaches safety minimum', () {
      const lowBalance = StockBalanceModel(
        id: 'mat_102_MAIN',
        materialId: 'mat_102',
        materialSku: 'MAT-BOLT-M8',
        materialName: 'Hex Bolt M8',
        locationId: 'MAIN',
        currentQuantity: 45, // 45 PCS remaining
        allocatedQuantity: 10,
        availableQuantity: 35,
        unit: 'PCS',
        unitScale: 1,
        minimumStock: 100, // 100 PCS safety threshold
      );

      expect(lowBalance.isLowStock, isTrue);
      expect(lowBalance.formattedCurrent, equals('45'));
    });

    test('Clamps availableQuantity to zero when allocation matches or exceeds current stock', () {
      final rawData = {
        'materialId': 'mat_103',
        'materialSku': 'MAT-BRASS-ROD',
        'materialName': 'Brass Rod',
        'currentQuantity': 5000,
        'allocatedQuantity': 6000, // Surplus allocation edge case
        'unit': 'KG',
        'unitScale': 1000,
      };

      final balance = StockBalanceModel.fromMap('mat_103_MAIN', rawData);

      expect(balance.availableQuantity, equals(0)); // never negative
    });
  });

  group('Phase 4: StockTransactionModel & Ledger Invariants', () {
    test('StockTransactionModel serializes and formats delta quantities for Receipts and Issues', () {
      final now = DateTime(2026, 10, 15, 11, 30);
      final receiptTx = StockTransactionModel(
        id: 'tx_01',
        transactionNumber: 'TX-2026-0001',
        type: 'RECEIPT',
        materialId: 'mat_101',
        materialSku: 'MAT-SS-316L',
        materialName: 'Stainless Steel Sheet',
        quantityDelta: 25000, // +25.000 KG
        balanceBefore: 10000,
        balanceAfter: 35000,
        performedByUid: 'admin_01',
        performedByName: 'Aniket Bankar',
        referenceNumber: 'PO-2026-901',
        notes: 'Incoming shipment from Jindal Stainless',
        unit: 'KG',
        unitScale: 1000,
        createdAt: now,
      );

      expect(receiptTx.isPositiveDelta, isTrue);
      expect(receiptTx.formattedDelta, equals('+25.000 KG'));
      expect(receiptTx.formattedBalanceAfter, equals('35.000 KG'));

      final issueTx = StockTransactionModel(
        id: 'tx_02',
        transactionNumber: 'TX-2026-0002',
        type: 'ISSUE',
        materialId: 'mat_101',
        materialSku: 'MAT-SS-316L',
        materialName: 'Stainless Steel Sheet',
        quantityDelta: -5000, // -5.000 KG
        balanceBefore: 35000,
        balanceAfter: 30000,
        orderId: 'WO-2026-101',
        performedByUid: 'emp_007',
        performedByName: 'Suresh Patel',
        referenceNumber: 'WO-2026-101',
        notes: 'Issued to Laser Cutting station',
        unit: 'KG',
        unitScale: 1000,
        createdAt: now,
      );

      expect(issueTx.isPositiveDelta, isFalse);
      expect(issueTx.formattedDelta, equals('-5.000 KG'));
      expect(issueTx.formattedBalanceAfter, equals('30.000 KG'));
      expect(issueTx.orderId, equals('WO-2026-101'));
    });

    test('Zero floating-point error guarantee with decimal unit conversions', () {
      // 1.500 KG + 0.250 KG + 0.125 KG in base units
      const initialBase = 1500;
      const delta1 = 250;
      const delta2 = 125;

      const sumBase = initialBase + delta1 + delta2;
      expect(sumBase, equals(1875));

      final displaySum = FactoryFormatters.formatBaseUnitsToDisplay(
        baseUnits: sumBase,
        unitScale: 1000,
      );
      expect(displaySum, equals('1.875')); // Exact representation without IEEE-754 floating drift
    });

    test('InsufficientStockException is thrown with descriptive error message and code', () {
      const ex = InsufficientStockException('Insufficient inventory stock to complete this transaction.');
      expect(ex.code, equals('insufficient-stock'));
      expect(ex.toString(), contains('Insufficient inventory stock'));
    });
  });
}
