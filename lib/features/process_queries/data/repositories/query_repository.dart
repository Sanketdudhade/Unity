import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/process_queries/data/models/process_query_model.dart';

/// Repository managing shop-floor tickets, operator queries, and maintenance resolution.
class QueryRepository {
  final FirebaseFirestore firestore;

  QueryRepository({required this.firestore});

  /// Real-time stream of all queries in [orgId].
  Stream<List<ProcessQuery>> getQueriesStream(String orgId) {
    return firestore
        .collection(FirestorePaths.processQueriesCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProcessQuery.fromFirestore(doc))
          .toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000)));
    });
  }

  /// Creates a new shop-floor query / ticket.
  Future<void> createQuery(String orgId, ProcessQuery query) async {
    try {
      final collection = firestore.collection(FirestorePaths.processQueriesCollection(orgId));
      await collection.add(query.toMap());
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to raise ticket: ${e.message}', code: e.code);
    }
  }

  /// Updates status and resolution notes of a query.
  Future<void> updateQueryStatus({
    required String orgId,
    required String queryId,
    required String status,
    String? resolutionNotes,
  }) async {
    try {
      await firestore
          .collection(FirestorePaths.processQueriesCollection(orgId))
          .doc(queryId)
          .update({
        'status': status.toLowerCase(),
        if (resolutionNotes != null && resolutionNotes.isNotEmpty) 'resolutionNotes': resolutionNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update ticket: ${e.message}', code: e.code);
    }
  }
}
