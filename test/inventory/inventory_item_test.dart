import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/inventory/data/models/inventory_item_model.dart';

void main() {
  group('InventoryItem Model Tests', () {
    test('Calculates isLowStock correctly when quantity is below or equal to threshold', () {
      const itemLow = InventoryItem(
        id: 'item_1',
        sku: 'RM-STEEL-01',
        name: 'Steel Sheet 316L',
        category: 'Raw Material',
        quantity: 15.0,
        minStockLevel: 20.0,
        unit: 'kg',
        location: 'Bay 1',
      );

      const itemOptimal = InventoryItem(
        id: 'item_2',
        sku: 'RM-STEEL-02',
        name: 'Steel Bar',
        category: 'Raw Material',
        quantity: 50.0,
        minStockLevel: 20.0,
        unit: 'kg',
        location: 'Bay 2',
      );

      expect(itemLow.isLowStock, isTrue);
      expect(itemOptimal.isLowStock, isFalse);
    });

    test('Serializes to valid Firestore map', () {
      const item = InventoryItem(
        id: 'item_3',
        sku: 'FG-VALVE-10',
        name: 'Pressure Valve 10mm',
        category: 'Finished Good',
        quantity: 100.0,
        minStockLevel: 25.0,
        unit: 'pcs',
        location: 'Warehouse B',
      );

      final map = item.toMap();
      expect(map['sku'], 'FG-VALVE-10');
      expect(map['name'], 'Pressure Valve 10mm');
      expect(map['category'], 'Finished Good');
      expect(map['quantity'], 100.0);
      expect(map['minStockLevel'], 25.0);
      expect(map['unit'], 'pcs');
      expect(map['location'], 'Warehouse B');
      expect(map.containsKey('updatedAt'), isTrue);
    });
  });
}
