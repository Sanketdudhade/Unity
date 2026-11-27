import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/processes/data/models/process_step_model.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/sub_process_model.dart';
import 'package:unity/features/production/data/models/jobwork_po_model.dart';
import 'package:unity/features/production/data/models/process_update_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/data/models/production_workflows.dart';

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
  /// Supports assigning accountable employees to each stage individually.
  Future<String> createOrderWithSnapshottedTemplate({
    required String orgId,
    required ProductionOrder order,
    required List<ProcessStepModel> templateSteps,
    String? assignedEmployeeUid,
    String? assignedEmployeeName,
    Map<int, ({String uid, String name})>? stageAssignmentsBySequence,
  }) async {
    try {
      final effectiveSteps = templateSteps.isNotEmpty
          ? templateSteps
          : ProductionWorkflows.getStages(order.productionType);

      final orderRef = firestore.collection(FirestorePaths.productionOrdersCollection(orgId)).doc();
      final batch = firestore.batch();

      // Write parent order document
      batch.set(orderRef, {
        ...order.toMap(),
        'totalProcesses': effectiveSteps.length,
        'completedProcesses': 0,
      });

      // Snapshot each step into `productionOrders/{orderId}/processes/{processId}`
      for (int i = 0; i < effectiveSteps.length; i++) {
        final step = effectiveSteps[i];
        final processRef = orderRef.collection('processes').doc();

        final isFirst = i == 0 || step.dependsOnStepSequence.isEmpty;
        final stageAssignment = stageAssignmentsBySequence?[step.sequence];

        final String stepEmpUid;
        final String stepEmpName;

        if (stageAssignment != null && stageAssignment.uid.isNotEmpty) {
          stepEmpUid = stageAssignment.uid.trim();
          stepEmpName = stageAssignment.name.trim();
        } else if (isFirst && assignedEmployeeUid != null && assignedEmployeeUid.isNotEmpty) {
          stepEmpUid = assignedEmployeeUid.trim();
          stepEmpName = (assignedEmployeeName ?? 'Unassigned').trim();
        } else {
          stepEmpUid = '';
          stepEmpName = 'Unassigned';
        }

        final isAssigned = stepEmpUid.isNotEmpty;

        final process = OrderProcessModel(
          id: processRef.id,
          orderId: orderRef.id,
          templateStepId: step.id,
          name: step.name,
          sequence: step.sequence,
          dependsOnStepSequence: step.dependsOnStepSequence,
          assignedEmployeeUid: stepEmpUid,
          assignedEmployeeName: stepEmpName,
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

  /// Snapshots stages for an existing order if it currently has none.
  Future<void> initializeStagesForOrder({
    required String orgId,
    required String orderId,
    List<ProcessStepModel>? steps,
    Map<int, ({String uid, String name})>? stageAssignmentsBySequence,
  }) async {
    try {
      final orderRef = firestore.collection(FirestorePaths.productionOrdersCollection(orgId)).doc(orderId);
      final orderSnap = await orderRef.get();
      final orderData = orderSnap.data() ?? {};
      final orderProductionType = orderData['productionType'] as String? ?? 'CUTTING';

      final effectiveSteps = (steps != null && steps.isNotEmpty)
          ? steps
          : ProductionWorkflows.getStages(orderProductionType);

      final processesCol = firestore.collection(FirestorePaths.orderProcessesCollection(orgId, orderId));
      final existingSnap = await processesCol.limit(1).get();
      if (existingSnap.docs.isNotEmpty) return; // Already initialized

      final targetQuantity = (orderData['targetQuantity'] as num?)?.toInt() ?? 100;
      final dueDate = (orderData['dueDate'] as Timestamp?)?.toDate();

      final batch = firestore.batch();
      for (int i = 0; i < effectiveSteps.length; i++) {
        final step = effectiveSteps[i];
        final processRef = processesCol.doc();
        final stageAssignment = stageAssignmentsBySequence?[step.sequence];
        final stepEmpUid = stageAssignment?.uid.trim() ?? '';
        final stepEmpName = stageAssignment?.name.trim() ?? (stepEmpUid.isNotEmpty ? 'Assigned' : 'Unassigned');

        final process = OrderProcessModel(
          id: processRef.id,
          orderId: orderId,
          templateStepId: step.id,
          name: step.name,
          sequence: step.sequence,
          dependsOnStepSequence: step.dependsOnStepSequence,
          assignedEmployeeUid: stepEmpUid,
          assignedEmployeeName: stepEmpName,
          targetQty: targetQuantity,
          completedQty: 0,
          status: stepEmpUid.isNotEmpty ? 'ASSIGNED' : 'NOT_STARTED',
          dueAt: dueDate,
        );
        batch.set(processRef, process.toMap());
      }

      batch.update(orderRef, {
        'totalProcesses': effectiveSteps.length,
        'completedProcesses': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to initialize stages for order: ${e.message}', code: e.code);
    }
  }

  /// Completely replaces/resets the workflow stages for an existing order with a selected workflow type.
  Future<void> replaceWorkflowStagesForOrder({
    required String orgId,
    required String orderId,
    required String productionType,
    List<ProcessStepModel>? steps,
    Map<int, ({String uid, String name})>? stageAssignmentsBySequence,
  }) async {
    try {
      final effectiveSteps = (steps != null && steps.isNotEmpty)
          ? steps
          : ProductionWorkflows.getStages(productionType);

      final processesCol = firestore.collection(FirestorePaths.orderProcessesCollection(orgId, orderId));
      final existingDocs = await processesCol.get();

      final orderRef = firestore.collection(FirestorePaths.productionOrdersCollection(orgId)).doc(orderId);
      final orderSnap = await orderRef.get();
      final orderData = orderSnap.data() ?? {};
      final targetQuantity = (orderData['targetQuantity'] as num?)?.toInt() ?? 100;
      final dueDate = (orderData['dueDate'] as Timestamp?)?.toDate();

      final batch = firestore.batch();

      // Delete old processes
      for (final doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }

      // Snapshot new processes
      for (int i = 0; i < effectiveSteps.length; i++) {
        final step = effectiveSteps[i];
        final processRef = processesCol.doc();
        final stageAssignment = stageAssignmentsBySequence?[step.sequence];
        final stepEmpUid = stageAssignment?.uid.trim() ?? '';
        final stepEmpName = stageAssignment?.name.trim() ?? (stepEmpUid.isNotEmpty ? 'Assigned' : 'Unassigned');

        final process = OrderProcessModel(
          id: processRef.id,
          orderId: orderId,
          templateStepId: step.id,
          name: step.name,
          sequence: step.sequence,
          dependsOnStepSequence: step.dependsOnStepSequence,
          assignedEmployeeUid: stepEmpUid,
          assignedEmployeeName: stepEmpName,
          targetQty: targetQuantity,
          completedQty: 0,
          status: stepEmpUid.isNotEmpty ? 'ASSIGNED' : 'NOT_STARTED',
          dueAt: dueDate,
        );
        batch.set(processRef, process.toMap());
      }

      batch.update(orderRef, {
        'productionType': productionType,
        'totalProcesses': effectiveSteps.length,
        'completedProcesses': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to replace workflow stages for order: ${e.message}', code: e.code);
    }
  }

  /// Updates the allocated BOM inventory items for a specific process stage.
  Future<void> updateProcessAllocatedBomItems({
    required String orgId,
    required String orderId,
    required String processId,
    required List<String> selectedBomItemIds,
  }) async {
    try {
      final docRef = firestore
          .collection(FirestorePaths.orderProcessesCollection(orgId, orderId))
          .doc(processId);
      await docRef.update({
        'selectedBomItemIds': selectedBomItemIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update stage BOM inventory: ${e.message}', code: e.code);
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
      final orderRef = firestore
          .collection(FirestorePaths.productionOrdersCollection(orgId))
          .doc(orderId);

      final currentDoc = await docRef.get();
      final currentStatus = currentDoc.data()?['status'] as String? ?? 'NOT_STARTED';

      final Map<String, dynamic> updates = {
        'assignedEmployeeUid': employeeUid.trim(),
        'assignedEmployeeName': employeeName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (employeeUid.trim().isEmpty) {
        if (currentStatus == 'ASSIGNED') {
          updates['status'] = 'NOT_STARTED';
        }
      } else {
        if (currentStatus == 'NOT_STARTED') {
          updates['status'] = 'ASSIGNED';
        }
      }

      final batch = firestore.batch();
      batch.update(docRef, updates);

      // Touch parent order updatedAt to trigger real-time listeners across employee dashboards
      batch.update(orderRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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

      final batch = firestore.batch();
      batch.update(processesCol.doc(processId), updates);

      // Recompute completed processes counter on parent order and touch parent updatedAt
      final orderRef = firestore.collection(FirestorePaths.productionOrdersCollection(orgId)).doc(orderId);
      final newlyCompleted = allProcesses.where((p) => p.id == processId ? newStatus == 'COMPLETED' : (p.id != processId && p.isCompleted)).length;
      final orderUpdates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'completedProcesses': newlyCompleted,
      };
      if (newlyCompleted >= allProcesses.length && allProcesses.isNotEmpty) {
        orderUpdates['status'] = 'completed';
      } else if (newlyCompleted > 0 || newStatus == 'IN_PROGRESS') {
        orderUpdates['status'] = 'in_production';
      }
      batch.update(orderRef, orderUpdates);

      await batch.commit();
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
  Stream<List<OrderProcessModel>> getAssignedProcessesForEmployee(
    String orgId,
    String employeeUid, [
    String? employeeName,
  ]) {
    final cleanUid = employeeUid.trim();
    final cleanName = (employeeName ?? '').trim();

    return firestore
        .collection(FirestorePaths.productionOrdersCollection(orgId))
        .snapshots()
        .asyncMap((ordersSnap) async {
          final List<OrderProcessModel> assigned = [];
          for (final orderDoc in ordersSnap.docs) {
            final orderData = orderDoc.data();
            final orderStatus = (orderData['status'] as String? ?? '').toLowerCase();
            if (orderStatus == 'completed') continue;

            final procSnap = await orderDoc.reference
                .collection('processes')
                .get();

            for (final pDoc in procSnap.docs) {
              final p = OrderProcessModel.fromFirestore(pDoc);
              final pUid = p.assignedEmployeeUid.trim();
              final pName = p.assignedEmployeeName.trim().toLowerCase();

              final isStageAssigned = (cleanUid.isNotEmpty && pUid == cleanUid) ||
                  (cleanName.isNotEmpty && pName.isNotEmpty && pName == cleanName.toLowerCase());

              final isSubProcessAssigned = p.subProcesses.any((sp) =>
                  (cleanUid.isNotEmpty && sp.assignedEmployeeUid.trim() == cleanUid) ||
                  (cleanName.isNotEmpty &&
                      sp.assignedEmployeeName.trim().isNotEmpty &&
                      sp.assignedEmployeeName.trim().toLowerCase() == cleanName.toLowerCase()));

              if (isStageAssigned || isSubProcessAssigned) {
                assigned.add(p.orderId.isNotEmpty ? p : p.copyWith(orderId: orderDoc.id));
              }
            }
          }
          assigned.sort((a, b) => a.sequence.compareTo(b.sequence));
          return assigned;
        });
  }

  /// Adds a new sub-process under a manufacturing stage (Steps 4 to 11).
  Future<void> addSubProcess({
    required String orgId,
    required String orderId,
    required String processId,
    required SubProcessModel subProcess,
  }) async {
    try {
      final docRef = firestore
          .collection(FirestorePaths.productionOrdersCollection(orgId))
          .doc(orderId)
          .collection('processes')
          .doc(processId);

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final existingList = (data['subProcesses'] as List<dynamic>?)
                ?.map((e) => SubProcessModel.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];
        existingList.add(subProcess);
        tx.update(docRef, {
          'subProcesses': existingList.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to add sub-process: ${e.message}', code: e.code);
    }
  }

  /// Updates status of a sub-process (e.g., 'IN_PROGRESS', 'COMPLETED') by an assigned employee or admin.
  Future<void> updateSubProcessStatus({
    required String orgId,
    required String orderId,
    required String processId,
    required String subProcessId,
    required String newStatus,
  }) async {
    try {
      final docRef = firestore
          .collection(FirestorePaths.productionOrdersCollection(orgId))
          .doc(orderId)
          .collection('processes')
          .doc(processId);

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final existingList = (data['subProcesses'] as List<dynamic>?)
                ?.map((e) => SubProcessModel.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];

        final index = existingList.indexWhere((sp) => sp.id == subProcessId);
        if (index == -1) return;

        final now = DateTime.now();
        final upperStatus = newStatus.toUpperCase();
        final current = existingList[index];

        final updatedSp = current.copyWith(
          status: upperStatus,
          startedAt: (upperStatus == 'IN_PROGRESS' && current.startedAt == null)
              ? now
              : current.startedAt,
          completedAt: (upperStatus == 'COMPLETED') ? now : current.completedAt,
          updatedAt: now,
        );
        existingList[index] = updatedSp;

        // If stage itself is NOT_STARTED and a sub-process starts, optionally advance stage to IN_PROGRESS
        final stageStatus = (data['status'] as String? ?? 'NOT_STARTED').toUpperCase();
        final Map<String, dynamic> updateMap = {
          'subProcesses': existingList.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (upperStatus == 'IN_PROGRESS' && (stageStatus == 'NOT_STARTED' || stageStatus == 'ASSIGNED')) {
          updateMap['status'] = 'IN_PROGRESS';
          if (data['startedAt'] == null) {
            updateMap['startedAt'] = FieldValue.serverTimestamp();
          }
        }

        tx.update(docRef, updateMap);
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update sub-process status: ${e.message}', code: e.code);
    }
  }

  /// Removes a sub-process from a manufacturing stage.
  Future<void> deleteSubProcess({
    required String orgId,
    required String orderId,
    required String processId,
    required String subProcessId,
  }) async {
    try {
      final docRef = firestore
          .collection(FirestorePaths.productionOrdersCollection(orgId))
          .doc(orderId)
          .collection('processes')
          .doc(processId);

      await firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final existingList = (data['subProcesses'] as List<dynamic>?)
                ?.map((e) => SubProcessModel.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [];
        existingList.removeWhere((sp) => sp.id == subProcessId);
        tx.update(docRef, {
          'subProcesses': existingList.map((e) => e.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to delete sub-process: ${e.message}', code: e.code);
    }
  }

  /// Real-time stream of all processes across all active (non-completed) orders in [orgId].
  Stream<List<OrderProcessModel>> getAllActiveProcessesStream(String orgId) {
    return firestore
        .collection(FirestorePaths.productionOrdersCollection(orgId))
        .snapshots()
        .asyncMap((ordersSnap) async {
          final List<OrderProcessModel> allProcesses = [];
          for (final orderDoc in ordersSnap.docs) {
            final orderData = orderDoc.data();
            final orderStatus = (orderData['status'] as String? ?? '').toLowerCase();
            if (orderStatus == 'completed') continue;

            final procSnap = await orderDoc.reference
                .collection('processes')
                .get();

            for (final pDoc in procSnap.docs) {
              final p = OrderProcessModel.fromFirestore(pDoc);
              allProcesses.add(p.orderId.isNotEmpty ? p : p.copyWith(orderId: orderDoc.id));
            }
          }
          allProcesses.sort((a, b) => a.sequence.compareTo(b.sequence));
          return allProcesses;
        });
  }

  // ==================== JOBWORK PURCHASE ORDERS (STAGE 4 M&G) ====================

  /// Stream of all Jobwork Purchase Orders created for an order.
  Stream<List<JobworkPoModel>> streamJobworkPos(String orgId, String orderId) {
    return firestore
        .collection(FirestorePaths.jobworkPosCollection(orgId))
        .where('orderId', isEqualTo: orderId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => JobworkPoModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Saves (creates or updates) an M/G Jobwork Purchase Order.
  Future<String> saveJobworkPo(String orgId, JobworkPoModel po) async {
    try {
      final collectionRef = firestore.collection(FirestorePaths.jobworkPosCollection(orgId));
      final docRef = po.id.isNotEmpty ? collectionRef.doc(po.id) : collectionRef.doc();
      final toSave = po.copyWith(id: docRef.id);
      await docRef.set(toSave.toMap(), SetOptions(merge: true));
      return docRef.id;
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to save Jobwork PO: ${e.message}', code: e.code);
    }
  }

  /// Deletes a Jobwork Purchase Order.
  Future<void> deleteJobworkPo(String orgId, String poId) async {
    try {
      await firestore.doc(FirestorePaths.jobworkPoDoc(orgId, poId)).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to delete Jobwork PO: ${e.message}', code: e.code);
    }
  }
}
