import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';

void main() {
  group('ProcessTask Model Tests', () {
    test('Correctly computes boolean status helper getters', () {
      const taskInProgress = ProcessTask(
        id: 'task_1',
        title: 'Laser Cutting',
        stage: 'Cutting',
        workOrder: 'WO-101',
        assignedToUid: 'u_1',
        assignedToName: 'John',
        status: 'in_progress',
        priority: 'high',
      );

      const taskPending = ProcessTask(
        id: 'task_2',
        title: 'CNC Milling',
        stage: 'Machining',
        workOrder: 'WO-102',
        assignedToUid: 'u_2',
        assignedToName: 'Alice',
        status: 'pending',
        priority: 'urgent',
      );

      const taskPaused = ProcessTask(
        id: 'task_3',
        title: 'Welding',
        stage: 'Assembly',
        workOrder: 'WO-103',
        assignedToUid: 'u_3',
        assignedToName: 'Bob',
        status: 'paused',
        priority: 'normal',
      );

      const taskCompleted = ProcessTask(
        id: 'task_4',
        title: 'Quality Check',
        stage: 'Inspection',
        workOrder: 'WO-104',
        assignedToUid: 'u_4',
        assignedToName: 'Dan',
        status: 'completed',
        priority: 'normal',
      );

      expect(taskInProgress.isInProgress, isTrue);
      expect(taskInProgress.isPending, isFalse);

      expect(taskPending.isPending, isTrue);
      expect(taskPending.isInProgress, isFalse);

      expect(taskPaused.isPaused, isTrue);
      expect(taskPaused.isInProgress, isFalse);

      expect(taskCompleted.isCompleted, isTrue);
      expect(taskCompleted.isInProgress, isFalse);
    });

    test('Serializes to map suitable for Firestore', () {
      const task = ProcessTask(
        id: 'task_100',
        title: 'Milling Component A',
        stage: 'CNC Shop',
        workOrder: 'WO-2026-999',
        assignedToUid: 'worker_1',
        assignedToName: 'Sanket',
        status: 'in_progress',
        priority: 'urgent',
        notes: 'Check cutting tool wear',
      );

      final map = task.toMap();
      expect(map['title'], 'Milling Component A');
      expect(map['stage'], 'CNC Shop');
      expect(map['workOrder'], 'WO-2026-999');
      expect(map['assignedToUid'], 'worker_1');
      expect(map['assignedToName'], 'Sanket');
      expect(map['status'], 'in_progress');
      expect(map['priority'], 'urgent');
      expect(map['notes'], 'Check cutting tool wear');
      expect(map.containsKey('updatedAt'), isTrue);
    });
  });
}
