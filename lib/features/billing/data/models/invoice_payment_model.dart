import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment transaction recorded against an issued invoice.
class InvoicePaymentModel {
  final String id;
  final String invoiceId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod; // 'BANK_TRANSFER', 'NEFT_RTGS', 'CHEQUE', 'UPI', 'CASH'
  final String transactionReference;
  final String notes;
  final String recordedByUid;
  final String recordedByName;
  final DateTime? createdAt;

  const InvoicePaymentModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    this.paymentMethod = 'BANK_TRANSFER',
    String? transactionReference,
    String? notes,
    String? recordedBy,
    this.recordedByUid = '',
    this.recordedByName = 'Admin',
    this.createdAt,
  })  : transactionReference = transactionReference ?? '',
        notes = notes ?? '';

  String? get recordedBy => recordedByUid;

  factory InvoicePaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return InvoicePaymentModel.fromMap(doc.id, data);
  }

  factory InvoicePaymentModel.fromMap(dynamic p1, [dynamic p2]) {
    final String id;
    final Map<String, dynamic> data;
    if (p1 is Map<String, dynamic>) {
      data = p1;
      id = (p2 is String ? p2 : (data['id'] as String? ?? ''));
    } else {
      id = p1.toString();
      data = (p2 as Map<String, dynamic>?) ?? {};
    }

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return InvoicePaymentModel(
      id: id,
      invoiceId: data['invoiceId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: parseDate(data['paymentDate']),
      paymentMethod: data['paymentMethod'] as String? ?? 'BANK_TRANSFER',
      transactionReference: data['transactionReference'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      recordedByUid: (data['recordedByUid'] ?? data['recordedBy']) as String? ?? '',
      recordedByName: data['recordedByName'] as String? ?? 'Admin',
      createdAt: data['createdAt'] != null ? parseDate(data['createdAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceId': invoiceId,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentMethod': paymentMethod,
      'transactionReference': transactionReference.trim(),
      'notes': notes.trim(),
      'recordedByUid': recordedByUid,
      'recordedByName': recordedByName.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  InvoicePaymentModel copyWith({
    String? id,
    String? invoiceId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? transactionReference,
    String? notes,
    String? recordedBy,
    String? recordedByUid,
    String? recordedByName,
    DateTime? createdAt,
  }) {
    return InvoicePaymentModel(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionReference: transactionReference ?? this.transactionReference,
      notes: notes ?? this.notes,
      recordedByUid: recordedBy ?? (recordedByUid ?? this.recordedByUid),
      recordedByName: recordedByName ?? this.recordedByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
