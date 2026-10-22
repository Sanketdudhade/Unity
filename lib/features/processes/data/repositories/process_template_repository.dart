import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/processes/data/models/process_step_model.dart';
import 'package:unity/features/processes/data/models/process_template_model.dart';

/// Repository for managing reusable manufacturing process templates and sequential step definitions.
class ProcessTemplateRepository {
  final FirebaseFirestore firestore;

  ProcessTemplateRepository({required this.firestore});

  /// Real-time stream of all process templates in [orgId].
  Stream<List<ProcessTemplateModel>> getTemplatesStream(String orgId) {
    return firestore
        .collection(FirestorePaths.processTemplatesCollection(orgId))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProcessTemplateModel.fromFirestore(doc))
          .toList()
        ..sort((a, b) => b.version.compareTo(a.version));
    });
  }

  /// Fetches a single template with all its subcollection steps.
  Future<ProcessTemplateModel?> getTemplateWithSteps(String orgId, String templateId) async {
    try {
      final doc = await firestore
          .collection(FirestorePaths.processTemplatesCollection(orgId))
          .doc(templateId)
          .get();

      if (!doc.exists) return null;

      final stepsSnap = await firestore
          .collection(FirestorePaths.processTemplateStepsCollection(orgId, templateId))
          .orderBy('sequence')
          .get();

      final steps = stepsSnap.docs
          .map((sDoc) => ProcessStepModel.fromMap(sDoc.id, sDoc.data()))
          .toList();

      return ProcessTemplateModel.fromFirestore(doc, steps);
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to fetch template steps: ${e.message}', code: e.code);
    }
  }

  /// Creates a template and saves its ordered steps into the subcollection atomically.
  Future<String> createTemplateWithSteps({
    required String orgId,
    required ProcessTemplateModel template,
    required List<ProcessStepModel> steps,
  }) async {
    try {
      final templateRef = firestore
          .collection(FirestorePaths.processTemplatesCollection(orgId))
          .doc();

      final batch = firestore.batch();

      batch.set(templateRef, template.toMap());

      for (final step in steps) {
        final stepRef = templateRef.collection('steps').doc();
        batch.set(stepRef, step.toMap());
      }

      await batch.commit();
      return templateRef.id;
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create template: ${e.message}', code: e.code);
    }
  }

  /// Checks if any templates exist; if not, seeds the default 17-stage manufacturing flow.
  Future<void> seedDefaultTemplateIfEmpty(String orgId) async {
    try {
      final collection = firestore.collection(FirestorePaths.processTemplatesCollection(orgId));
      final snap = await collection.limit(1).get();
      if (snap.docs.isNotEmpty) return;

      final defaultSteps = ProcessTemplateModel.default17Stages();
      const defaultTemplate = ProcessTemplateModel(
        id: '',
        name: 'Standard 17-Stage Manufacturing Flow',
        version: 1,
        isActive: true,
        stagesCount: 17,
      );

      await createTemplateWithSteps(
        orgId: orgId,
        template: defaultTemplate,
        steps: defaultSteps,
      );
    } catch (_) {}
  }

  /// Toggles template active state.
  Future<void> toggleTemplateActive(String orgId, String templateId, bool isActive) async {
    try {
      await firestore
          .collection(FirestorePaths.processTemplatesCollection(orgId))
          .doc(templateId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update template: ${e.message}', code: e.code);
    }
  }
}
