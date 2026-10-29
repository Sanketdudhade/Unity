import 'package:cloud_firestore/cloud_firestore.dart';

class ProcessTask {
  final String id;
  final String title;
  final String stage;
  final String workOrder;
  final String assignedToUid;
  final String assignedToName;
  final String status; // 'pending', 'in_progress', 'paused', 'completed'
  final String priority; // 'normal', 'high', 'urgent'
  final DateTime? scheduledDate;
  final String notes;
  final DateTime? updatedAt;

  const ProcessTask({
    required this.id,
    required this.title,
    required this.stage,
    required this.workOrder,
    required this.assignedToUid,
    required this.assignedToName,
    required this.status,
    required this.priority,
    this.scheduledDate,
    this.notes = '',
    this.updatedAt,
  });

  bool get isInProgress => status.toLowerCase() == 'in_progress';
  bool get isPending => status.toLowerCase() == 'pending' || status.toLowerCase() == 'assigned';
  bool get isPaused => status.toLowerCase() == 'paused';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isAssigned => status.toLowerCase() == 'assigned';

  factory ProcessTask.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime? parsedDate;
    final sched = data['scheduledDate'];
    if (sched is Timestamp) parsedDate = sched.toDate();

    DateTime? parsedUpdated;
    final upd = data['updatedAt'];
    if (upd is Timestamp) parsedUpdated = upd.toDate();

    return ProcessTask(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Operation',
      stage: data['stage'] as String? ?? 'Production',
      workOrder: data['workOrder'] as String? ?? 'WO-001',
      assignedToUid: data['assignedToUid'] as String? ?? '',
      assignedToName: data['assignedToName'] as String? ?? 'Shop-Floor Team',
      status: data['status'] as String? ?? 'pending',
      priority: data['priority'] as String? ?? 'normal',
      scheduledDate: parsedDate,
      notes: data['notes'] as String? ?? '',
      updatedAt: parsedUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'stage': stage.trim(),
      'workOrder': workOrder.trim(),
      'assignedToUid': assignedToUid,
      'assignedToName': assignedToName.trim(),
      'status': status.toLowerCase(),
      'priority': priority.toLowerCase(),
      'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : FieldValue.serverTimestamp(),
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
