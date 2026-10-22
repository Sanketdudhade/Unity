class ProcessStepModel {
  final String id;
  final int sequence;
  final String name;
  final int defaultDurationHours;
  final bool isOptional;
  final List<int> dependsOnStepSequence;
  final List<String> allowedRoles;

  const ProcessStepModel({
    required this.id,
    required this.sequence,
    required this.name,
    this.defaultDurationHours = 8,
    this.isOptional = false,
    this.dependsOnStepSequence = const [],
    this.allowedRoles = const ['EMPLOYEE', 'ADMIN'],
  });

  factory ProcessStepModel.fromMap(String id, Map<String, dynamic> data) {
    return ProcessStepModel(
      id: id,
      sequence: (data['sequence'] as num?)?.toInt() ?? 1,
      name: data['name'] as String? ?? 'Stage',
      defaultDurationHours: (data['defaultDurationHours'] as num?)?.toInt() ?? 8,
      isOptional: data['isOptional'] as bool? ?? false,
      dependsOnStepSequence: (data['dependsOnStepSequence'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      allowedRoles: (data['allowedRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['EMPLOYEE', 'ADMIN'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sequence': sequence,
      'name': name.trim(),
      'defaultDurationHours': defaultDurationHours,
      'isOptional': isOptional,
      'dependsOnStepSequence': dependsOnStepSequence,
      'allowedRoles': allowedRoles,
    };
  }

  ProcessStepModel copyWith({
    String? id,
    int? sequence,
    String? name,
    int? defaultDurationHours,
    bool? isOptional,
    List<int>? dependsOnStepSequence,
    List<String>? allowedRoles,
  }) {
    return ProcessStepModel(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      name: name ?? this.name,
      defaultDurationHours: defaultDurationHours ?? this.defaultDurationHours,
      isOptional: isOptional ?? this.isOptional,
      dependsOnStepSequence: dependsOnStepSequence ?? this.dependsOnStepSequence,
      allowedRoles: allowedRoles ?? this.allowedRoles,
    );
  }
}
