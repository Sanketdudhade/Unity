import 'package:cloud_firestore/cloud_firestore.dart';
import 'bom_component_item.dart';
import 'bom_standard_item.dart';

/// Authoritative Product-specific Bill of Materials (BOM) document model.
/// Scoped under: `/organizations/{orgId}/products/{productId}/boms/{bomId}`
class ProductBomModel {
  final String id;
  final String productId;
  final String productCode;
  final String productName;
  final String partNoExtracted;
  final String partNameExtracted;
  final String toolNo;
  final String toolName;
  final String designedBy;
  final String date;
  final String customer;
  final String project;
  final String materialSheet;
  final String materialThickness;
  final String revision;
  final int version;
  final String uploadedFileName;
  final String uploadedByUid;
  final String uploadedByName;
  final DateTime? uploadedAt;
  final DateTime? updatedAt;
  final bool isActive;
  final List<BomComponentItem> mainComponents;
  final List<BomStandardItem> standardItems;

  const ProductBomModel({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    this.partNoExtracted = '',
    this.partNameExtracted = '',
    this.toolNo = '',
    this.toolName = '',
    this.designedBy = '',
    this.date = '',
    this.customer = '',
    this.project = '',
    this.materialSheet = '',
    this.materialThickness = '',
    this.revision = 'Rev 1',
    this.version = 1,
    this.uploadedFileName = '',
    this.uploadedByUid = '',
    this.uploadedByName = '',
    this.uploadedAt,
    this.updatedAt,
    this.isActive = true,
    this.mainComponents = const [],
    this.standardItems = const [],
  });

  int get totalComponentsCount => mainComponents.length;
  int get totalStandardItemsCount => standardItems.length;
  List<BomComponentItem> get components => mainComponents;
  int get totalItemsCount => totalComponentsCount + totalStandardItemsCount;

  int get mappedItemsCount =>
      mainComponents.where((c) => c.isMapped).length +
      standardItems.where((s) => s.isMapped).length;

  int get unmappedItemsCount => totalItemsCount - mappedItemsCount;

  double get mappingPercentage =>
      totalItemsCount == 0 ? 0.0 : (mappedItemsCount / totalItemsCount) * 100.0;

  factory ProductBomModel.fromFirestore(DocumentSnapshot doc) {
    return ProductBomModel.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? {},
    );
  }

  factory ProductBomModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    final rawComponents = (data['mainComponents'] as List<dynamic>?) ?? [];
    final components = rawComponents
        .map((item) => BomComponentItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    final rawStandard = (data['standardItems'] as List<dynamic>?) ?? [];
    final standard = rawStandard
        .map((item) => BomStandardItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return ProductBomModel(
      id: id,
      productId: (data['productId'] as String? ?? '').trim(),
      productCode: (data['productCode'] as String? ?? '').trim(),
      productName: (data['productName'] as String? ?? '').trim(),
      partNoExtracted: (data['partNoExtracted'] as String? ?? '').trim(),
      partNameExtracted: (data['partNameExtracted'] as String? ?? '').trim(),
      toolNo: (data['toolNo'] as String? ?? '').trim(),
      toolName: (data['toolName'] as String? ?? '').trim(),
      designedBy: (data['designedBy'] as String? ?? '').trim(),
      date: (data['date'] as String? ?? '').trim(),
      customer: (data['customer'] as String? ?? '').trim(),
      project: (data['project'] as String? ?? '').trim(),
      materialSheet: (data['materialSheet'] as String? ?? '').trim(),
      materialThickness: (data['materialThickness'] as String? ?? '').trim(),
      revision: (data['revision'] as String? ?? 'Rev 1').trim(),
      version: (data['version'] as num?)?.toInt() ?? 1,
      uploadedFileName: (data['uploadedFileName'] as String? ?? '').trim(),
      uploadedByUid: (data['uploadedByUid'] as String? ?? '').trim(),
      uploadedByName: (data['uploadedByName'] as String? ?? '').trim(),
      uploadedAt: parseDate(data['uploadedAt']),
      updatedAt: parseDate(data['updatedAt']),
      isActive: data['isActive'] as bool? ?? true,
      mainComponents: components,
      standardItems: standard,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productCode': productCode,
      'productName': productName,
      'partNoExtracted': partNoExtracted,
      'partNameExtracted': partNameExtracted,
      'toolNo': toolNo,
      'toolName': toolName,
      'designedBy': designedBy,
      'date': date,
      'customer': customer,
      'project': project,
      'materialSheet': materialSheet,
      'materialThickness': materialThickness,
      'revision': revision,
      'version': version,
      'uploadedFileName': uploadedFileName,
      'uploadedByUid': uploadedByUid,
      'uploadedByName': uploadedByName,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
      'mainComponents': mainComponents.map((c) => c.toMap()).toList(),
      'standardItems': standardItems.map((s) => s.toMap()).toList(),
      'totalComponentsCount': totalComponentsCount,
      'totalStandardItemsCount': totalStandardItemsCount,
      'mappedItemsCount': mappedItemsCount,
      'unmappedItemsCount': unmappedItemsCount,
    };
  }

  ProductBomModel copyWith({
    String? id,
    String? productId,
    String? productCode,
    String? productName,
    String? partNoExtracted,
    String? partNameExtracted,
    String? toolNo,
    String? toolName,
    String? designedBy,
    String? date,
    String? customer,
    String? project,
    String? materialSheet,
    String? materialThickness,
    String? revision,
    int? version,
    String? uploadedFileName,
    String? uploadedByUid,
    String? uploadedByName,
    DateTime? uploadedAt,
    DateTime? updatedAt,
    bool? isActive,
    List<BomComponentItem>? mainComponents,
    List<BomStandardItem>? standardItems,
  }) {
    return ProductBomModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      partNoExtracted: partNoExtracted ?? this.partNoExtracted,
      partNameExtracted: partNameExtracted ?? this.partNameExtracted,
      toolNo: toolNo ?? this.toolNo,
      toolName: toolName ?? this.toolName,
      designedBy: designedBy ?? this.designedBy,
      date: date ?? this.date,
      customer: customer ?? this.customer,
      project: project ?? this.project,
      materialSheet: materialSheet ?? this.materialSheet,
      materialThickness: materialThickness ?? this.materialThickness,
      revision: revision ?? this.revision,
      version: version ?? this.version,
      uploadedFileName: uploadedFileName ?? this.uploadedFileName,
      uploadedByUid: uploadedByUid ?? this.uploadedByUid,
      uploadedByName: uploadedByName ?? this.uploadedByName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      mainComponents: mainComponents ?? this.mainComponents,
      standardItems: standardItems ?? this.standardItems,
    );
  }
}
