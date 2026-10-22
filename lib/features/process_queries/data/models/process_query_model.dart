import 'package:cloud_firestore/cloud_firestore.dart';

class ProcessQuery {
  final String id;
  final String ticketNumber;
  final String title;
  final String description;
  final String workOrder;
  final String stage;
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String status; // 'open', 'in_review', 'resolved'
  final String reportedByName;
  final String reportedByUid;
  final String resolutionNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProcessQuery({
    required this.id,
    required this.ticketNumber,
    required this.title,
    required this.description,
    this.workOrder = '',
    this.stage = '',
    required this.severity,
    required this.status,
    required this.reportedByName,
    this.reportedByUid = '',
    this.resolutionNotes = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isInReview => status.toLowerCase() == 'in_review';
  bool get isResolved => status.toLowerCase() == 'resolved';

  factory ProcessQuery.fromFirestore(DocumentSnapshot doc) {
    return ProcessQuery.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? {},
    );
  }

  factory ProcessQuery.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return ProcessQuery(
      id: id,
      ticketNumber: data['ticketNumber'] as String? ?? 'TK-100',
      title: data['title'] as String? ?? 'Shop-Floor Issue',
      description: data['description'] as String? ?? '',
      workOrder: data['workOrder'] as String? ?? '',
      stage: data['stage'] as String? ?? '',
      severity: data['severity'] as String? ?? 'medium',
      status: data['status'] as String? ?? 'open',
      reportedByName: data['reportedByName'] as String? ?? 'Operator',
      reportedByUid: data['reportedByUid'] as String? ?? '',
      resolutionNotes: data['resolutionNotes'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketNumber': ticketNumber.trim().toUpperCase(),
      'title': title.trim(),
      'description': description.trim(),
      'workOrder': workOrder.trim(),
      'stage': stage.trim(),
      'severity': severity.toLowerCase(),
      'status': status.toLowerCase(),
      'reportedByName': reportedByName.trim(),
      'reportedByUid': reportedByUid,
      'resolutionNotes': resolutionNotes.trim(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProcessQuery copyWith({
    String? id,
    String? ticketNumber,
    String? title,
    String? description,
    String? workOrder,
    String? stage,
    String? severity,
    String? status,
    String? reportedByName,
    String? reportedByUid,
    String? resolutionNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProcessQuery(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      workOrder: workOrder ?? this.workOrder,
      stage: stage ?? this.stage,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      reportedByName: reportedByName ?? this.reportedByName,
      reportedByUid: reportedByUid ?? this.reportedByUid,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
