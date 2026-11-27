import 'bom_mapping_status.dart';

/// Represents a standard catalogue / off-the-shelf component (e.g. Misumi punches, buttons, pillars, springs)
/// extracted from the STD BOM LIST section of a product BOM.
class BomStandardItem {
  final String id;
  final String detNo;
  final String nameOfPart;
  final String vendor;
  final String partCode;
  final int qty;

  // Inventory mapping fields
  final String? inventoryMaterialId;
  final String? inventoryMaterialSku;
  final String? inventoryMaterialName;
  final String? inventoryUnit;
  final int inventoryUnitScale;
  final BomMappingStatus mappingStatus;

  const BomStandardItem({
    required this.id,
    required this.detNo,
    required this.nameOfPart,
    this.vendor = '',
    required this.partCode,
    required this.qty,
    this.inventoryMaterialId,
    this.inventoryMaterialSku,
    this.inventoryMaterialName,
    this.inventoryUnit,
    this.inventoryUnitScale = 1,
    this.mappingStatus = BomMappingStatus.unmatched,
  });

  bool get isMapped =>
      inventoryMaterialId != null &&
      inventoryMaterialId!.isNotEmpty &&
      mappingStatus != BomMappingStatus.unmatched;

  factory BomStandardItem.fromMap(Map<String, dynamic> data) {
    return BomStandardItem(
      id: (data['id'] as String? ?? '').trim(),
      detNo: (data['detNo'] as String? ?? '').trim(),
      nameOfPart: (data['nameOfPart'] as String? ?? '').trim(),
      vendor: (data['vendor'] as String? ?? '').trim(),
      partCode: (data['partCode'] as String? ?? '').trim(),
      qty: (data['qty'] as num?)?.toInt() ?? 1,
      inventoryMaterialId: data['inventoryMaterialId'] as String?,
      inventoryMaterialSku: data['inventoryMaterialSku'] as String?,
      inventoryMaterialName: data['inventoryMaterialName'] as String?,
      inventoryUnit: data['inventoryUnit'] as String?,
      inventoryUnitScale: (data['inventoryUnitScale'] as num?)?.toInt() ?? 1,
      mappingStatus: BomMappingStatus.fromString(data['mappingStatus'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'detNo': detNo,
      'nameOfPart': nameOfPart,
      'vendor': vendor,
      'partCode': partCode,
      'qty': qty,
      'inventoryMaterialId': inventoryMaterialId,
      'inventoryMaterialSku': inventoryMaterialSku,
      'inventoryMaterialName': inventoryMaterialName,
      'inventoryUnit': inventoryUnit,
      'inventoryUnitScale': inventoryUnitScale,
      'mappingStatus': mappingStatus.toDbString(),
    };
  }

  BomStandardItem copyWith({
    String? id,
    String? detNo,
    String? nameOfPart,
    String? vendor,
    String? partCode,
    int? qty,
    String? inventoryMaterialId,
    String? inventoryMaterialSku,
    String? inventoryMaterialName,
    String? inventoryUnit,
    int? inventoryUnitScale,
    BomMappingStatus? mappingStatus,
  }) {
    return BomStandardItem(
      id: id ?? this.id,
      detNo: detNo ?? this.detNo,
      nameOfPart: nameOfPart ?? this.nameOfPart,
      vendor: vendor ?? this.vendor,
      partCode: partCode ?? this.partCode,
      qty: qty ?? this.qty,
      inventoryMaterialId: inventoryMaterialId ?? this.inventoryMaterialId,
      inventoryMaterialSku: inventoryMaterialSku ?? this.inventoryMaterialSku,
      inventoryMaterialName: inventoryMaterialName ?? this.inventoryMaterialName,
      inventoryUnit: inventoryUnit ?? this.inventoryUnit,
      inventoryUnitScale: inventoryUnitScale ?? this.inventoryUnitScale,
      mappingStatus: mappingStatus ?? this.mappingStatus,
    );
  }
}
