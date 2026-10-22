import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/products/data/models/product_model.dart';

/// Repository for managing the factory product and parts catalog.
class ProductRepository {
  final FirebaseFirestore firestore;

  ProductRepository({required this.firestore});

  /// Real-time stream of all products in [orgId].
  Stream<List<ProductModel>> getProductsStream(String orgId) {
    return firestore
        .collection(FirestorePaths.productsCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList()
        ..sort((a, b) => a.partCode.toLowerCase().compareTo(b.partCode.toLowerCase()));
    });
  }

  /// Adds a new product / part definition to Firestore.
  Future<void> createProduct(String orgId, ProductModel product) async {
    try {
      final docRef = firestore.collection(FirestorePaths.productsCollection(orgId)).doc();
      await docRef.set(product.toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create product: ${e.message}', code: e.code);
    }
  }

  /// Updates an existing product definition.
  Future<void> updateProduct(String orgId, ProductModel product) async {
    try {
      await firestore
          .collection(FirestorePaths.productsCollection(orgId))
          .doc(product.id)
          .update(product.toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update product: ${e.message}', code: e.code);
    }
  }

  /// Toggles product active status.
  Future<void> toggleProductStatus(String orgId, String productId, bool isActive) async {
    try {
      await firestore
          .collection(FirestorePaths.productsCollection(orgId))
          .doc(productId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to toggle product status: ${e.message}', code: e.code);
    }
  }
}
