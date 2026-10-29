import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/process_queries/presentation/providers/query_providers.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';

/// Navigation tab indices for the Employee Workspace.
enum EmployeeTab {
  overview,      // 0: Terminal Overview & Shift Status
  stationQueue,  // 1: Assigned Manufacturing Stages (17-Stage flow)
  myTasks,       // 2: Assigned Work Orders & Floor Tasks
  materials,     // 3: Log Raw Material Consumption & Stock View
  tickets,       // 4: Shop-Floor Tickets & Maintenance Requests
}

/// Riverpod 3.x Notifier for managing active tab index.
class EmployeeSelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  @override
  set state(int value) => super.state = value;
  void setTab(int index) => state = index;
}

final employeeSelectedTabProvider = NotifierProvider<EmployeeSelectedTabNotifier, int>(
  EmployeeSelectedTabNotifier.new,
);

/// Riverpod 3.x Notifier for filtering employee tasks.
class EmployeeTaskFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  @override
  set state(String value) => super.state = value;
  void setFilter(String filter) => state = filter;
}

final employeeTaskFilterProvider = NotifierProvider<EmployeeTaskFilterNotifier, String>(
  EmployeeTaskFilterNotifier.new,
);

/// Riverpod 3.x Notifier for searching employee tasks.
class EmployeeTaskSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
  void setSearch(String search) => state = search;
}

final employeeTaskSearchProvider = NotifierProvider<EmployeeTaskSearchNotifier, String>(
  EmployeeTaskSearchNotifier.new,
);

/// Riverpod 3.x Notifier for filtering assigned stages.
class EmployeeStageFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  @override
  set state(String value) => super.state = value;
  void setFilter(String filter) => state = filter;
}

final employeeStageFilterProvider = NotifierProvider<EmployeeStageFilterNotifier, String>(
  EmployeeStageFilterNotifier.new,
);

/// Riverpod 3.x Notifier for searching assigned stages.
class EmployeeStageSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  @override
  set state(String value) => super.state = value;
  void setSearch(String search) => state = search;
}

final employeeStageSearchProvider = NotifierProvider<EmployeeStageSearchNotifier, String>(
  EmployeeStageSearchNotifier.new,
);

/// Aggregated performance summary metrics for the logged-in employee.
class EmployeeSummaryMetrics {
  final int assignedStagesCount;
  final int inProgressStagesCount;
  final int activeTasksCount;
  final int pendingOrPausedCount;
  final int completedTasksCount;
  final int openTicketsCount;

  const EmployeeSummaryMetrics({
    required this.assignedStagesCount,
    required this.inProgressStagesCount,
    required this.activeTasksCount,
    required this.pendingOrPausedCount,
    required this.completedTasksCount,
    required this.openTicketsCount,
  });

  const EmployeeSummaryMetrics.zero()
      : assignedStagesCount = 0,
        inProgressStagesCount = 0,
        activeTasksCount = 0,
        pendingOrPausedCount = 0,
        completedTasksCount = 0,
        openTicketsCount = 0;
}

final employeeSummaryMetricsProvider = Provider<EmployeeSummaryMetrics>((ref) {
  final stagesAsync = ref.watch(employeeAssignedProcessesStreamProvider);
  final myTasks = ref.watch(myAssignedTasksProvider);
  final allTasksAsync = ref.watch(tasksStreamProvider);
  final queriesAsync = ref.watch(queriesStreamProvider);
  final user = ref.watch(authStateProvider).user;

  final stages = stagesAsync.value ?? [];
  final allTasks = allTasksAsync.value ?? [];
  final queries = queriesAsync.value ?? [];

  final inProgressStages = stages.where((s) => s.isInProgress).length;
  final activeTasks = myTasks.where((t) => t.isInProgress).length;
  final pendingOrPaused = myTasks.where((t) => t.isPending || t.isPaused).length +
      stages.where((s) => s.status == 'BLOCKED' || s.status == 'REWORK_REQUIRED').length;

  final completedTasks = allTasks.where((t) {
    final uidMatch = user != null && t.assignedToUid.trim() == user.uid.trim();
    final nameMatch = user != null &&
        t.assignedToName.trim().isNotEmpty &&
        t.assignedToName.trim().toLowerCase() == user.fullName.trim().toLowerCase();
    return (uidMatch || nameMatch) && t.isCompleted;
  }).length + stages.where((s) => s.isCompleted).length;

  final myOpenTickets = queries.where((q) {
    final isMine = user != null && q.reportedByUid == user.uid;
    return isMine && !q.isResolved;
  }).length;

  return EmployeeSummaryMetrics(
    assignedStagesCount: stages.length,
    inProgressStagesCount: inProgressStages,
    activeTasksCount: activeTasks,
    pendingOrPausedCount: pendingOrPaused,
    completedTasksCount: completedTasks,
    openTicketsCount: myOpenTickets,
  );
});

/// Filtered list of assigned manufacturing process stages based on search & filter state.
final filteredEmployeeStagesProvider = Provider<List<OrderProcessModel>>((ref) {
  final stagesAsync = ref.watch(employeeAssignedProcessesStreamProvider);
  final filter = ref.watch(employeeStageFilterProvider);
  final search = ref.watch(employeeStageSearchProvider).trim().toLowerCase();

  return stagesAsync.maybeWhen(
    data: (stages) {
      return stages.where((stage) {
        // Status filter
        if (filter != 'All') {
          switch (filter) {
            case 'In Progress':
              if (!stage.isInProgress) return false;
              break;
            case 'Assigned':
              if (stage.status != 'ASSIGNED' && !stage.isNotStarted) return false;
              break;
            case 'Attention / Blocked':
              if (stage.status != 'BLOCKED' && stage.status != 'REWORK_REQUIRED') return false;
              break;
            case 'Completed':
              if (!stage.isCompleted) return false;
              break;
          }
        }

        // Search match
        if (search.isNotEmpty) {
          final nameMatch = stage.name.toLowerCase().contains(search);
          final orderMatch = stage.orderId.toLowerCase().contains(search);
          final statusMatch = stage.status.toLowerCase().contains(search);
          if (!nameMatch && !orderMatch && !statusMatch) return false;
        }

        return true;
      }).toList();
    },
    orElse: () => [],
  );
});

/// Filtered list of tasks assigned to the employee based on search & filter state.
final filteredEmployeeTasksProvider = Provider<List<ProcessTask>>((ref) {
  final tasks = ref.watch(myAssignedTasksProvider);
  final filter = ref.watch(employeeTaskFilterProvider);
  final search = ref.watch(employeeTaskSearchProvider).trim().toLowerCase();

  return tasks.where((task) {
    if (filter != 'All') {
      switch (filter) {
        case 'In Progress':
          if (!task.isInProgress) return false;
          break;
        case 'Pending':
          if (!task.isPending) return false;
          break;
        case 'Paused':
          if (!task.isPaused) return false;
          break;
        case 'Completed':
          if (!task.isCompleted) return false;
          break;
      }
    }

    if (search.isNotEmpty) {
      final titleMatch = task.title.toLowerCase().contains(search);
      final woMatch = task.workOrder.toLowerCase().contains(search);
      final stageMatch = task.stage.toLowerCase().contains(search);
      if (!titleMatch && !woMatch && !stageMatch) return false;
    }

    return true;
  }).toList();
});
