import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionOrder {
  final String id;
  final String orderNumber;
  final String productName;
  final double targetQuantity;
  final double completedQuantity;
  final String unit;
  final String status; // 'scheduled', 'in_production', 'completed', 'on_hold'
  final String priority; // 'normal', 'high', 'urgent'
  final String productionType; // 'CUTTING', 'NON_CUTTING'
  final DateTime? startDate;
  final DateTime? dueDate;
  final String customerName;
  final String notes;
  final DateTime? updatedAt;

  const ProductionOrder({
    required this.id,
    required this.orderNumber,
    required this.productName,
    required this.targetQuantity,
    this.completedQuantity = 0.0,
    required this.unit,
    required this.status,
    required this.priority,
    this.productionType = 'CUTTING',
    this.startDate,
    this.dueDate,
    this.customerName = '',
    this.notes = '',
    this.updatedAt,
  });

  bool get isCutting => productionType.toUpperCase() == 'CUTTING';
  bool get isNonCutting => productionType.toUpperCase() == 'NON_CUTTING';

  bool get isInProduction => status.toLowerCase() == 'in_production';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isScheduled => status.toLowerCase() == 'scheduled';
  bool get isOnHold => status.toLowerCase() == 'on_hold';

  double get progressPercentage {
    if (targetQuantity <= 0) return 0.0;
    return (completedQuantity / targetQuantity).clamp(0.0, 1.0);
  }

  factory ProductionOrder.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      return null;
    }

    return ProductionOrder(
      id: doc.id,
      orderNumber: data['orderNumber'] as String? ?? 'WO-NEW',
      productName: data['productName'] as String? ?? 'Custom Part',
      targetQuantity: (data['targetQuantity'] as num?)?.toDouble() ?? 100.0,
      completedQuantity: (data['completedQuantity'] as num?)?.toDouble() ?? 0.0,
      unit: data['unit'] as String? ?? 'pcs',
      status: data['status'] as String? ?? 'scheduled',
      priority: data['priority'] as String? ?? 'normal',
      productionType: (data['productionType'] as String? ?? 'CUTTING').toUpperCase(),
      startDate: parseDate(data['startDate']),
      dueDate: parseDate(data['dueDate']),
      customerName: data['customerName'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderNumber': orderNumber.trim().toUpperCase(),
      'productName': productName.trim(),
      'targetQuantity': targetQuantity,
      'completedQuantity': completedQuantity,
      'unit': unit.trim(),
      'status': status.toLowerCase(),
      'priority': priority.toLowerCase(),
      'productionType': productionType.toUpperCase(),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'customerName': customerName.trim(),
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ProductionOrder copyWith({
    String? id,
    String? orderNumber,
    String? productName,
    double? targetQuantity,
    double? completedQuantity,
    String? unit,
    String? status,
    String? priority,
    String? productionType,
    DateTime? startDate,
    DateTime? dueDate,
    String? customerName,
    String? notes,
    DateTime? updatedAt,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      productName: productName ?? this.productName,
      targetQuantity: targetQuantity ?? this.targetQuantity,
      completedQuantity: completedQuantity ?? this.completedQuantity,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      productionType: productionType ?? this.productionType,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
