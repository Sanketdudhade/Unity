import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/bom/data/models/product_bom_file_model.dart';
import 'package:unity/features/bom/data/models/product_bom_model.dart';
import 'package:unity/features/bom/data/services/bom_repository.dart';

/// Provider for BomRepository instance.
final bomRepositoryProvider = Provider<BomRepository>((ref) {
  return BomRepository(firestore: FirebaseFirestore.instance);
});

/// Stream of all BOM versions for a given product ID.
final productBomsStreamProvider =
    StreamProvider.family<List<ProductBomModel>, String>((ref, productId) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;
  if (orgId == null || orgId.isEmpty) {
    return const Stream.empty();
  }
  final repo = ref.watch(bomRepositoryProvider);
  return repo.getProductBomsStream(orgId, productId);
});

/// Future provider to fetch the single active BOM for a product.
final activeProductBomProvider =
    FutureProvider.family<ProductBomModel?, String>((ref, productId) async {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;
  if (orgId == null || orgId.isEmpty) {
    return null;
  }
  final repo = ref.watch(bomRepositoryProvider);
  return repo.getActiveBom(orgId, productId);
});

/// Stream of all exported / uploaded files for a product's BOMs.
final productBomFilesStreamProvider =
    StreamProvider.family<List<ProductBomFileModel>, String>((ref, productId) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;
  if (orgId == null || orgId.isEmpty) {
    return const Stream.empty();
  }
  final repo = ref.watch(bomRepositoryProvider);
  return repo.getBomFilesStream(orgId, productId);
});
