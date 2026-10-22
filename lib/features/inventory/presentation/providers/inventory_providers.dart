import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/data/models/inventory_item_model.dart';
import 'package:unity/features/inventory/data/models/material_model.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/data/models/stock_movement_model.dart';
import 'package:unity/features/inventory/data/repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return InventoryRepository(firestore: firestore);
});

// ==========================================
// PHASE 4 PROVIDERS: MATERIALS, BALANCES, LEDGER
// ==========================================

/// Stream provider for Material Master catalog.
final materialsStreamProvider = StreamProvider<List<MaterialModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getMaterialsStream(orgId);
});

/// Stream provider for live Stock Balances with integer base units.
final stockBalancesStreamProvider = StreamProvider<List<StockBalanceModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getBalancesStream(orgId);
});

/// Stream provider for low-stock inventory alerts.
final lowStockBalancesStreamProvider = StreamProvider<List<StockBalanceModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getLowStockBalancesStream(orgId);
});

/// Stream provider for immutable Inventory Transaction Ledger (optional materialId filter).
final stockTransactionsStreamProvider =
    StreamProvider.family<List<StockTransactionModel>, String?>((ref, materialId) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getTransactionsStream(orgId, materialId: materialId);
});

// ==========================================
// LEGACY BACKWARD-COMPATIBILITY PROVIDERS
// ==========================================

/// Stream provider for all inventory items in current user's organization.
final inventoryStreamProvider = StreamProvider<List<InventoryItem>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getInventoryStream(orgId);
});

/// Total number of inventory items.
final inventoryCountProvider = Provider<int>((ref) {
  final balancesAsync = ref.watch(stockBalancesStreamProvider);
  return balancesAsync.maybeWhen(
    data: (items) => items.length,
    orElse: () => 0,
  );
});

/// Number of low stock alerts.
final lowStockCountProvider = Provider<int>((ref) {
  final lowBalancesAsync = ref.watch(lowStockBalancesStreamProvider);
  return lowBalancesAsync.maybeWhen(
    data: (items) => items.length,
    orElse: () => 0,
  );
});
