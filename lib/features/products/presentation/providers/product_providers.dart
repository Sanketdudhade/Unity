import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/products/data/repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ProductRepository(firestore: firestore);
});

/// Stream of all products in current organization.
final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductsStream(orgId);
});

/// Only active products available for ordering.
final activeProductsProvider = Provider<List<ProductModel>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  return productsAsync.maybeWhen(
    data: (products) => products.where((p) => p.isActive).toList(),
    orElse: () => [],
  );
});

/// Total number of registered products.
final productCountProvider = Provider<int>((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  return productsAsync.maybeWhen(
    data: (products) => products.length,
    orElse: () => 0,
  );
});
