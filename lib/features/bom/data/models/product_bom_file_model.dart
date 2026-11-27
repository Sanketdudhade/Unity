import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing an exported or uploaded BOM file associated with a product.
/// Scoped under: `/organizations/{orgId}/products/{productId}/bomFiles/{fileId}`
class ProductBomFileModel {
  final String id;
  final String productId;
  final String bomId;
  final String fileName;
  final String fileType; // 'EXCEL' or 'CSV'
  final String storagePath;
  final String downloadUrl;
  final int version;
  final String generatedByUid;
  final String generatedByName;
  final DateTime generatedAt;
  final int fileSize; // in bytes
  final String status; // 'AVAILABLE', 'ARCHIVED'

  const ProductBomFileModel({
    required this.id,
    required this.productId,
    required this.bomId,
    required this.fileName,
    required this.fileType,
    required this.storagePath,
    required this.downloadUrl,
    required this.version,
    required this.generatedByUid,
    required this.generatedByName,
    required this.generatedAt,
    required this.fileSize,
    this.status = 'AVAILABLE',
  });

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory ProductBomFileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProductBomFileModel.fromMap(data, doc.id);
  }

  factory ProductBomFileModel.fromMap(Map<String, dynamic> data, [String id = '']) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ProductBomFileModel(
      id: id.isNotEmpty ? id : (data['id'] as String? ?? ''),
      productId: data['productId'] as String? ?? '',
      bomId: data['bomId'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      fileType: data['fileType'] as String? ?? 'EXCEL',
      storagePath: data['storagePath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      version: (data['version'] as num?)?.toInt() ?? 1,
      generatedByUid: data['generatedByUid'] as String? ?? '',
      generatedByName: data['generatedByName'] as String? ?? 'Admin',
      generatedAt: parseDate(data['generatedAt']),
      fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'AVAILABLE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'bomId': bomId,
      'fileName': fileName,
      'fileType': fileType,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'version': version,
      'generatedByUid': generatedByUid,
      'generatedByName': generatedByName,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'fileSize': fileSize,
      'status': status,
    };
  }
}
