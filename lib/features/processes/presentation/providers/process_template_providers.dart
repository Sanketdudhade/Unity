import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/processes/data/models/process_template_model.dart';
import 'package:unity/features/processes/data/repositories/process_template_repository.dart';

final processTemplateRepositoryProvider = Provider<ProcessTemplateRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ProcessTemplateRepository(firestore: firestore);
});

/// Stream of all process templates in current organization.
final processTemplatesStreamProvider = StreamProvider<List<ProcessTemplateModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(processTemplateRepositoryProvider);
  return repository.getTemplatesStream(orgId);
});

/// Only active templates available when launching production orders.
final activeProcessTemplatesProvider = Provider<List<ProcessTemplateModel>>((ref) {
  final templatesAsync = ref.watch(processTemplatesStreamProvider);
  return templatesAsync.maybeWhen(
    data: (templates) => templates.where((t) => t.isActive).toList(),
    orElse: () => [],
  );
});

/// Future provider to fetch a single template with all its subcollection steps.
final templateWithStepsProvider = FutureProvider.family<ProcessTemplateModel?, String>((ref, templateId) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Future.value(null);
  }

  final repository = ref.watch(processTemplateRepositoryProvider);
  return repository.getTemplateWithSteps(orgId, templateId);
});
