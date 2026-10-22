import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';

/// Repository for managing shop-floor operations, assigned tasks, and status updates.
class TaskRepository {
  final FirebaseFirestore firestore;

  TaskRepository({required this.firestore});

  /// Real-time stream of all process tasks in the organization.
  Stream<List<ProcessTask>> getTasksStream(String orgId) {
    return firestore
        .collection(FirestorePaths.processTasksCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProcessTask.fromFirestore(doc))
          .toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));
    });
  }

  /// Updates task progress / state ('in_progress', 'paused', 'completed', 'pending').
  Future<void> updateTaskStatus({
    required String orgId,
    required String taskId,
    required String newStatus,
    String? workerName,
    String? notes,
  }) async {
    try {
      final taskDoc = firestore
          .collection(FirestorePaths.processTasksCollection(orgId))
          .doc(taskId);

      await taskDoc.update({
        'status': newStatus.toLowerCase(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log status update history in status_updates collection
      await firestore.collection(FirestorePaths.statusUpdatesCollection(orgId)).add({
        'taskId': taskId,
        'newStatus': newStatus.toLowerCase(),
        'workerName': workerName ?? 'Worker',
        'notes': notes ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update task: ${e.message}', code: e.code);
    }
  }

  /// Creates a new shop-floor task.
  Future<void> createTask(String orgId, ProcessTask task) async {
    try {
      final collection = firestore.collection(FirestorePaths.processTasksCollection(orgId));
      await collection.add(task.toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create task: ${e.message}', code: e.code);
    }
  }
}
