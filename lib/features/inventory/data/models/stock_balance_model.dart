import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/utils/formatters.dart';

/// Real-time inventory balance for a specific material at a warehouse location.
/// Scoped under: `/organizations/{orgId}/inventoryBalances/{materialLocationId}`
/// Keyed by `${materialId}_${locationId}` or `${materialId}_MAIN`
class StockBalanceModel {
  final String id;
  final String materialId;
  final String materialSku;
  final String materialName;
  final String locationId;
  final String locationName;
  final int currentQuantity; // in integer base units (never negative)
  final int allocatedQuantity; // in integer base units (reserved for ongoing work orders)
  final int availableQuantity; // in integer base units (current - allocated, never negative)
  final String unit;
  final int unitScale;
  final int minimumStock;
  final DateTime? updatedAt;

  const StockBalanceModel({
    required this.id,
    required this.materialId,
    required this.materialSku,
    required this.materialName,
    this.locationId = 'MAIN',
    this.locationName = 'Main Warehouse',
    required this.currentQuantity,
    this.allocatedQuantity = 0,
    required this.availableQuantity,
    required this.unit,
    this.unitScale = 1,
    this.minimumStock = 0,
    this.updatedAt,
  });

  bool get isLowStock => currentQuantity <= minimumStock;

  String get formattedCurrent => FactoryFormatters.formatBaseUnitsToDisplay(
        baseUnits: currentQuantity,
        unitScale: unitScale,
      );

  String get formattedAvailable => FactoryFormatters.formatBaseUnitsToDisplay(
        baseUnits: availableQuantity,
        unitScale: unitScale,
      );

  String get formattedAllocated => FactoryFormatters.formatBaseUnitsToDisplay(
        baseUnits: allocatedQuantity,
        unitScale: unitScale,
      );

  String get formattedMinimumStock => FactoryFormatters.formatBaseUnitsToDisplay(
        baseUnits: minimumStock,
        unitScale: unitScale,
      );

  factory StockBalanceModel.fromFirestore(DocumentSnapshot doc) {
    return StockBalanceModel.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? {},
    );
  }

  factory StockBalanceModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    final scale = (data['unitScale'] as num?)?.toInt() ?? 1;

    // Support both integer base units and legacy quantity
    int current = 0;
    if (data['currentQuantity'] != null) {
      current = (data['currentQuantity'] as num).toInt();
    } else if (data['quantity'] != null) {
      current = ((data['quantity'] as num).toDouble() * scale).round();
    }

    final allocated = (data['allocatedQuantity'] as num?)?.toInt() ?? 0;
    final available = (data['availableQuantity'] as num?)?.toInt() ??
        (current - allocated).clamp(0, 999999999).toInt();

    int minStock = 0;
    if (data['minimumStock'] != null) {
      minStock = (data['minimumStock'] as num).toInt();
    } else if (data['minStockLevel'] != null) {
      minStock = ((data['minStockLevel'] as num).toDouble() * scale).round();
    }

    return StockBalanceModel(
      id: id,
      materialId: data['materialId'] as String? ?? '',
      materialSku: data['materialSku'] as String? ?? '',
      materialName: data['materialName'] as String? ?? 'Material',
      locationId: data['locationId'] as String? ?? 'MAIN',
      locationName: data['locationName'] as String? ?? 'Main Warehouse',
      currentQuantity: current < 0 ? 0 : current,
      allocatedQuantity: allocated < 0 ? 0 : allocated,
      availableQuantity: available < 0 ? 0 : available,
      unit: data['unit'] as String? ?? 'pcs',
      unitScale: scale,
      minimumStock: minStock,
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'materialId': materialId,
      'materialSku': materialSku,
      'materialName': materialName,
      'locationId': locationId,
      'locationName': locationName,
      'currentQuantity': currentQuantity,
      'allocatedQuantity': allocatedQuantity,
      'availableQuantity': availableQuantity,
      'unit': unit,
      'unitScale': unitScale,
      'minimumStock': minimumStock,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
