import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String partCode;
  final String name;
  final String description;
  final String drawingNumber;
  final String revision;
  final String unit;
  final String customerReference;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductModel({
    required this.id,
    required this.partCode,
    required this.name,
    this.description = '',
    this.drawingNumber = '',
    this.revision = 'Rev A',
    this.unit = 'PCS',
    this.customerReference = '',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    return ProductModel.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? {},
    );
  }

  factory ProductModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return ProductModel(
      id: id,
      partCode: data['partCode'] as String? ?? 'PRD-NEW',
      name: data['name'] as String? ?? 'Unnamed Product',
      description: data['description'] as String? ?? '',
      drawingNumber: data['drawingNumber'] as String? ?? '',
      revision: data['revision'] as String? ?? 'Rev A',
      unit: data['unit'] as String? ?? 'PCS',
      customerReference: data['customerReference'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partCode': partCode.trim().toUpperCase(),
      'name': name.trim(),
      'description': description.trim(),
      'drawingNumber': drawingNumber.trim().toUpperCase(),
      'revision': revision.trim(),
      'unit': unit.trim().toUpperCase(),
      'customerReference': customerReference.trim(),
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? partCode,
    String? name,
    String? description,
    String? drawingNumber,
    String? revision,
    String? unit,
    String? customerReference,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      partCode: partCode ?? this.partCode,
      name: name ?? this.name,
      description: description ?? this.description,
      drawingNumber: drawingNumber ?? this.drawingNumber,
      revision: revision ?? this.revision,
      unit: unit ?? this.unit,
      customerReference: customerReference ?? this.customerReference,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
