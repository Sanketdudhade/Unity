import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/jobwork_po_model.dart';
import 'package:unity/features/production/data/models/process_update_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/data/repositories/production_repository.dart';

final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ProductionRepository(firestore: firestore);
});

/// Real-time stream of all production orders in the organization.
final productionOrdersStreamProvider = StreamProvider<List<ProductionOrder>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(productionRepositoryProvider);
  return repository.getOrdersStream(orgId);
});

/// Count of active (in production or scheduled) work orders.
final activeProductionOrdersCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(productionOrdersStreamProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.where((o) => !o.isCompleted).length,
    orElse: () => 0,
  );
});

/// Count of completed work orders.
final completedProductionOrdersCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(productionOrdersStreamProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.where((o) => o.isCompleted).length,
    orElse: () => 0,
  );
});

/// Real-time stream of all snapshotted processes for a single order.
final orderProcessesStreamProvider = StreamProvider.family<List<OrderProcessModel>, String>((ref, orderId) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty || orderId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(productionRepositoryProvider);
  return repository.getOrderProcessesStream(orgId, orderId);
});

/// Real-time stream of daily update logs for an order stage.
final processUpdatesStreamProvider = StreamProvider.family<List<ProcessUpdateModel>, ({String orderId, String processId})>((ref, arg) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty || arg.orderId.isEmpty || arg.processId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(productionRepositoryProvider);
  return repository.getProcessUpdatesStream(orgId, arg.orderId, arg.processId);
});

/// Real-time stream of all processes assigned to the currently logged-in employee across active orders.
final employeeAssignedProcessesStreamProvider = StreamProvider<List<OrderProcessModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.user;
  final orgId = user?.organizationId;
  final uid = user?.uid;

  if (orgId == null || orgId.isEmpty || uid == null || uid.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(productionRepositoryProvider);
  return repository.getAssignedProcessesForEmployee(orgId, uid, user?.fullName);
});

/// Real-time stream of all process stages across all active orders in the organization.
final allActiveProcessesStreamProvider = StreamProvider<List<OrderProcessModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.user;
  final orgId = user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(productionRepositoryProvider);
  return repository.getAllActiveProcessesStream(orgId);
});

/// Real-time stream of all Jobwork Purchase Orders for an order.
final jobworkPosStreamProvider = StreamProvider.family<List<JobworkPoModel>, String>((ref, orderId) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty || orderId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(productionRepositoryProvider);
  return repository.streamJobworkPos(orgId, orderId);
});

