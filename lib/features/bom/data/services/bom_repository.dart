import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/bom/data/models/bom_component_item.dart';
import 'package:unity/features/bom/data/models/bom_mapping_status.dart';
import 'package:unity/features/bom/data/models/bom_standard_item.dart';
import 'package:unity/features/bom/data/models/product_bom_file_model.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';
import 'package:unity/features/inventory/data/models/material_model.dart';

/// Repository for handling Product BOM Firestore persistence and inventory mapping.
class BomRepository {
  final FirebaseFirestore firestore;

  BomRepository({required this.firestore});

  /// Real-time stream of all BOM records for a given product.
  Stream<List<ProductBomModel>> getProductBomsStream(String orgId, String productId) {
    return firestore
        .collection(FirestorePaths.productBomsCollection(orgId, productId))
        .orderBy('version', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ProductBomModel.fromFirestore(doc)).toList();
    });
  }

  /// Gets the active BOM for a product, or null if none is marked active.
  Future<ProductBomModel?> getActiveBom(String orgId, String productId) async {
    try {
      final query = await firestore
          .collection(FirestorePaths.productBomsCollection(orgId, productId))
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return ProductBomModel.fromFirestore(query.docs.first);
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to fetch active BOM: ${e.message}', code: e.code);
    }
  }

  /// Saves a newly imported or modified BOM.
  /// Automatically manages versions, deactivates older active BOMs in a single batch transaction,
  /// and updates the parent Product document metadata (hasBom, activeBomId, bomVersion, bomStatus, bomUpdatedAt).
  Future<String> saveBom({
    required String orgId,
    required String productId,
    required ProductBomModel bom,
    bool makeActive = true,
  }) async {
    try {
      final bomsRef = firestore.collection(FirestorePaths.productBomsCollection(orgId, productId));
      final productRef = firestore.doc(FirestorePaths.productDoc(orgId, productId));

      // 1. Determine next version number
      final existingBoms = await bomsRef.get();
      int maxVersion = 0;
      for (final doc in existingBoms.docs) {
        final ver = (doc.data()['version'] as num?)?.toInt() ?? 0;
        if (ver > maxVersion) maxVersion = ver;
      }
      final newVersion = maxVersion + 1;

      final docRef = bom.id.isNotEmpty ? bomsRef.doc(bom.id) : bomsRef.doc();
      final bomId = docRef.id;

      final batch = firestore.batch();

      // 2. If making this active, deactivate older active BOMs
      if (makeActive) {
        for (final doc in existingBoms.docs) {
          if (doc.data()['isActive'] == true && doc.id != bomId) {
            batch.update(doc.reference, {
              'isActive': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // 3. Prepare BOM model with final ID, version, timestamps
      final preparedBom = bom.copyWith(
        id: bomId,
        version: newVersion,
        isActive: makeActive,
        uploadedAt: bom.uploadedAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      batch.set(docRef, preparedBom.toMap());

      // 4. Update Product model summary metadata
      if (makeActive) {
        batch.update(productRef, {
          'hasBom': true,
          'activeBomId': bomId,
          'bomVersion': newVersion,
          'bomStatus': 'ACTIVE',
          'bomUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return bomId;
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to save BOM: ${e.message}', code: e.code);
    }
  }

  /// Sets a specific BOM as active and deactivates any other versions.
  Future<void> setActiveBom({
    required String orgId,
    required String productId,
    required String bomId,
  }) async {
    try {
      final bomsRef = firestore.collection(FirestorePaths.productBomsCollection(orgId, productId));
      final productRef = firestore.doc(FirestorePaths.productDoc(orgId, productId));

      final existingBoms = await bomsRef.get();
      final batch = firestore.batch();

      int targetVersion = 1;

      for (final doc in existingBoms.docs) {
        if (doc.id == bomId) {
          targetVersion = (doc.data()['version'] as num?)?.toInt() ?? 1;
          batch.update(doc.reference, {
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (doc.data()['isActive'] == true) {
          batch.update(doc.reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      batch.update(productRef, {
        'hasBom': true,
        'activeBomId': bomId,
        'bomVersion': targetVersion,
        'bomStatus': 'ACTIVE',
        'bomUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to set active BOM: ${e.message}', code: e.code);
    }
  }

  /// Automatically attempts to match parsed BOM components and standard items
  /// against available inventory materials in [orgId].
  ///
  /// Matching Hierarchy:
  /// 1. SKU / Part Code exact match (case-insensitive).
  /// 2. Material Name / Description match.
  ProductBomModel autoMapInventory({
    required ProductBomModel bom,
    required List<MaterialModel> inventoryMaterials,
  }) {
    final Map<String, MaterialModel> skuMap = {};
    final Map<String, MaterialModel> nameMap = {};

    for (final mat in inventoryMaterials) {
      if (mat.sku.isNotEmpty) {
        skuMap[mat.sku.trim().toLowerCase()] = mat;
      }
      if (mat.name.isNotEmpty) {
        nameMap[mat.name.trim().toLowerCase()] = mat;
      }
    }

    // Map Main Components
    final updatedComponents = bom.mainComponents.map((comp) {
      // 1. Check SKU / DetNo / Material
      MaterialModel? matched;
      final rawMat = comp.material.trim().toLowerCase();
      final partName = comp.nameOfPart.trim().toLowerCase();

      if (rawMat.isNotEmpty && skuMap.containsKey(rawMat)) {
        matched = skuMap[rawMat];
      } else if (rawMat.isNotEmpty && nameMap.containsKey(rawMat)) {
        matched = nameMap[rawMat];
      } else if (partName.isNotEmpty && nameMap.containsKey(partName)) {
        matched = nameMap[partName];
      }

      if (matched != null) {
        return comp.copyWith(
          inventoryMaterialId: matched.id,
          inventoryMaterialSku: matched.sku,
          inventoryMaterialName: matched.name,
          inventoryUnit: matched.unit,
          inventoryUnitScale: matched.unitScale,
          mappingStatus: BomMappingStatus.matched,
        );
      }
      return comp;
    }).toList();

    // Map Standard Items
    final updatedStandards = bom.standardItems.map((item) {
      MaterialModel? matched;
      final partCode = item.partCode.trim().toLowerCase();
      final partName = item.nameOfPart.trim().toLowerCase();

      if (partCode.isNotEmpty && skuMap.containsKey(partCode)) {
        matched = skuMap[partCode];
      } else if (partCode.isNotEmpty && nameMap.containsKey(partCode)) {
        matched = nameMap[partCode];
      } else if (partName.isNotEmpty && nameMap.containsKey(partName)) {
        matched = nameMap[partName];
      }

      if (matched != null) {
        return item.copyWith(
          inventoryMaterialId: matched.id,
          inventoryMaterialSku: matched.sku,
          inventoryMaterialName: matched.name,
          inventoryUnit: matched.unit,
          inventoryUnitScale: matched.unitScale,
          mappingStatus: BomMappingStatus.matched,
        );
      }
      return item;
    }).toList();

    return bom.copyWith(
      mainComponents: updatedComponents,
      standardItems: updatedStandards,
    );
  }

  /// Deletes a specific BOM document.
  /// If the deleted BOM was active, the product summary status is updated accordingly.
  Future<void> deleteBom({
    required String orgId,
    required String productId,
    required String bomId,
  }) async {
    try {
      final docRef = firestore.doc(FirestorePaths.productBomDoc(orgId, productId, bomId));
      final snapshot = await docRef.get();
      final wasActive = snapshot.data()?['isActive'] == true;

      await docRef.delete();

      if (wasActive) {
        // Look for remaining BOMs to activate the latest one
        final remaining = await firestore
            .collection(FirestorePaths.productBomsCollection(orgId, productId))
            .orderBy('version', descending: true)
            .limit(1)
            .get();

        final productRef = firestore.doc(FirestorePaths.productDoc(orgId, productId));

        if (remaining.docs.isNotEmpty) {
          final nextActive = remaining.docs.first;
          await nextActive.reference.update({'isActive': true, 'updatedAt': FieldValue.serverTimestamp()});
          final ver = (nextActive.data()['version'] as num?)?.toInt() ?? 1;
          await productRef.update({
            'hasBom': true,
            'activeBomId': nextActive.id,
            'bomVersion': ver,
            'bomStatus': 'ACTIVE',
            'bomUpdatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await productRef.update({
            'hasBom': false,
            'activeBomId': '',
            'bomVersion': 0,
            'bomStatus': 'NONE',
            'bomUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to delete BOM: ${e.message}', code: e.code);
    }
  }

  /// Stream of exported or attached BOM files for a product.
  Stream<List<ProductBomFileModel>> getBomFilesStream(String orgId, String productId) {
    return firestore
        .collection(FirestorePaths.productBomFilesCollection(orgId, productId))
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ProductBomFileModel.fromFirestore(doc)).toList());
  }

  /// Records an exported BOM file entry in Firestore.
  Future<String> recordBomFile({
    required String orgId,
    required String productId,
    required ProductBomFileModel fileRecord,
  }) async {
    try {
      final collection = firestore.collection(FirestorePaths.productBomFilesCollection(orgId, productId));
      final docRef = fileRecord.id.isNotEmpty ? collection.doc(fileRecord.id) : collection.doc();
      final recordWithId = ProductBomFileModel(
        id: docRef.id,
        productId: productId,
        bomId: fileRecord.bomId,
        fileName: fileRecord.fileName,
        fileType: fileRecord.fileType,
        storagePath: fileRecord.storagePath,
        downloadUrl: fileRecord.downloadUrl,
        version: fileRecord.version,
        generatedByUid: fileRecord.generatedByUid,
        generatedByName: fileRecord.generatedByName,
        generatedAt: fileRecord.generatedAt,
        fileSize: fileRecord.fileSize,
        status: fileRecord.status,
      );

      await docRef.set(recordWithId.toMap());
      return docRef.id;
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to record BOM file: ${e.message}', code: e.code);
    }
  }

  /// Deletes a recorded BOM file document (does not delete underlying BOM data).
  Future<void> deleteBomFile({
    required String orgId,
    required String productId,
    required String fileId,
  }) async {
    try {
      await firestore.doc(FirestorePaths.productBomFileDoc(orgId, productId, fileId)).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to delete BOM file: ${e.message}', code: e.code);
    }
  }
}
