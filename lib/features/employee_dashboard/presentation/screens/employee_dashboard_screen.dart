import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employee_dashboard/presentation/providers/employee_dashboard_provider.dart';
import 'package:unity/features/employee_dashboard/presentation/shell/employee_shell.dart';
import 'package:unity/features/employee_dashboard/presentation/views/employee_materials_view.dart';
import 'package:unity/features/employee_dashboard/presentation/views/employee_overview_view.dart';
import 'package:unity/features/employee_dashboard/presentation/views/employee_station_queue_view.dart';
import 'package:unity/features/employee_dashboard/presentation/views/employee_tasks_view.dart';
import 'package:unity/features/employee_dashboard/presentation/views/employee_tickets_view.dart';

/// Modern Enterprise Employee Workspace & Station Terminal.
/// Conforms to UNITY Redesign Spec Section 3, 4, 5, 6, and 7.
/// Fully responsive on Android smartphones, tablets, and Windows desktop.
class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading employee terminal...'),
      );
    }

    final activeTab = ref.watch(employeeSelectedTabProvider);

    return EmployeeShell(
      child: IndexedStack(
        index: activeTab.clamp(0, 4),
        children: [
          IgnorePointer(
            ignoring: activeTab != 0,
            child: const EmployeeOverviewView(),
          ),
          IgnorePointer(
            ignoring: activeTab != 1,
            child: const EmployeeStationQueueView(),
          ),
          IgnorePointer(
            ignoring: activeTab != 2,
            child: const EmployeeTasksView(),
          ),
          IgnorePointer(
            ignoring: activeTab != 3,
            child: const EmployeeMaterialsView(),
          ),
          IgnorePointer(
            ignoring: activeTab != 4,
            child: const EmployeeTicketsView(),
          ),
        ],
      ),
    );
  }
}
