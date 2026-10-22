import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String sku;
  final String name;
  final String category;
  final double quantity;
  final double minStockLevel;
  final String unit;
  final String location;
  final DateTime? updatedAt;

  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minStockLevel,
    required this.unit,
    required this.location,
    this.updatedAt,
  });

  bool get isLowStock => quantity <= minStockLevel;

  factory InventoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    
    DateTime? parsedDate;
    final timestamp = data['updatedAt'];
    if (timestamp is Timestamp) {
      parsedDate = timestamp.toDate();
    }

    return InventoryItem(
      id: doc.id,
      sku: data['sku'] as String? ?? 'SKU-UNKNOWN',
      name: data['name'] as String? ?? 'Unnamed Item',
      category: data['category'] as String? ?? 'Raw Material',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      minStockLevel: (data['minStockLevel'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] as String? ?? 'pcs',
      location: data['location'] as String? ?? 'Warehouse',
      updatedAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sku': sku.trim().toUpperCase(),
      'name': name.trim(),
      'category': category.trim(),
      'quantity': quantity,
      'minStockLevel': minStockLevel,
      'unit': unit.trim(),
      'location': location.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  InventoryItem copyWith({
    String? id,
    String? sku,
    String? name,
    String? category,
    double? quantity,
    double? minStockLevel,
    String? unit,
    String? location,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      unit: unit ?? this.unit,
      location: location ?? this.location,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
