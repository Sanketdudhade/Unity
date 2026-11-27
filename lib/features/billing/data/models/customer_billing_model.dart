import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a customer/buyer record saved for quick selection and reuse in invoices.
class CustomerBillingModel {
  final String id;
  final String customerName;
  final String billingAddress;
  final String gstin;
  final String stateName;
  final String stateCode;
  final String placeOfSupply;
  final String email;
  final String phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomerBillingModel({
    required this.id,
    required this.customerName,
    this.billingAddress = '',
    this.gstin = '',
    this.stateName = 'Maharashtra',
    this.stateCode = '27',
    this.placeOfSupply = 'Maharashtra (27)',
    this.email = '',
    this.phone = '',
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerBillingModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CustomerBillingModel.fromMap(doc.id, data);
  }

  factory CustomerBillingModel.fromMap(dynamic p1, [dynamic p2]) {
    final String id;
    final Map<String, dynamic> data;
    if (p1 is Map<String, dynamic>) {
      data = p1;
      id = (p2 is String ? p2 : (data['id'] as String? ?? ''));
    } else {
      id = p1.toString();
      data = (p2 as Map<String, dynamic>?) ?? {};
    }

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return CustomerBillingModel(
      id: id,
      customerName: data['customerName'] as String? ?? '',
      billingAddress: data['billingAddress'] as String? ?? '',
      gstin: data['gstin'] as String? ?? '',
      stateName: data['stateName'] as String? ?? 'Maharashtra',
      stateCode: data['stateCode'] as String? ?? '27',
      placeOfSupply: data['placeOfSupply'] as String? ?? 'Maharashtra (27)',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName.trim(),
      'billingAddress': billingAddress.trim(),
      'gstin': gstin.trim().toUpperCase(),
      'stateName': stateName.trim(),
      'stateCode': stateCode.trim(),
      'placeOfSupply': placeOfSupply.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CustomerBillingModel copyWith({
    String? id,
    String? customerName,
    String? billingAddress,
    String? gstin,
    String? stateName,
    String? stateCode,
    String? placeOfSupply,
    String? email,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerBillingModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      billingAddress: billingAddress ?? this.billingAddress,
      gstin: gstin ?? this.gstin,
      stateName: stateName ?? this.stateName,
      stateCode: stateCode ?? this.stateCode,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
