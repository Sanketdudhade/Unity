import 'bom_mapping_status.dart';

/// Represents a single main manufactured/machined component extracted from a product BOM.
class BomComponentItem {
  final String id;
  final String detNo;
  final String nameOfPart;
  final String sectionName;
  final int qty;
  final String material;
  final String finishHeight;
  final String finishWidth;
  final String finishLength;
  final String rowHeight;
  final String rowWidth;
  final String rowLength;
  final String materialVendor;
  final String materialIn;
  final String millingGrinding;
  final String jigBoring;
  final String vmc;
  final String wireCut;
  final String hardening;
  final String assly;

  // Inventory mapping fields
  final String? inventoryMaterialId;
  final String? inventoryMaterialSku;
  final String? inventoryMaterialName;
  final String? inventoryUnit;
  final int inventoryUnitScale;
  final BomMappingStatus mappingStatus;

  const BomComponentItem({
    required this.id,
    required this.detNo,
    required this.nameOfPart,
    this.sectionName = 'GENERAL',
    required this.qty,
    required this.material,
    this.finishHeight = '',
    this.finishWidth = '',
    this.finishLength = '',
    this.rowHeight = '',
    this.rowWidth = '',
    this.rowLength = '',
    this.materialVendor = '',
    this.materialIn = '',
    this.millingGrinding = '',
    this.jigBoring = '',
    this.vmc = '',
    this.wireCut = '',
    this.hardening = '',
    this.assly = '',
    this.inventoryMaterialId,
    this.inventoryMaterialSku,
    this.inventoryMaterialName,
    this.inventoryUnit,
    this.inventoryUnitScale = 1,
    this.mappingStatus = BomMappingStatus.unmatched,
  });

  String get finishDimensions {
    final parts = [finishHeight, finishWidth, finishLength].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join(' × ');
  }

  String get rowDimensions {
    final parts = [rowHeight, rowWidth, rowLength].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? '-' : parts.join(' × ');
  }

  bool get isMapped =>
      inventoryMaterialId != null &&
      inventoryMaterialId!.isNotEmpty &&
      mappingStatus != BomMappingStatus.unmatched;

  factory BomComponentItem.fromMap(Map<String, dynamic> data) {
    return BomComponentItem(
      id: (data['id'] as String? ?? '').trim(),
      detNo: (data['detNo'] as String? ?? '').trim(),
      nameOfPart: (data['nameOfPart'] as String? ?? '').trim(),
      sectionName: (data['sectionName'] as String? ?? 'GENERAL').trim(),
      qty: (data['qty'] as num?)?.toInt() ?? 1,
      material: (data['material'] as String? ?? '').trim(),
      finishHeight: (data['finishHeight'] as String? ?? '').trim(),
      finishWidth: (data['finishWidth'] as String? ?? '').trim(),
      finishLength: (data['finishLength'] as String? ?? '').trim(),
      rowHeight: (data['rowHeight'] as String? ?? '').trim(),
      rowWidth: (data['rowWidth'] as String? ?? '').trim(),
      rowLength: (data['rowLength'] as String? ?? '').trim(),
      materialVendor: (data['materialVendor'] as String? ?? '').trim(),
      materialIn: (data['materialIn'] as String? ?? '').trim(),
      millingGrinding: (data['millingGrinding'] as String? ?? '').trim(),
      jigBoring: (data['jigBoring'] as String? ?? '').trim(),
      vmc: (data['vmc'] as String? ?? '').trim(),
      wireCut: (data['wireCut'] as String? ?? '').trim(),
      hardening: (data['hardening'] as String? ?? '').trim(),
      assly: (data['assly'] as String? ?? '').trim(),
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
      'sectionName': sectionName,
      'qty': qty,
      'material': material,
      'finishHeight': finishHeight,
      'finishWidth': finishWidth,
      'finishLength': finishLength,
      'rowHeight': rowHeight,
      'rowWidth': rowWidth,
      'rowLength': rowLength,
      'materialVendor': materialVendor,
      'materialIn': materialIn,
      'millingGrinding': millingGrinding,
      'jigBoring': jigBoring,
      'vmc': vmc,
      'wireCut': wireCut,
      'hardening': hardening,
      'assly': assly,
      'inventoryMaterialId': inventoryMaterialId,
      'inventoryMaterialSku': inventoryMaterialSku,
      'inventoryMaterialName': inventoryMaterialName,
      'inventoryUnit': inventoryUnit,
      'inventoryUnitScale': inventoryUnitScale,
      'mappingStatus': mappingStatus.toDbString(),
    };
  }

  BomComponentItem copyWith({
    String? id,
    String? detNo,
    String? nameOfPart,
    String? sectionName,
    int? qty,
    String? material,
    String? finishHeight,
    String? finishWidth,
    String? finishLength,
    String? rowHeight,
    String? rowWidth,
    String? rowLength,
    String? materialVendor,
    String? materialIn,
    String? millingGrinding,
    String? jigBoring,
    String? vmc,
    String? wireCut,
    String? hardening,
    String? assly,
    String? inventoryMaterialId,
    String? inventoryMaterialSku,
    String? inventoryMaterialName,
    String? inventoryUnit,
    int? inventoryUnitScale,
    BomMappingStatus? mappingStatus,
  }) {
    return BomComponentItem(
      id: id ?? this.id,
      detNo: detNo ?? this.detNo,
      nameOfPart: nameOfPart ?? this.nameOfPart,
      sectionName: sectionName ?? this.sectionName,
      qty: qty ?? this.qty,
      material: material ?? this.material,
      finishHeight: finishHeight ?? this.finishHeight,
      finishWidth: finishWidth ?? this.finishWidth,
      finishLength: finishLength ?? this.finishLength,
      rowHeight: rowHeight ?? this.rowHeight,
      rowWidth: rowWidth ?? this.rowWidth,
      rowLength: rowLength ?? this.rowLength,
      materialVendor: materialVendor ?? this.materialVendor,
      materialIn: materialIn ?? this.materialIn,
      millingGrinding: millingGrinding ?? this.millingGrinding,
      jigBoring: jigBoring ?? this.jigBoring,
      vmc: vmc ?? this.vmc,
      wireCut: wireCut ?? this.wireCut,
      hardening: hardening ?? this.hardening,
      assly: assly ?? this.assly,
      inventoryMaterialId: inventoryMaterialId ?? this.inventoryMaterialId,
      inventoryMaterialSku: inventoryMaterialSku ?? this.inventoryMaterialSku,
      inventoryMaterialName: inventoryMaterialName ?? this.inventoryMaterialName,
      inventoryUnit: inventoryUnit ?? this.inventoryUnit,
      inventoryUnitScale: inventoryUnitScale ?? this.inventoryUnitScale,
      mappingStatus: mappingStatus ?? this.mappingStatus,
    );
  }
}
