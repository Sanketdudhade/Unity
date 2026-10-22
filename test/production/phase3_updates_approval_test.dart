import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/process_update_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';

void main() {
  group('Phase 3: ProcessUpdateModel Serialization & Validation', () {
    test('ProcessUpdateModel parses valid map correctly with all fields', () {
      final now = DateTime(2026, 10, 15, 14, 30);
      final rawData = {
        'actorUid': 'emp_007',
        'actorName': 'Suresh Patel',
        'deltaCompletedQty': 45,
        'hoursSpent': 3.5,
        'blockerReason': 'Extrusion nozzle temperature fluctuation',
        'notes': 'Completed batch A with stable calibration',
        'attachmentRefs': ['gs://unity-c5e69.appspot.com/reports/batch_a.pdf'],
        'createdAt': Timestamp.fromDate(now),
      };

      final update = ProcessUpdateModel.fromMap('upd_101', rawData);

      expect(update.id, equals('upd_101'));
      expect(update.actorUid, equals('emp_007'));
      expect(update.actorName, equals('Suresh Patel'));
      expect(update.deltaCompletedQty, equals(45));
      expect(update.hoursSpent, equals(3.5));
      expect(update.blockerReason, equals('Extrusion nozzle temperature fluctuation'));
      expect(update.notes, equals('Completed batch A with stable calibration'));
      expect(update.attachmentRefs.length, equals(1));
      expect(update.attachmentRefs.first, contains('batch_a.pdf'));
      expect(update.createdAt, equals(now));
      expect(update.hasBlocker, isTrue);
    });

    test('ProcessUpdateModel handles fallback defaults when optional fields are omitted', () {
      final rawData = <String, dynamic>{
        'actorUid': 'emp_008',
      };

      final update = ProcessUpdateModel.fromMap('upd_102', rawData);

      expect(update.id, equals('upd_102'));
      expect(update.actorUid, equals('emp_008'));
      expect(update.actorName, equals('Operator'));
      expect(update.deltaCompletedQty, equals(0));
      expect(update.hoursSpent, isNull);
      expect(update.blockerReason, isNull);
      expect(update.notes, equals(''));
      expect(update.attachmentRefs, isEmpty);
      expect(update.createdAt, isNull);
      expect(update.hasBlocker, isFalse);
    });

    test('ProcessUpdateModel serializes toMap correctly for Firestore transmission', () {
      final now = DateTime(2026, 10, 15, 10, 0);
      final update = ProcessUpdateModel(
        id: 'upd_103',
        actorUid: 'emp_009',
        actorName: 'Ramesh Sharma',
        deltaCompletedQty: 120,
        hoursSpent: 5.0,
        blockerReason: null,
        notes: 'Shift completed without interruptions  ',
        createdAt: now,
      );

      final map = update.toMap();

      expect(map['actorUid'], equals('emp_009'));
      expect(map['actorName'], equals('Ramesh Sharma'));
      expect(map['deltaCompletedQty'], equals(120));
      expect(map['hoursSpent'], equals(5.0));
      expect(map['blockerReason'], isNull);
      expect(map['notes'], equals('Shift completed without interruptions')); // trimmed
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), equals(now));
    });
  });

  group('Phase 3: Station Progress & Daily Output Calculations', () {
    test('Calculates progress percentage accurately across stage execution', () {
      const stage = OrderProcessModel(
        id: 'proc_01',
        templateStepId: 'step_laser_cutting',
        name: 'Laser Cutting',
        sequence: 1,
        targetQty: 500,
        completedQty: 250,
      );

      expect(stage.progressPercentage, equals(0.50));
      expect(stage.targetQty - stage.completedQty, equals(250));
    });

    test('Clamps progress percentage cleanly between 0.0 and 1.0 even with delta surplus', () {
      const stageZero = OrderProcessModel(
        id: 'proc_02',
        templateStepId: 'step_stamping',
        name: 'Sheet Stamping',
        sequence: 2,
        targetQty: 100,
        completedQty: 0,
      );
      expect(stageZero.progressPercentage, equals(0.0));

      const stageSurplus = OrderProcessModel(
        id: 'proc_03',
        templateStepId: 'step_stamping',
        name: 'Sheet Stamping',
        sequence: 2,
        targetQty: 100,
        completedQty: 130, // Operator logged 30 units extra scrap margin
      );
      expect(stageSurplus.progressPercentage, equals(1.0));
    });

    test('Progress percentage gracefully returns 0.0 when targetQty is 0 or negative', () {
      const stageZeroTarget = OrderProcessModel(
        id: 'proc_04',
        templateStepId: 'step_qc',
        name: 'Quality Inspection',
        sequence: 16,
        targetQty: 0,
        completedQty: 10,
      );
      expect(stageZeroTarget.progressPercentage, equals(0.0));
    });
  });

  group('Phase 3: Stage Completion, Blocker & Supervisor Approval Flow', () {
    test('OrderProcessModel status transitions detect review and blocked states', () {
      const stageInProgress = OrderProcessModel(
        id: 'proc_10',
        templateStepId: 'step_welding',
        name: 'MIG Welding',
        sequence: 5,
        targetQty: 200,
        completedQty: 120,
        status: 'IN_PROGRESS',
      );
      expect(stageInProgress.isInProgress, isTrue);
      expect(stageInProgress.isBlocked, isFalse);
      expect(stageInProgress.isPendingApproval, isFalse);

      const stageBlocked = OrderProcessModel(
        id: 'proc_11',
        templateStepId: 'step_welding',
        name: 'MIG Welding',
        sequence: 5,
        targetQty: 200,
        completedQty: 120,
        status: 'BLOCKED',
      );
      expect(stageBlocked.isBlocked, isTrue);
      expect(stageBlocked.isInProgress, isFalse);

      const stagePendingApproval = OrderProcessModel(
        id: 'proc_12',
        templateStepId: 'step_welding',
        name: 'MIG Welding',
        sequence: 5,
        targetQty: 200,
        completedQty: 200,
        status: 'PENDING_APPROVAL',
      );
      expect(stagePendingApproval.isPendingApproval, isTrue);
      expect(stagePendingApproval.isCompleted, isFalse);
    });

    test('Admin approval marks stage COMPLETED with approver audit trail', () {
      final approvalDate = DateTime(2026, 10, 15, 17, 0);
      final approvedStage = OrderProcessModel(
        id: 'proc_13',
        templateStepId: 'step_welding',
        name: 'MIG Welding',
        sequence: 5,
        targetQty: 200,
        completedQty: 200,
        status: 'COMPLETED',
        approvedBy: 'admin_bankar',
        completedAt: approvalDate,
      );

      expect(approvedStage.isCompleted, isTrue);
      expect(approvedStage.approvedBy, equals('admin_bankar'));
      expect(approvedStage.completedAt, equals(approvalDate));
      expect(approvedStage.progressPercentage, equals(1.0));
    });

    test('Supervisor rework rejection correctly sets REWORK_REQUIRED with non-empty reason', () {
      const reworkStage = OrderProcessModel(
        id: 'proc_14',
        templateStepId: 'step_powder_coating',
        name: 'Powder Coating',
        sequence: 12,
        targetQty: 350,
        completedQty: 300,
        status: 'REWORK_REQUIRED',
        reworkReason: 'Thickness uneven on seam weld edges; re-coat required',
      );

      expect(reworkStage.isReworkRequired, isTrue);
      expect(reworkStage.isCompleted, isFalse);
      expect(reworkStage.reworkReason, contains('Thickness uneven'));
    });

    test('ProductionOrder overall progress calculation accounts for production output', () {
      final now = DateTime(2026, 10, 15);
      final order = ProductionOrder(
        id: 'order_99',
        orderNumber: 'WO-2026-99',
        productName: 'Enclosure Alpha',
        targetQuantity: 100.0,
        completedQuantity: 40.0,
        unit: 'pcs',
        status: 'in_production',
        priority: 'high',
        startDate: now,
      );

      expect(order.progressPercentage, closeTo(0.40, 0.001));
      expect(order.isInProduction, isTrue);
      expect(order.isCompleted, isFalse);
    });
  });
}
