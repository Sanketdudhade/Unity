import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable daily update log for a single manufacturing stage in a production order.
/// Scoped under: `/organizations/{orgId}/productionOrders/{orderId}/processes/{processId}/updates/{updateId}`
class ProcessUpdateModel {
  final String id;
  final String actorUid;
  final String actorName;
  final int deltaCompletedQty;
  final double? hoursSpent;
  final String? blockerReason;
  final String notes;
  final List<String> attachmentRefs;
  final DateTime? createdAt;

  const ProcessUpdateModel({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.deltaCompletedQty,
    this.hoursSpent,
    this.blockerReason,
    this.notes = '',
    this.attachmentRefs = const [],
    this.createdAt,
  });

  factory ProcessUpdateModel.fromFirestore(DocumentSnapshot doc) {
    return ProcessUpdateModel.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? {},
    );
  }

  factory ProcessUpdateModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return ProcessUpdateModel(
      id: id,
      actorUid: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Operator',
      deltaCompletedQty: (data['deltaCompletedQty'] as num?)?.toInt() ?? 0,
      hoursSpent: (data['hoursSpent'] as num?)?.toDouble(),
      blockerReason: data['blockerReason'] as String?,
      notes: data['notes'] as String? ?? '',
      attachmentRefs: (data['attachmentRefs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorUid': actorUid,
      'actorName': actorName,
      'deltaCompletedQty': deltaCompletedQty,
      'hoursSpent': hoursSpent,
      'blockerReason': blockerReason,
      'notes': notes.trim(),
      'attachmentRefs': attachmentRefs,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  bool get hasBlocker => blockerReason != null && blockerReason!.trim().isNotEmpty;
}
