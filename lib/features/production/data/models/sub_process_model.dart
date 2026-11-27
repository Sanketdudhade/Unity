import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an operational sub-process under a primary manufacturing stage (Steps 4 to 11).
/// Admin can create sub-processes and allocate them to individual technicians/operators.
class SubProcessModel {
  final String id;
  final String orderId;
  final String processId;
  final int stageSequence;
  final String stageName;
  final String title;
  final String description;
  final String assignedEmployeeUid;
  final String assignedEmployeeName;
  final String status; // 'NOT_STARTED', 'IN_PROGRESS', 'COMPLETED', 'BLOCKED'
  final int targetQty;
  final int completedQty;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubProcessModel({
    required this.id,
    this.orderId = '',
    this.processId = '',
    this.stageSequence = 0,
    this.stageName = '',
    required this.title,
    this.description = '',
    this.assignedEmployeeUid = '',
    this.assignedEmployeeName = 'Unassigned',
    this.status = 'NOT_STARTED',
    this.targetQty = 0,
    this.completedQty = 0,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isNotStarted => status == 'NOT_STARTED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get isBlocked => status == 'BLOCKED';
  bool get isAssigned => assignedEmployeeUid.isNotEmpty && assignedEmployeeName != 'Unassigned';

  factory SubProcessModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return SubProcessModel(
      id: id ?? (map['id'] as String? ?? ''),
      orderId: map['orderId'] as String? ?? '',
      processId: map['processId'] as String? ?? '',
      stageSequence: (map['stageSequence'] as num?)?.toInt() ?? 0,
      stageName: map['stageName'] as String? ?? '',
      title: map['title'] as String? ?? map['name'] as String? ?? '',
      description: map['description'] as String? ?? map['notes'] as String? ?? '',
      assignedEmployeeUid: map['assignedEmployeeUid'] as String? ?? '',
      assignedEmployeeName: map['assignedEmployeeName'] as String? ?? 'Unassigned',
      status: (map['status'] as String? ?? 'NOT_STARTED').toUpperCase(),
      targetQty: (map['targetQty'] as num?)?.toInt() ?? 0,
      completedQty: (map['completedQty'] as num?)?.toInt() ?? 0,
      startedAt: parseDate(map['startedAt']),
      completedAt: parseDate(map['completedAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'processId': processId,
      'stageSequence': stageSequence,
      'stageName': stageName,
      'title': title.trim(),
      'description': description.trim(),
      'assignedEmployeeUid': assignedEmployeeUid.trim(),
      'assignedEmployeeName': assignedEmployeeName.trim(),
      'status': status.toUpperCase(),
      'targetQty': targetQty,
      'completedQty': completedQty,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SubProcessModel copyWith({
    String? id,
    String? orderId,
    String? processId,
    int? stageSequence,
    String? stageName,
    String? title,
    String? description,
    String? assignedEmployeeUid,
    String? assignedEmployeeName,
    String? status,
    int? targetQty,
    int? completedQty,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubProcessModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      processId: processId ?? this.processId,
      stageSequence: stageSequence ?? this.stageSequence,
      stageName: stageName ?? this.stageName,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedEmployeeUid: assignedEmployeeUid ?? this.assignedEmployeeUid,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      status: status ?? this.status,
      targetQty: targetQty ?? this.targetQty,
      completedQty: completedQty ?? this.completedQty,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
