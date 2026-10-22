import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/features/processes/data/models/process_step_model.dart';

class ProcessTemplateModel {
  final String id;
  final String name;
  final int version;
  final bool isActive;
  final int stagesCount;
  final List<ProcessStepModel> steps;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProcessTemplateModel({
    required this.id,
    required this.name,
    this.version = 1,
    this.isActive = true,
    this.stagesCount = 17,
    this.steps = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ProcessTemplateModel.fromFirestore(
    DocumentSnapshot doc, [
    List<ProcessStepModel> steps = const [],
  ]) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      return null;
    }

    return ProcessTemplateModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Manufacturing Template',
      version: (data['version'] as num?)?.toInt() ?? 1,
      isActive: data['isActive'] as bool? ?? true,
      stagesCount: (data['stagesCount'] as num?)?.toInt() ?? steps.length,
      steps: steps,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'version': version,
      'isActive': isActive,
      'stagesCount': steps.isNotEmpty ? steps.length : stagesCount,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProcessTemplateModel copyWith({
    String? id,
    String? name,
    int? version,
    bool? isActive,
    int? stagesCount,
    List<ProcessStepModel>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProcessTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      stagesCount: stagesCount ?? this.stagesCount,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Default 17-stage reference manufacturing workflow
  static List<ProcessStepModel> default17Stages() {
    return const [
      ProcessStepModel(id: 'step_1', sequence: 1, name: 'RFQ received', defaultDurationHours: 4, dependsOnStepSequence: []),
      ProcessStepModel(id: 'step_2', sequence: 2, name: 'Feasibility study', defaultDurationHours: 8, dependsOnStepSequence: [1]),
      ProcessStepModel(id: 'step_3', sequence: 3, name: 'Quotation', defaultDurationHours: 4, dependsOnStepSequence: [2]),
      ProcessStepModel(id: 'step_4', sequence: 4, name: 'Customer purchase order', defaultDurationHours: 4, dependsOnStepSequence: [3]),
      ProcessStepModel(id: 'step_5', sequence: 5, name: 'Concept drawing/design', defaultDurationHours: 16, dependsOnStepSequence: [4]),
      ProcessStepModel(id: 'step_6', sequence: 6, name: '3D design/modeling', defaultDurationHours: 24, dependsOnStepSequence: [5]),
      ProcessStepModel(id: 'step_7', sequence: 7, name: 'BOM release', defaultDurationHours: 8, dependsOnStepSequence: [6]),
      ProcessStepModel(id: 'step_8', sequence: 8, name: 'Material procurement', defaultDurationHours: 48, dependsOnStepSequence: [7]),
      ProcessStepModel(id: 'step_9', sequence: 9, name: 'Detailed drawing release', defaultDurationHours: 16, dependsOnStepSequence: [8]),
      ProcessStepModel(id: 'step_10', sequence: 10, name: 'Optional Stage (Pre-machining QA)', defaultDurationHours: 8, isOptional: true, dependsOnStepSequence: [9]),
      ProcessStepModel(id: 'step_11', sequence: 11, name: '3D precision machining', defaultDurationHours: 32, dependsOnStepSequence: [9]),
      ProcessStepModel(id: 'step_12', sequence: 12, name: 'Heat treatment', defaultDurationHours: 24, dependsOnStepSequence: [11]),
      ProcessStepModel(id: 'step_13', sequence: 13, name: '2D precision machining', defaultDurationHours: 16, dependsOnStepSequence: [12]),
      ProcessStepModel(id: 'step_14', sequence: 14, name: 'Assembly', defaultDurationHours: 16, dependsOnStepSequence: [13]),
      ProcessStepModel(id: 'step_15', sequence: 15, name: 'Trial', defaultDurationHours: 8, dependsOnStepSequence: [14]),
      ProcessStepModel(id: 'step_16', sequence: 16, name: 'Inspection', defaultDurationHours: 8, dependsOnStepSequence: [15]),
      ProcessStepModel(id: 'step_17', sequence: 17, name: 'Dispatch', defaultDurationHours: 4, dependsOnStepSequence: [16]),
    ];
  }
}
