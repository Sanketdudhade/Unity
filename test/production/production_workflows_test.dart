import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/data/models/production_workflows.dart';

void main() {
  group('Production Workflows Specification Tests', () {
    test('Cutting workflow has exactly 14 stages in the required order', () {
      final stages = ProductionWorkflows.cuttingStages();
      expect(stages.length, equals(14));

      final expectedNames = [
        'BOM',
        'Material Order Date',
        'Raw Material',
        'M&G (Milling & Grinding)',
        'DWG (Drawing)',
        'Pillar / Bush / Button',
        'DRO',
        'ASY (Assembly)',
        'H/T (Heat Treatment)',
        'VMC',
        'W/C (Wire Cutting)',
        'F.ASY (Final Assembly)',
        'Trial',
        'Tool Final Date',
      ];

      for (int i = 0; i < expectedNames.length; i++) {
        expect(stages[i].sequence, equals(i + 1));
        expect(stages[i].name, equals(expectedNames[i]));
      }
    });

    test('Non-Cutting workflow has exactly 15 stages in the required order', () {
      final stages = ProductionWorkflows.nonCuttingStages();
      expect(stages.length, equals(15));

      final expectedNames = [
        'BOM',
        'Material Order Date',
        'Raw Material',
        'M&G (Milling & Grinding)',
        'DWG (Drawing)',
        'Pillar / Bush / Button',
        'DRO',
        'ASY (Assembly)',
        'VMC',
        'Machine / Drawing Operation',
        'W/C (Wire Cutting)',
        'F.ASY (Final Assembly)',
        'Trial',
        'H/T (Heat Treatment)',
        'Tool Final Date',
      ];

      for (int i = 0; i < expectedNames.length; i++) {
        expect(stages[i].sequence, equals(i + 1));
        expect(stages[i].name, equals(expectedNames[i]));
      }
    });

    test('ProductionOrder serialization preserves productionType field', () {
      final order = ProductionOrder(
        id: 'ord_123',
        orderNumber: 'WO-12345',
        productName: 'Sample Die',
        targetQuantity: 100,
        unit: 'PCS',
        status: 'scheduled',
        priority: 'high',
        productionType: ProductionWorkflows.cutting,
      );

      final map = order.toMap();
      expect(map['productionType'], equals('CUTTING'));

      final nonCutOrder = order.copyWith(productionType: ProductionWorkflows.nonCutting);
      expect(nonCutOrder.isNonCutting, isTrue);
      expect(nonCutOrder.isCutting, isFalse);
    });
  });
}
