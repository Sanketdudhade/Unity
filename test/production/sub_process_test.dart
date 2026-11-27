import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/sub_process_model.dart';

void main() {
  group('SubProcessModel Tests', () {
    test('SubProcessModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 11, 23, 10, 30);
      final sp = SubProcessModel(
        id: 'sp_101',
        orderId: 'WO-861853',
        processId: 'proc_4',
        stageSequence: 4,
        stageName: 'M&G (Milling & Grinding)',
        title: 'Rough Milling',
        description: 'Milling top and bottom faces to ±0.05mm',
        assignedEmployeeUid: 'emp_001',
        assignedEmployeeName: 'John Doe',
        status: 'ASSIGNED',
        targetQty: 100,
        completedQty: 0,
        createdAt: now,
      );

      expect(sp.isNotStarted, isFalse);
      expect(sp.isInProgress, isFalse);
      expect(sp.isCompleted, isFalse);
      expect(sp.isAssigned, isTrue);

      final map = sp.toMap();
      expect(map['id'], 'sp_101');
      expect(map['title'], 'Rough Milling');
      expect(map['assignedEmployeeUid'], 'emp_001');
      expect(map['status'], 'ASSIGNED');

      final fromMap = SubProcessModel.fromMap(map);
      expect(fromMap.id, sp.id);
      expect(fromMap.title, sp.title);
      expect(fromMap.assignedEmployeeUid, sp.assignedEmployeeUid);
      expect(fromMap.assignedEmployeeName, sp.assignedEmployeeName);
      expect(fromMap.status, 'ASSIGNED');
    });

    test('Status transitions and copyWith work as expected', () {
      final sp = SubProcessModel(
        id: 'sp_102',
        title: 'Surface Grinding',
        status: 'NOT_STARTED',
      );

      expect(sp.isNotStarted, isTrue);

      final inProgress = sp.copyWith(
        status: 'IN_PROGRESS',
        startedAt: DateTime.now(),
      );
      expect(inProgress.isInProgress, isTrue);
      expect(inProgress.isNotStarted, isFalse);
      expect(inProgress.startedAt, isNotNull);

      final completed = inProgress.copyWith(
        status: 'COMPLETED',
        completedAt: DateTime.now(),
      );
      expect(completed.isCompleted, isTrue);
      expect(completed.isInProgress, isFalse);
      expect(completed.completedAt, isNotNull);
    });

    test('OrderProcessModel correctly identifies stages 4 to 11 for sub-processes', () {
      final step1 = OrderProcessModel(
        id: 'p1',
        templateStepId: 't1',
        name: 'BOM',
        sequence: 1,
        targetQty: 100,
      );
      expect(step1.allowsSubProcesses, isFalse);

      final step3 = OrderProcessModel(
        id: 'p3',
        templateStepId: 't3',
        name: 'Raw Material',
        sequence: 3,
        targetQty: 100,
      );
      expect(step3.allowsSubProcesses, isFalse);

      for (int seq = 4; seq <= 11; seq++) {
        final stage = OrderProcessModel(
          id: 'p$seq',
          templateStepId: 't$seq',
          name: 'Stage $seq',
          sequence: seq,
          targetQty: 100,
        );
        expect(stage.allowsSubProcesses, isTrue, reason: 'Sequence $seq should allow sub-processes');
      }

      final step12 = OrderProcessModel(
        id: 'p12',
        templateStepId: 't12',
        name: 'F.ASY',
        sequence: 12,
        targetQty: 100,
      );
      expect(step12.allowsSubProcesses, isFalse);
    });

    test('OrderProcessModel embeds subProcesses in toMap and fromMap', () {
      final subList = [
        const SubProcessModel(id: 'sp_1', title: 'Rough Milling', status: 'IN_PROGRESS'),
        const SubProcessModel(id: 'sp_2', title: 'Surface Grinding', status: 'COMPLETED'),
      ];

      final stage = OrderProcessModel(
        id: 'p4',
        templateStepId: 't4',
        name: 'M&G',
        sequence: 4,
        targetQty: 100,
        subProcesses: subList,
      );

      final map = stage.toMap();
      expect(map['subProcesses'], isA<List>());
      expect((map['subProcesses'] as List).length, 2);

      final reconstructed = OrderProcessModel.fromMap('p4', map);
      expect(reconstructed.subProcesses.length, 2);
      expect(reconstructed.subProcesses[0].title, 'Rough Milling');
      expect(reconstructed.subProcesses[0].isInProgress, isTrue);
      expect(reconstructed.subProcesses[1].title, 'Surface Grinding');
      expect(reconstructed.subProcesses[1].isCompleted, isTrue);
    });
  });
}
