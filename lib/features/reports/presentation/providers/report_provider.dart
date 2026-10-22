import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:unity/features/process_queries/presentation/providers/query_providers.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';

/// Executive KPI summary model for live manufacturing operations dashboard.
class ExecutiveKpiSummary {
  final int totalEmployees;
  final int activeEmployees;
  final int totalInventoryItems;
  final int lowStockAlerts;
  final int activeOrders;
  final int completedOrders;
  final int openQueries;

  const ExecutiveKpiSummary({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.totalInventoryItems,
    required this.lowStockAlerts,
    required this.activeOrders,
    required this.completedOrders,
    required this.openQueries,
  });
}

/// Provider aggregating real-time facility KPIs for executive dashboards.
final executiveKpiProvider = Provider<ExecutiveKpiSummary>((ref) {
  final employees = ref.watch(employeesStreamProvider).value ?? [];
  final balances = ref.watch(stockBalancesStreamProvider).value ?? [];
  final orders = ref.watch(productionOrdersStreamProvider).value ?? [];
  final queries = ref.watch(queriesStreamProvider).value ?? [];

  return ExecutiveKpiSummary(
    totalEmployees: employees.length,
    activeEmployees: employees.where((e) => e.isActive).length,
    totalInventoryItems: balances.length,
    lowStockAlerts: balances.where((b) => b.isLowStock).length,
    activeOrders: orders.where((o) => o.isInProduction).length,
    completedOrders: orders.where((o) => o.isCompleted).length,
    openQueries: queries.where((q) => !q.isResolved).length,
  );
});
