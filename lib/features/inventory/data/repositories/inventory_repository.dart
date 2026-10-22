import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/inventory/data/models/inventory_item_model.dart';
import 'package:unity/features/inventory/data/models/material_model.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/data/models/stock_movement_model.dart';

/// Repository for handling materials catalog, real-time inventory balances,
/// and authoritative immutable ledger transactions with zero floating-point math.
class InventoryRepository {
  final FirebaseFirestore firestore;

  InventoryRepository({required this.firestore});

  // ==========================================
  // 1. MATERIAL MASTER CATALOG
  // ==========================================

  /// Real-time stream of materials in [orgId].
  Stream<List<MaterialModel>> getMaterialsStream(String orgId) {
    return firestore
        .collection(FirestorePaths.materialsCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MaterialModel.fromFirestore(doc))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  /// Creates a new Material Master and initializes its default location balance.
  Future<String> createMaterial({
    required String orgId,
    required MaterialModel material,
    int initialQuantity = 0,
    String actorUid = 'system',
    String actorName = 'Admin',
  }) async {
    try {
      final materialsCol = firestore.collection(FirestorePaths.materialsCollection(orgId));
      final materialDoc = materialsCol.doc();
      final materialId = materialDoc.id;

      final balanceLocId = '${materialId}_MAIN';
      final balanceDoc = firestore
          .collection(FirestorePaths.inventoryBalancesCollection(orgId))
          .doc(balanceLocId);

      final batch = firestore.batch();

      // 1. Material Master Record
      final materialToSave = material.copyWith(id: materialId);
      final materialMap = materialToSave.toMap();
      materialMap['quantity'] = initialQuantity > 0 ? (initialQuantity / material.unitScale) : 0.0;
      batch.set(materialDoc, materialMap);

      // 2. Initial Stock Balance Record
      final initialBalance = StockBalanceModel(
        id: balanceLocId,
        materialId: materialId,
        materialSku: material.sku,
        materialName: material.name,
        locationId: 'MAIN',
        locationName: material.defaultLocation,
        currentQuantity: initialQuantity,
        allocatedQuantity: 0,
        availableQuantity: initialQuantity,
        unit: material.unit,
        unitScale: material.unitScale,
        minimumStock: material.minimumStock,
      );
      batch.set(balanceDoc, initialBalance.toMap());

      // 3. Optional Initial Receipt Ledger Record
      if (initialQuantity > 0) {
        final txDoc = firestore
            .collection(FirestorePaths.inventoryTransactionsCollection(orgId))
            .doc();
        final tx = StockTransactionModel(
          id: txDoc.id,
          transactionNumber: 'TX-INIT-${DateTime.now().millisecondsSinceEpoch}',
          type: 'RECEIPT',
          materialId: materialId,
          materialSku: material.sku,
          materialName: material.name,
          locationId: 'MAIN',
          quantityDelta: initialQuantity,
          balanceBefore: 0,
          balanceAfter: initialQuantity,
          performedByUid: actorUid,
          performedByName: actorName,
          referenceNumber: 'INITIAL-STOCK',
          notes: 'Initial inventory creation',
          unit: material.unit,
          unitScale: material.unitScale,
        );
        batch.set(txDoc, tx.toMap());
      }

      await batch.commit();
      return materialId;
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create material: ${e.message}', code: e.code);
    }
  }

  /// Updates Material Master metadata.
  Future<void> updateMaterial(String orgId, MaterialModel material) async {
    try {
      await firestore
          .collection(FirestorePaths.materialsCollection(orgId))
          .doc(material.id)
          .update(material.toMap());

      // Sync minimumStock & unit to balance record
      final balanceLocId = '${material.id}_MAIN';
      await firestore
          .collection(FirestorePaths.inventoryBalancesCollection(orgId))
          .doc(balanceLocId)
          .set({
        'materialSku': material.sku,
        'materialName': material.name,
        'unit': material.unit,
        'unitScale': material.unitScale,
        'minimumStock': material.minimumStock,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update material: ${e.message}', code: e.code);
    }
  }

  /// Toggles active state of a material.
  Future<void> toggleMaterialActive(String orgId, String materialId, bool isActive) async {
    try {
      await firestore
          .collection(FirestorePaths.materialsCollection(orgId))
          .doc(materialId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to toggle material: ${e.message}', code: e.code);
    }
  }

  // ==========================================
  // 2. INVENTORY BALANCES (READ-ONLY FOR CLIENTS)
  // ==========================================

  /// Real-time stream of all inventory balances in [orgId].
  Stream<List<StockBalanceModel>> getBalancesStream(String orgId) {
    return firestore
        .collection(FirestorePaths.inventoryBalancesCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StockBalanceModel.fromFirestore(doc))
          .toList()
        ..sort((a, b) => a.materialName.toLowerCase().compareTo(b.materialName.toLowerCase()));
    });
  }

  /// Real-time stream of low stock materials.
  Stream<List<StockBalanceModel>> getLowStockBalancesStream(String orgId) {
    return getBalancesStream(orgId).map((balances) {
      return balances.where((b) => b.isLowStock).toList();
    });
  }

  /// Streams a single material balance for a location.
  Stream<StockBalanceModel?> getBalanceForMaterial(
    String orgId,
    String materialId, {
    String locationId = 'MAIN',
  }) {
    final balanceLocId = '${materialId}_$locationId';
    return firestore
        .collection(FirestorePaths.inventoryBalancesCollection(orgId))
        .doc(balanceLocId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return StockBalanceModel.fromFirestore(doc);
    });
  }

  // ==========================================
  // 3. AUTHORITATIVE IMMUTABLE TRANSACTION LEDGER
  // ==========================================

  /// Streams the immutable transaction history.
  Stream<List<StockTransactionModel>> getTransactionsStream(
    String orgId, {
    String? materialId,
    int limit = 100,
  }) {
    Query query = firestore
        .collection(FirestorePaths.inventoryTransactionsCollection(orgId))
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (materialId != null && materialId.isNotEmpty) {
      query = query.where('materialId', isEqualTo: materialId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => StockTransactionModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Executes an atomic ledger transaction and updates the material balance.
  /// Strictly enforces zero floating-point error and non-negative balance invariants.
  Future<String> recordTransaction({
    required String orgId,
    required String materialId,
    required String materialSku,
    required String materialName,
    required String type, // 'RECEIPT', 'ISSUE', 'ALLOCATION', 'DEALLOCATION', 'SCRAP', 'ADJUSTMENT', 'RETURN'
    required int quantityDelta, // positive for in/return/adjustment-up, negative for out/scrap
    String locationId = 'MAIN',
    String locationName = 'Main Warehouse',
    String? orderId,
    String? processId,
    required String performedByUid,
    required String performedByName,
    String? referenceNumber,
    String notes = '',
    String unit = 'pcs',
    int unitScale = 1,
  }) async {
    final balanceLocId = '${materialId}_$locationId';
    final balanceRef = firestore
        .collection(FirestorePaths.inventoryBalancesCollection(orgId))
        .doc(balanceLocId);
    final txRef = firestore
        .collection(FirestorePaths.inventoryTransactionsCollection(orgId))
        .doc();
    final materialRef = firestore
        .collection(FirestorePaths.materialsCollection(orgId))
        .doc(materialId);

    return firestore.runTransaction<String>((transaction) async {
      final balanceSnap = await transaction.get(balanceRef);

      int currentQty = 0;
      int allocatedQty = 0;
      int minStock = 0;

      if (balanceSnap.exists) {
        final data = balanceSnap.data() as Map<String, dynamic>;
        currentQty = (data['currentQuantity'] as num?)?.toInt() ?? 0;
        allocatedQty = (data['allocatedQuantity'] as num?)?.toInt() ?? 0;
        minStock = (data['minimumStock'] as num?)?.toInt() ?? 0;
      } else {
        // If balance does not exist, only RECEIPT, ADJUSTMENT, or RETURN can initialize it
        final isInitAllowed = type == 'RECEIPT' || type == 'ADJUSTMENT' || type == 'RETURN';
        if (!isInitAllowed) {
          throw const InsufficientStockException(
            'Cannot issue, scrap, or allocate material: No inventory balance record exists for this item.',
          );
        }
      }

      int newCurrent = currentQty;
      int newAllocated = allocatedQty;

      final normalizedType = type.trim().toUpperCase();

      switch (normalizedType) {
        case 'RECEIPT':
        case 'RETURN':
          if (quantityDelta <= 0) {
            throw const ValidationException('Receipt or return quantity must be positive.');
          }
          newCurrent = currentQty + quantityDelta;
          break;

        case 'ISSUE':
          final issueAmount = quantityDelta.abs();
          if (issueAmount <= 0) {
            throw const ValidationException('Issue quantity must be greater than zero.');
          }
          if (currentQty < issueAmount) {
            throw InsufficientStockException(
              'Cannot issue $issueAmount base units: Only $currentQty available in stock.',
            );
          }
          newCurrent = currentQty - issueAmount;
          // If issued against an active allocation, deduct from allocated as well
          if (allocatedQty > 0 && orderId != null && orderId.isNotEmpty) {
            newAllocated = max(0, allocatedQty - issueAmount);
          }
          break;

        case 'SCRAP':
          final scrapAmount = quantityDelta.abs();
          if (scrapAmount <= 0) {
            throw const ValidationException('Scrap quantity must be greater than zero.');
          }
          if (currentQty < scrapAmount) {
            throw InsufficientStockException(
              'Cannot scrap $scrapAmount base units: Only $currentQty available in stock.',
            );
          }
          newCurrent = currentQty - scrapAmount;
          break;

        case 'ALLOCATION':
          final allocAmount = quantityDelta.abs();
          final available = currentQty - allocatedQty;
          if (allocAmount <= 0) {
            throw const ValidationException('Allocation quantity must be greater than zero.');
          }
          if (available < allocAmount) {
            throw InsufficientStockException(
              'Cannot allocate $allocAmount base units: Only $available unallocated units available in stock.',
            );
          }
          newAllocated = allocatedQty + allocAmount;
          break;

        case 'DEALLOCATION':
          final deallocAmount = quantityDelta.abs();
          newAllocated = max(0, allocatedQty - deallocAmount);
          break;

        case 'ADJUSTMENT':
          newCurrent = currentQty + quantityDelta;
          if (newCurrent < 0) {
            throw const InsufficientStockException(
              'Stock adjustment would cause inventory to become negative.',
            );
          }
          break;

        default:
          throw ValidationException('Unsupported inventory transaction type: $type');
      }

      final newAvailable = max(0, newCurrent - newAllocated);

      // 1. Write immutable ledger transaction
      final txModel = StockTransactionModel(
        id: txRef.id,
        transactionNumber: 'TX-${DateTime.now().millisecondsSinceEpoch}',
        type: normalizedType,
        materialId: materialId,
        materialSku: materialSku,
        materialName: materialName,
        locationId: locationId,
        quantityDelta: (normalizedType == 'ISSUE' || normalizedType == 'SCRAP')
            ? -quantityDelta.abs()
            : quantityDelta,
        balanceBefore: currentQty,
        balanceAfter: newCurrent,
        orderId: orderId,
        processId: processId,
        performedByUid: performedByUid,
        performedByName: performedByName,
        referenceNumber: referenceNumber,
        notes: notes,
        unit: unit,
        unitScale: unitScale,
      );
      transaction.set(txRef, txModel.toMap());

      // 2. Write updated atomic balance
      final updatedBalance = StockBalanceModel(
        id: balanceLocId,
        materialId: materialId,
        materialSku: materialSku,
        materialName: materialName,
        locationId: locationId,
        locationName: locationName,
        currentQuantity: newCurrent,
        allocatedQuantity: newAllocated,
        availableQuantity: newAvailable,
        unit: unit,
        unitScale: unitScale,
        minimumStock: minStock,
      );
      transaction.set(balanceRef, updatedBalance.toMap());

      // 3. Sync denormalized quantity on Material Master
      transaction.update(materialRef, {
        'quantity': unitScale > 1 ? (newCurrent / unitScale) : newCurrent.toDouble(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return txRef.id;
    });
  }

  // ==========================================
  // 4. LEGACY / BACKWARD COMPATIBILITY
  // ==========================================

  /// Real-time stream of materials in [orgId] for legacy InventoryItem callers.
  Stream<List<InventoryItem>> getInventoryStream(String orgId) {
    return firestore
        .collection(FirestorePaths.materialsCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InventoryItem.fromFirestore(doc))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  /// Adds a new material/inventory item (legacy).
  Future<void> addInventoryItem(String orgId, InventoryItem item) async {
    try {
      final material = MaterialModel(
        id: item.id.isEmpty ? firestore.collection(FirestorePaths.materialsCollection(orgId)).doc().id : item.id,
        sku: item.sku,
        name: item.name,
        category: item.category,
        unit: item.unit,
        unitScale: (item.unit.toLowerCase() == 'kg' || item.unit.toLowerCase() == 'meter') ? 1000 : 1,
        minimumStock: (item.minStockLevel * ((item.unit.toLowerCase() == 'kg' || item.unit.toLowerCase() == 'meter') ? 1000 : 1)).round(),
        defaultLocation: item.location,
      );

      final initialBaseUnits = (item.quantity * material.unitScale).round();
      await createMaterial(orgId: orgId, material: material, initialQuantity: initialBaseUnits);
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create inventory item: ${e.message}', code: e.code);
    }
  }

  /// Updates an existing inventory item (legacy).
  Future<void> updateInventoryItem(String orgId, InventoryItem item) async {
    try {
      await firestore
          .collection(FirestorePaths.materialsCollection(orgId))
          .doc(item.id)
          .update(item.toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update inventory item: ${e.message}', code: e.code);
    }
  }

  /// Quick adjustment of stock (+/- delta) with atomic ledger tracking.
  Future<void> adjustStock({
    required String orgId,
    required String itemId,
    required double delta,
    String? workOrder,
  }) async {
    try {
      final docSnap = await firestore
          .collection(FirestorePaths.materialsCollection(orgId))
          .doc(itemId)
          .get();

      if (!docSnap.exists) {
        throw const DatabaseException('Material not found for stock adjustment.');
      }

      final mat = MaterialModel.fromFirestore(docSnap);
      final deltaBaseUnits = (delta.abs() * mat.unitScale).round();
      final txType = delta >= 0 ? 'RECEIPT' : 'ISSUE';

      await recordTransaction(
        orgId: orgId,
        materialId: mat.id,
        materialSku: mat.sku,
        materialName: mat.name,
        type: txType,
        quantityDelta: delta >= 0 ? deltaBaseUnits : -deltaBaseUnits,
        performedByUid: 'operator',
        performedByName: 'Shop Floor Worker',
        orderId: workOrder,
        notes: workOrder != null && workOrder.isNotEmpty
            ? 'Adjusted for $workOrder'
            : 'Manual stock adjustment',
        unit: mat.unit,
        unitScale: mat.unitScale,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to adjust stock: ${e.message}', code: e.code);
    }
  }

  /// Deletes an inventory item.
  Future<void> deleteInventoryItem(String orgId, String itemId) async {
    try {
      await firestore
          .collection(FirestorePaths.materialsCollection(orgId))
          .doc(itemId)
          .delete();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to delete inventory item: ${e.message}', code: e.code);
    }
  }
}
