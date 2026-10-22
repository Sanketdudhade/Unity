import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single process stage within a production order, snapshotted from a template.
class OrderProcessModel {
  final String id;
  final String orderId;
  final String templateStepId;
  final String name;
  final int sequence;
  final List<int> dependsOnStepSequence;
  final String assignedEmployeeUid;
  final String assignedEmployeeName;
  final int targetQty;
  final int completedQty;
  final String status;
  final DateTime? dueAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? approvedBy;
  final String reworkReason;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderProcessModel({
    required this.id,
    this.orderId = '',
    required this.templateStepId,
    required this.name,
    required this.sequence,
    this.dependsOnStepSequence = const [],
    this.assignedEmployeeUid = '',
    this.assignedEmployeeName = 'Unassigned',
    required this.targetQty,
    this.completedQty = 0,
    this.status = 'NOT_STARTED',
    this.dueAt,
    this.startedAt,
    this.completedAt,
    this.approvedBy,
    this.reworkReason = '',
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isNotStarted => status == 'NOT_STARTED';
  bool get isAssigned => status == 'ASSIGNED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isBlocked => status == 'BLOCKED';
  bool get isPendingApproval => status == 'PENDING_APPROVAL';
  bool get isCompleted => status == 'COMPLETED';
  bool get isReworkRequired => status == 'REWORK_REQUIRED';
  bool get isCancelled => status == 'CANCELLED';

  double get progressPercentage {
    if (targetQty <= 0) return 0.0;
    return (completedQty / targetQty).clamp(0.0, 1.0);
  }

  /// Verifies if this process step is unlocked given the completion state of all steps in the order.
  bool isUnlocked(Map<int, String> stepStatusesBySequence) {
    if (dependsOnStepSequence.isEmpty) return true;
    for (final seq in dependsOnStepSequence) {
      final status = stepStatusesBySequence[seq];
      if (status != 'COMPLETED') {
        return false;
      }
    }
    return true;
  }

  factory OrderProcessModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final parentOrderId = doc.reference.parent.parent?.id ?? '';
    return OrderProcessModel.fromMap(doc.id, data, parentOrderId);
  }

  factory OrderProcessModel.fromMap(String id, Map<String, dynamic> data, [String defaultOrderId = '']) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    final orderId = (data['orderId'] as String?)?.isNotEmpty == true
        ? data['orderId'] as String
        : defaultOrderId;

    return OrderProcessModel(
      id: id,
      orderId: orderId,
      templateStepId: data['templateStepId'] as String? ?? '',
      name: data['name'] as String? ?? 'Stage',
      sequence: (data['sequence'] as num?)?.toInt() ?? 1,
      dependsOnStepSequence: (data['dependsOnStepSequence'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      assignedEmployeeUid: data['assignedEmployeeUid'] as String? ?? '',
      assignedEmployeeName: data['assignedEmployeeName'] as String? ?? 'Unassigned',
      targetQty: (data['targetQty'] as num?)?.toInt() ?? 100,
      completedQty: (data['completedQty'] as num?)?.toInt() ?? 0,
      status: (data['status'] as String? ?? 'NOT_STARTED').toUpperCase(),
      dueAt: parseDate(data['dueAt']),
      startedAt: parseDate(data['startedAt']),
      completedAt: parseDate(data['completedAt']),
      approvedBy: data['approvedBy'] as String?,
      reworkReason: data['reworkReason'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'templateStepId': templateStepId,
      'name': name.trim(),
      'sequence': sequence,
      'dependsOnStepSequence': dependsOnStepSequence,
      'assignedEmployeeUid': assignedEmployeeUid,
      'assignedEmployeeName': assignedEmployeeName.trim(),
      'targetQty': targetQty,
      'completedQty': completedQty,
      'status': status.toUpperCase(),
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'approvedBy': approvedBy,
      'reworkReason': reworkReason.trim(),
      'notes': notes.trim(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  OrderProcessModel copyWith({
    String? id,
    String? orderId,
    String? templateStepId,
    String? name,
    int? sequence,
    List<int>? dependsOnStepSequence,
    String? assignedEmployeeUid,
    String? assignedEmployeeName,
    int? targetQty,
    int? completedQty,
    String? status,
    DateTime? dueAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? approvedBy,
    String? reworkReason,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderProcessModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      templateStepId: templateStepId ?? this.templateStepId,
      name: name ?? this.name,
      sequence: sequence ?? this.sequence,
      dependsOnStepSequence: dependsOnStepSequence ?? this.dependsOnStepSequence,
      assignedEmployeeUid: assignedEmployeeUid ?? this.assignedEmployeeUid,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      targetQty: targetQty ?? this.targetQty,
      completedQty: completedQty ?? this.completedQty,
      status: status ?? this.status,
      dueAt: dueAt ?? this.dueAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      reworkReason: reworkReason ?? this.reworkReason,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
