import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/utils/formatters.dart';

/// Immutable transaction entry in the authoritative inventory ledger.
/// Scoped under: `/organizations/{orgId}/inventoryTransactions/{transactionId}`
class StockTransactionModel {
  final String id;
  final String transactionNumber;
  final String type; // 'RECEIPT', 'ISSUE', 'ALLOCATION', 'DEALLOCATION', 'SCRAP', 'ADJUSTMENT', 'RETURN'
  final String materialId;
  final String materialSku;
  final String materialName;
  final String locationId;
  final int quantityDelta; // in integer base units (positive for receipts/returns, negative for issues/scrap)
  final int balanceBefore; // in integer base units
  final int balanceAfter; // in integer base units
  final String? orderId;
  final String? processId;
  final String performedByUid;
  final String performedByName;
  final String? referenceNumber; // PO Number, GRN, Work Order ID, Scrap Ticket
  final String notes;
  final String unit;
  final int unitScale;
  final DateTime? createdAt;

  const StockTransactionModel({
    required this.id,
    required this.transactionNumber,
    required this.type,
    required this.materialId,
    required this.materialSku,
    required this.materialName,
    this.locationId = 'MAIN',
    required this.quantityDelta,
    required this.balanceBefore,
    required this.balanceAfter,
    this.orderId,
    this.processId,
    required this.performedByUid,
    required this.performedByName,
    this.referenceNumber,
    this.notes = '',
    this.unit = 'pcs',
    this.unitScale = 1,
    this.createdAt,
  });

  bool get isPositiveDelta => quantityDelta > 0;

  String get formattedDelta {
    final absVal = FactoryFormatters.formatBaseUnitsToDisplay(
      baseUnits: quantityDelta.abs(),
      unitScale: unitScale,
    );
    final sign = quantityDelta >= 0 ? '+' : '-';
    return '$sign$absVal $unit';
  }

  String get formattedBalanceAfter =>
      '${FactoryFormatters.formatBaseUnitsToDisplay(baseUnits: balanceAfter, unitScale: unitScale)} $unit';

  factory StockTransactionModel.fromFirestore(DocumentSnapshot doc) {
    return StockTransactionModel.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? {},
    );
  }

  factory StockTransactionModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return StockTransactionModel(
      id: id,
      transactionNumber: data['transactionNumber'] as String? ?? 'TX-RECORD',
      type: (data['type'] as String? ?? 'RECEIPT').toUpperCase(),
      materialId: data['materialId'] as String? ?? '',
      materialSku: data['materialSku'] as String? ?? '',
      materialName: data['materialName'] as String? ?? 'Material',
      locationId: data['locationId'] as String? ?? 'MAIN',
      quantityDelta: (data['quantityDelta'] as num?)?.toInt() ?? 0,
      balanceBefore: (data['balanceBefore'] as num?)?.toInt() ?? 0,
      balanceAfter: (data['balanceAfter'] as num?)?.toInt() ?? 0,
      orderId: data['orderId'] as String?,
      processId: data['processId'] as String?,
      performedByUid: data['performedByUid'] as String? ?? '',
      performedByName: data['performedByName'] as String? ?? 'System',
      referenceNumber: data['referenceNumber'] as String?,
      notes: data['notes'] as String? ?? '',
      unit: data['unit'] as String? ?? 'pcs',
      unitScale: (data['unitScale'] as num?)?.toInt() ?? 1,
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionNumber': transactionNumber,
      'type': type,
      'materialId': materialId,
      'materialSku': materialSku,
      'materialName': materialName,
      'locationId': locationId,
      'quantityDelta': quantityDelta,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'orderId': orderId,
      'processId': processId,
      'performedByUid': performedByUid,
      'performedByName': performedByName,
      'referenceNumber': referenceNumber,
      'notes': notes.trim(),
      'unit': unit,
      'unitScale': unitScale,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
