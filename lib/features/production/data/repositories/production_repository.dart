import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/processes/data/models/process_step_model.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/process_update_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';

/// Repository managing production work orders, batches, and snapshotted process stages.
class ProductionRepository {
  final FirebaseFirestore firestore;

  ProductionRepository({required this.firestore});

  /// Real-time stream of all production orders in [orgId].
  Stream<List<ProductionOrder>> getOrdersStream(String orgId) {
    return firestore
        .collection(FirestorePaths.productionOrdersCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductionOrder.fromFirestore(doc))
          .toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));
    });
  }

  /// Real-time stream of all snapshotted process stages for a specific order.
  Stream<List<OrderProcessModel>> getOrderProcessesStream(String orgId, String orderId) {
    return firestore
        .collection(FirestorePaths.orderProcessesCollection(orgId, orderId))
        .orderBy('sequence')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderProcessModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Creates a production order and atomically snapshots template steps into the subcollection.
  Future<String> createOrderWithSnapshottedTemplate({
    required String orgId,
    required ProductionOrder order,
    required List<ProcessStepModel> templateSteps,
    String? assignedEmployeeUid,
    String? assignedEmployeeName,
  }) async {
    try {
      final orderRef = firestore.collection(FirestorePaths.productionOrdersCollection(orgId)).doc();
      final batch = firestore.batch();

      // Write parent order document
      batch.set(orderRef, {
        ...order.toMap(),
        'totalProcesses': templateSteps.length,
        'completedProcesses': 0,
      });

      // Snapshot each step into `productionOrders/{orderId}/processes/{processId}`
      for (int i = 0; i < templateSteps.length; i++) {
        final step = templateSteps[i];
        final processRef = orderRef.collection('processes').doc();

        final isFirst = i == 0 || step.dependsOnStepSequence.isEmpty;
        final isAssigned = isFirst && (assignedEmployeeUid != null && assignedEmployeeUid.isNotEmpty);

        final process = OrderProcessModel(
          id: processRef.id,
          orderId: orderRef.id,
          templateStepId: step.id,
          name: step.name,
          sequence: step.sequence,
          dependsOnStepSequence: step.dependsOnStepSequence,
          assignedEmployeeUid: isFirst ? (assignedEmployeeUid ?? '') : '',
          assignedEmployeeName: isFirst ? (assignedEmployeeName ?? 'Unassigned') : 'Unassigned',
          targetQty: order.targetQuantity.toInt(),
          completedQty: 0,
          status: isAssigned ? 'ASSIGNED' : 'NOT_STARTED',
          dueAt: order.dueDate,
        );

        batch.set(processRef, process.toMap());
      }

      await batch.commit();
      return orderRef.id;
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create order with process snapshot: ${e.message}', code: e.code);
    }
  }

  /// Reassigns an accountable employee to a process stage.
  Future<void> assignEmployeeToProcess({
    required String orgId,
    required String orderId,
    required String processId,
    required String employeeUid,
    required String employeeName,
  }) async {
    try {
      final docRef = firestore
          .collection(FirestorePaths.orderProcessesCollection(orgId, orderId))
          .doc(processId);

      await docRef.update({
        'assignedEmployeeUid': employeeUid,
        'assignedEmployeeName': employeeName,
        'status': 'ASSIGNED',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to assign employee: ${e.message}', code: e.code);
    }
  }

  /// Updates process status with sequential dependency invariant check.
  Future<void> updateProcessStatus({
    required String orgId,
    required String orderId,
    required String processId,
    required String newStatus,
    String? reworkReason,
    String? notes,
  }) async {
    try {
      final processesCol = firestore.collection(FirestorePaths.orderProcessesCollection(orgId, orderId));
      final allProcessesSnap = await processesCol.get();

      final allProcesses = allProcessesSnap.docs
          .map((d) => OrderProcessModel.fromFirestore(d))
          .toList();

      final OrderProcessModel? target = allProcesses.cast<OrderProcessModel?>().firstWhere(
        (p) => p?.id == processId,
        orElse: () => null,
      );

      if (target == null) {
        throw ValidationException(
          'Process stage "$processId" was not found under work order "$orderId".',
        );
      }

      final statusMap = {for (final p in allProcesses) p.sequence: p.status};

      // Sequential lock check: Cannot start if prerequisites are not completed
      if (newStatus == 'IN_PROGRESS' || newStatus == 'ASSIGNED') {
        if (!target.isUnlocked(statusMap)) {
          throw const ValidationException(
            'Cannot advance stage: Prerequisite manufacturing stages have not yet been approved and completed.',
          );
        }
      }

      final updates = <String, dynamic>{
        'status': newStatus.toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'IN_PROGRESS' && target.startedAt == null) {
        updates['startedAt'] = FieldValue.serverTimestamp();
      }
      if (newStatus == 'COMPLETED') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }
      if (reworkReason != null && reworkReason.isNotEmpty) {
        updates['reworkReason'] = reworkReason;
      }
      if (notes != null && notes.isNotEmpty) {
        updates['notes'] = notes;
      }

      await processesCol.doc(processId).update(updates);

      // Recompute completed processes counter on parent order
      if (newStatus == 'COMPLETED') {
        final newlyCompleted = allProcesses.where((p) => p.id == processId || p.isCompleted).length;
        await firestore
            .collection(FirestorePaths.productionOrdersCollection(orgId))
            .doc(orderId)
            .update({
          'completedProcesses': newlyCompleted,
          'status': newlyCompleted >= allProcesses.length ? 'completed' : 'in_production',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update stage: ${e.message}', code: e.code);
    }
  }

  /// Updates status and/or completed quantity of a work order.
  Future<void> updateOrderStatus({
    required String orgId,
    required String orderId,
    required String status,
    double? completedQuantity,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (completedQuantity != null) {
        updates['completedQuantity'] = completedQuantity;
      }

      await firestore
          .collection(FirestorePaths.productionOrdersCollection(orgId))
          .doc(orderId)
          .update(updates);
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update work order: ${e.message}', code: e.code);
    }
  }

  /// Deletes a work order.
  Future<void> deleteOrder(String orgId, String orderId) async {
    try {
      await firestore
          .collection(FirestorePaths.productionOrdersCollection(orgId))
          .doc(orderId)
          .delete();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to delete work order: ${e.message}', code: e.code);
    }
  }

  /// Real-time stream of daily updates logged for a specific process stage.
  Stream<List<ProcessUpdateModel>> getProcessUpdatesStream(
    String orgId,
    String orderId,
    String processId,
  ) {
    return firestore
        .collection(FirestorePaths.processUpdatesCollection(orgId, orderId, processId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => ProcessUpdateModel.fromFirestore(d)).toList());
  }

  /// Logs a daily update, atomically increments stage completed quantity, and optionally transitions status.
  Future<void> logProcessUpdate({
    required String orgId,
    required String orderId,
    required String processId,
    required ProcessUpdateModel update,
    String? transitionStatus,
  }) async {
    try {
      final orderProcessRef = firestore
          .collection(FirestorePaths.orderProcessesCollection(orgId, orderId))
          .doc(processId);
      final updateRef = orderProcessRef.collection('updates').doc();

      final processesCol = firestore.collection(FirestorePaths.orderProcessesCollection(orgId, orderId));
      final allProcessesSnap = await processesCol.get();
      final allProcesses = allProcessesSnap.docs.map((d) => OrderProcessModel.fromFirestore(d)).toList();
      final OrderProcessModel? target = allProcesses.cast<OrderProcessModel?>().firstWhere(
        (p) => p?.id == processId,
        orElse: () => null,
      );
      final statusMap = {for (final p in allProcesses) p.sequence: p.status};

      // Sequential lock check if transitioning to active or completed
      if (transitionStatus != null && target != null) {
        final upper = transitionStatus.toUpperCase();
        if ((upper == 'IN_PROGRESS' || upper == 'PENDING_APPROVAL' || upper == 'COMPLETED') &&
            !target.isUnlocked(statusMap)) {
          throw const ValidationException(
            'Cannot advance stage: Prerequisite manufacturing stages have not yet been approved and completed.',
          );
        }
      }

      final batch = firestore.batch();

      // 1. Insert immutable daily update record
      batch.set(updateRef, update.toMap());

      // 2. Prepare process document updates
      final processUpdates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (update.deltaCompletedQty > 0) {
        processUpdates['completedQty'] = FieldValue.increment(update.deltaCompletedQty);
      }

      if (transitionStatus != null) {
        final upper = transitionStatus.toUpperCase();
        processUpdates['status'] = upper;
        if (upper == 'IN_PROGRESS' && target?.startedAt == null) {
          processUpdates['startedAt'] = FieldValue.serverTimestamp();
        }
        if (upper == 'BLOCKED') {
          processUpdates['reworkReason'] = update.blockerReason ?? 'Station blocked';
        } else if (upper == 'IN_PROGRESS') {
          processUpdates['reworkReason'] = null; // Clear blocker once active again
        }
      }

      if (update.notes.trim().isNotEmpty) {
        processUpdates['notes'] = update.notes.trim();
      }

      batch.update(orderProcessRef, processUpdates);

      await batch.commit();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to log process update: ${e.message}', code: e.code);
    }
  }

  /// Approves a process stage (Admin action), advancing it to COMPLETED and unlocking subsequent stages.
  Future<void> approveProcessStage({
    required String orgId,
    required String orderId,
    required String processId,
    required String adminUid,
    required String adminName,
    String? approvalNotes,
  }) async {
    try {
      final processesCol = firestore.collection(FirestorePaths.orderProcessesCollection(orgId, orderId));
      final allProcessesSnap = await processesCol.get();
      final allProcesses = allProcessesSnap.docs.map((d) => OrderProcessModel.fromFirestore(d)).toList();
      final OrderProcessModel? target = allProcesses.cast<OrderProcessModel?>().firstWhere(
        (p) => p?.id == processId,
        orElse: () => null,
      );

      if (target == null) {
        throw ValidationException(
          'Process stage "$processId" was not found under work order "$orderId".',
        );
      }

      final statusMap = {for (final p in allProcesses) p.sequence: p.status};

      if (!target.isUnlocked(statusMap)) {
        throw const ValidationException(
          'Cannot approve stage: Prerequisite manufacturing stages are incomplete.',
        );
      }

      final batch = firestore.batch();
      final processRef = processesCol.doc(processId);

      batch.update(processRef, {
        'status': 'COMPLETED',
        'approvedByUid': adminUid,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reworkReason': null,
      });

      // Log an approval update into updates subcollection
      final updateRef = processRef.collection('updates').doc();
      batch.set(updateRef, {
        'actorUid': adminUid,
        'actorName': adminName,
        'deltaCompletedQty': 0,
        'notes': approvalNotes ?? 'Stage approved and signed off by supervisor.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Recalculate completed stages on parent order
      final newlyCompleted = allProcesses.where((p) => p.id == processId || p.isCompleted).length;
      final orderRef = firestore.collection(FirestorePaths.productionOrdersCollection(orgId)).doc(orderId);
      batch.update(orderRef, {
        'completedProcesses': newlyCompleted,
        'status': newlyCompleted >= allProcesses.length ? 'completed' : 'in_production',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to approve stage: ${e.message}', code: e.code);
    }
  }

  /// Rejects a process stage for rework (Admin action), requiring corrections before completion.
  Future<void> rejectProcessStageForRework({
    required String orgId,
    required String orderId,
    required String processId,
    required String adminUid,
    required String adminName,
    required String reworkReason,
  }) async {
    try {
      final processRef = firestore
          .collection(FirestorePaths.orderProcessesCollection(orgId, orderId))
          .doc(processId);

      final batch = firestore.batch();

      batch.update(processRef, {
        'status': 'REWORK_REQUIRED',
        'reworkReason': reworkReason.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log rework request in updates subcollection
      final updateRef = processRef.collection('updates').doc();
      batch.set(updateRef, {
        'actorUid': adminUid,
        'actorName': adminName,
        'deltaCompletedQty': 0,
        'blockerReason': reworkReason.trim(),
        'notes': 'Rework required: ${reworkReason.trim()}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to reject stage for rework: ${e.message}', code: e.code);
    }
  }

  /// Real-time stream of all processes assigned to a specific employee across active orders.
  Stream<List<OrderProcessModel>> getAssignedProcessesForEmployee(String orgId, String employeeUid) {
    return firestore
        .collection(FirestorePaths.productionOrdersCollection(orgId))
        .where('status', whereIn: ['in_production', 'scheduled'])
        .snapshots()
        .asyncMap((ordersSnap) async {
          final List<OrderProcessModel> assigned = [];
          for (final orderDoc in ordersSnap.docs) {
            final procSnap = await orderDoc.reference
                .collection('processes')
                .where('assignedEmployeeUid', isEqualTo: employeeUid)
                .get();

            for (final pDoc in procSnap.docs) {
              final p = OrderProcessModel.fromFirestore(pDoc);
              assigned.add(p.orderId.isNotEmpty ? p : p.copyWith(orderId: orderDoc.id));
            }
          }
          assigned.sort((a, b) => a.sequence.compareTo(b.sequence));
          return assigned;
        });
  }
}
