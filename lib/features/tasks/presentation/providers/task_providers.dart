import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/data/repositories/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return TaskRepository(firestore: firestore);
});

/// Stream of all organization tasks.
final tasksStreamProvider = StreamProvider<List<ProcessTask>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(taskRepositoryProvider);
  return repository.getTasksStream(orgId);
});

/// Tasks currently assigned to or worked on by this worker.
final myAssignedTasksProvider = Provider<List<ProcessTask>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  final user = ref.watch(authStateProvider).user;

  return tasksAsync.maybeWhen(
    data: (tasks) => tasks.where((t) {
      final isMine = t.assignedToUid == user?.uid || t.assignedToUid.isEmpty;
      return isMine && (t.isInProgress || t.isPending);
    }).toList(),
    orElse: () => [],
  );
});

/// Tasks scheduled for today or active.
final todaysScheduleTasksProvider = Provider<List<ProcessTask>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);

  return tasksAsync.maybeWhen(
    data: (tasks) => tasks.where((t) => !t.isCompleted).toList(),
    orElse: () => [],
  );
});

/// Pending or Paused tasks needing resumption or attention.
final pendingOrPausedTasksProvider = Provider<List<ProcessTask>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);

  return tasksAsync.maybeWhen(
    data: (tasks) => tasks.where((t) => t.isPending || t.isPaused).toList(),
    orElse: () => [],
  );
});
