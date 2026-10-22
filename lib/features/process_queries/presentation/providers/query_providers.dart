import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/process_queries/data/models/process_query_model.dart';
import 'package:unity/features/process_queries/data/repositories/query_repository.dart';

final queryRepositoryProvider = Provider<QueryRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return QueryRepository(firestore: firestore);
});

/// Stream of all shop-floor tickets in current organization.
final queriesStreamProvider = StreamProvider<List<ProcessQuery>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(queryRepositoryProvider);
  return repository.getQueriesStream(orgId);
});

/// Count of open (unresolved) shop-floor tickets.
final openQueriesCountProvider = Provider<int>((ref) {
  final queriesAsync = ref.watch(queriesStreamProvider);
  return queriesAsync.maybeWhen(
    data: (queries) => queries.where((q) => !q.isResolved).length,
    orElse: () => 0,
  );
});
