import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/utils/formatters.dart';

/// Represents a raw material, hardware, component, or consumable in the material catalog.
/// Scoped under: `/organizations/{orgId}/materials/{materialId}`
class MaterialModel {
  final String id;
  final String sku;
  final String name;
  final String category;
  final String unit;
  final int unitScale; // 1000 for continuous/decimal measurements (KG, METER, LITER); 1 for discrete items (PCS, SHEET, BAR)
  final int minimumStock; // in base units
  final int reorderQuantity; // in base units
  final String defaultLocation;
  final int? unitCost; // in integer paise / cents (e.g. ₹15.50 = 1550)
  final String notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MaterialModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unit,
    this.unitScale = 1,
    this.minimumStock = 0,
    this.reorderQuantity = 0,
    this.defaultLocation = 'Warehouse Main',
    this.unitCost,
    this.notes = '',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedMinimumStock => FactoryFormatters.formatBaseUnitsToDisplay(
        baseUnits: minimumStock,
        unitScale: unitScale,
      );

  String get formattedReorderQuantity => FactoryFormatters.formatBaseUnitsToDisplay(
        baseUnits: reorderQuantity,
        unitScale: unitScale,
      );

  factory MaterialModel.fromFirestore(DocumentSnapshot doc) {
    return MaterialModel.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? {},
    );
  }

  factory MaterialModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    final scale = (data['unitScale'] as num?)?.toInt() ?? 1;

    // Support both integer base units and legacy minStockLevel
    int parsedMinStock = 0;
    if (data['minimumStock'] != null) {
      parsedMinStock = (data['minimumStock'] as num).toInt();
    } else if (data['minStockLevel'] != null) {
      parsedMinStock = ((data['minStockLevel'] as num).toDouble() * scale).round();
    }

    return MaterialModel(
      id: id,
      sku: (data['sku'] as String? ?? 'MAT-NEW').trim().toUpperCase(),
      name: (data['name'] as String? ?? 'Unnamed Material').trim(),
      category: (data['category'] as String? ?? 'RAW_MATERIAL').trim(),
      unit: (data['unit'] as String? ?? 'pcs').trim(),
      unitScale: scale,
      minimumStock: parsedMinStock,
      reorderQuantity: (data['reorderQuantity'] as num?)?.toInt() ?? 0,
      defaultLocation: (data['defaultLocation'] as String? ?? data['location'] as String? ?? 'Warehouse Main').trim(),
      unitCost: (data['unitCost'] as num?)?.toInt(),
      notes: (data['notes'] as String? ?? '').trim(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sku': sku.trim().toUpperCase(),
      'name': name.trim(),
      'category': category.trim(),
      'unit': unit.trim(),
      'unitScale': unitScale,
      'minimumStock': minimumStock,
      'reorderQuantity': reorderQuantity,
      'defaultLocation': defaultLocation.trim(),
      'unitCost': unitCost,
      'notes': notes.trim(),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  MaterialModel copyWith({
    String? id,
    String? sku,
    String? name,
    String? category,
    String? unit,
    int? unitScale,
    int? minimumStock,
    int? reorderQuantity,
    String? defaultLocation,
    int? unitCost,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialModel(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      unitScale: unitScale ?? this.unitScale,
      minimumStock: minimumStock ?? this.minimumStock,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
      defaultLocation: defaultLocation ?? this.defaultLocation,
      unitCost: unitCost ?? this.unitCost,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
