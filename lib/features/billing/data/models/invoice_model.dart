import 'package:cloud_firestore/cloud_firestore.dart';
import 'company_billing_config_model.dart';
import 'customer_billing_model.dart';
import 'invoice_item_model.dart';

enum InvoiceRecordStatus { draft, issued, cancelled }
enum InvoicePaymentStatus { paid, pending, partial, overdue }

/// Complete GST Invoice model representing an issued, draft, or cancelled financial document.
class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String financialYear; // e.g. "2026-27"
  final int sequenceNumber;
  final String status; // 'DRAFT', 'ISSUED', 'CANCELLED'
  final String paymentStatus; // 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'OVERDUE'
  final DateTime invoiceDate;
  final DateTime? dueDate;

  // Delivery & Reference Information
  final String deliveryNote;
  final String paymentTerms;
  final String referenceNo;
  final DateTime? referenceDate;
  final String otherReferences;
  final String buyersOrderNo;
  final DateTime? buyersOrderDate;
  final String dispatchDocNo;
  final DateTime? deliveryNoteDate;
  final String dispatchedThrough;
  final String destination;
  final String billOfLadingNo;
  final String vehicleNo;
  final String termsOfDelivery;

  // Optional E-Invoice compliance fields
  final String irn;
  final String ackNo;
  final DateTime? ackDate;

  // Immutable historical snapshots of company emitter and buyer customer
  final CompanyBillingConfigModel companyDetails;
  final String? customerId;
  final CustomerBillingModel customerDetails;

  // Line items
  final List<InvoiceItemModel> items;

  // Financial aggregates
  final double totalQuantity;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTaxAmount;
  final double otherCharges;
  final double roundOff;
  final double grandTotal;
  final double totalPaid;
  final double outstandingAmount;
  final String amountInWords;
  final String taxAmountInWords;
  final bool isInterState;

  // Audit and cancellation
  final String cancellationReason;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.financialYear,
    this.sequenceNumber = 1,
    String status = 'DRAFT',
    InvoiceRecordStatus? invoiceStatus,
    dynamic paymentStatus = 'UNPAID',
    InvoicePaymentStatus? paymentStatusEnum,
    required this.invoiceDate,
    this.dueDate,
    this.deliveryNote = '',
    String? modeOfPayment,
    String paymentTerms = 'Payment on Delivery / 30 Days',
    this.referenceNo = '',
    this.referenceDate,
    this.otherReferences = '',
    String? buyerOrderNumber,
    String buyersOrderNo = '',
    this.buyersOrderDate,
    String? dispatchDocNumber,
    String dispatchDocNo = '',
    this.deliveryNoteDate,
    this.dispatchedThrough = '',
    this.destination = '',
    this.billOfLadingNo = '',
    String? motorVehicleNumber,
    String vehicleNo = '',
    this.termsOfDelivery = '',
    this.irn = '',
    String? acknowledgementNumber,
    String ackNo = '',
    this.ackDate,
    String? acknowledgementDate,
    CompanyBillingConfigModel? companyDetails,
    CompanyBillingConfigModel? companySnapshot,
    this.customerId,
    CustomerBillingModel? customerDetails,
    CustomerBillingModel? customerSnapshot,
    this.items = const [],
    this.totalQuantity = 0.0,
    this.taxableAmount = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    double? totalTax,
    double totalTaxAmount = 0.0,
    this.otherCharges = 0.0,
    this.roundOff = 0.0,
    required this.grandTotal,
    this.totalPaid = 0.0,
    double? outstandingAmount,
    this.amountInWords = '',
    this.taxAmountInWords = '',
    this.isInterState = false,
    this.cancellationReason = '',
    this.cancelledAt,
    this.cancelledBy,
    String? createdBy,
    String createdByUid = '',
    this.createdByName = 'Admin',
    this.createdAt,
    this.updatedAt,
  })  : status = invoiceStatus?.name.toUpperCase() ?? status,
        paymentStatus = (paymentStatus is InvoicePaymentStatus
            ? paymentStatus.name.toUpperCase()
            : (paymentStatusEnum?.name.toUpperCase() ??
                paymentStatus.toString().toUpperCase())),
        paymentTerms = modeOfPayment ?? paymentTerms,
        buyersOrderNo = buyerOrderNumber ?? buyersOrderNo,
        dispatchDocNo = dispatchDocNumber ?? dispatchDocNo,
        vehicleNo = motorVehicleNumber ?? vehicleNo,
        ackNo = acknowledgementNumber ?? ackNo,
        companyDetails = companySnapshot ??
            (companyDetails ?? CompanyBillingConfigModel.defaultConfig()),
        customerDetails = customerSnapshot ??
            (customerDetails ??
                const CustomerBillingModel(id: '', customerName: '')),
        totalTaxAmount = totalTax ?? totalTaxAmount,
        outstandingAmount = outstandingAmount ?? (grandTotal - totalPaid),
        createdByUid = createdBy ?? createdByUid;

  CompanyBillingConfigModel get companySnapshot => companyDetails;
  CustomerBillingModel get customerSnapshot => customerDetails;
  double get totalTax => totalTaxAmount;
  String? get motorVehicleNumber => vehicleNo.isNotEmpty ? vehicleNo : null;
  String? get buyerOrderNumber => buyersOrderNo.isNotEmpty ? buyersOrderNo : null;
  DateTime? get buyerOrderDate => buyersOrderDate;
  String? get dispatchDocNumber => dispatchDocNo.isNotEmpty ? dispatchDocNo : null;
  String? get acknowledgementNumber => ackNo.isNotEmpty ? ackNo : null;
  String? get acknowledgementDate => ackDate?.toIso8601String().split('T').first;
  String? get modeOfPayment => paymentTerms.isNotEmpty ? paymentTerms : null;

  InvoiceRecordStatus get invoiceStatus {
    if (status.toUpperCase() == 'ISSUED') return InvoiceRecordStatus.issued;
    if (status.toUpperCase() == 'CANCELLED') return InvoiceRecordStatus.cancelled;
    return InvoiceRecordStatus.draft;
  }

  InvoicePaymentStatus get paymentStatusEnum {
    if (paymentStatus.toUpperCase() == 'PAID') return InvoicePaymentStatus.paid;
    if (paymentStatus.toUpperCase() == 'PARTIALLY_PAID' || paymentStatus.toUpperCase() == 'PARTIAL') {
      return InvoicePaymentStatus.partial;
    }
    if (paymentStatus.toUpperCase() == 'OVERDUE') return InvoicePaymentStatus.overdue;
    return InvoicePaymentStatus.pending;
  }

  bool get isDraft => status == 'DRAFT';
  bool get isIssued => status == 'ISSUED';
  bool get isCancelled => status == 'CANCELLED';

  bool get isPaid => paymentStatus == 'PAID';
  bool get isPartiallyPaid => paymentStatus == 'PARTIALLY_PAID';
  bool get isUnpaid => paymentStatus == 'UNPAID';
  bool get isOverdue => paymentStatus == 'OVERDUE';

  factory InvoiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return InvoiceModel.fromMap(doc.id, data);
  }

  factory InvoiceModel.fromMap(dynamic p1, [dynamic p2]) {
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

    final rawCompany = (data['companyDetails'] ?? data['companySnapshot']) as Map<String, dynamic>? ?? {};
    final rawCustomer = (data['customerDetails'] ?? data['customerSnapshot']) as Map<String, dynamic>? ?? {};
    final rawItems = (data['items'] as List<dynamic>?) ?? [];

    final invoiceDate = parseDate(data['invoiceDate']) ?? DateTime.now();
    final grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (data['outstandingAmount'] as num?)?.toDouble() ??
        (grandTotal - totalPaid).clamp(0.0, double.infinity);

    return InvoiceModel(
      id: id,
      invoiceNumber: data['invoiceNumber'] as String? ?? 'DRAFT',
      financialYear: data['financialYear'] as String? ?? '2026-27',
      sequenceNumber: (data['sequenceNumber'] as num?)?.toInt() ?? 1,
      status: (data['status'] as String? ?? 'DRAFT').toUpperCase(),
      paymentStatus: (data['paymentStatus'] as String? ?? 'UNPAID').toUpperCase(),
      invoiceDate: invoiceDate,
      dueDate: parseDate(data['dueDate']),
      deliveryNote: data['deliveryNote'] as String? ?? '',
      paymentTerms: data['paymentTerms'] as String? ?? '',
      referenceNo: data['referenceNo'] as String? ?? '',
      referenceDate: parseDate(data['referenceDate']),
      otherReferences: data['otherReferences'] as String? ?? '',
      buyersOrderNo: data['buyersOrderNo'] as String? ?? '',
      buyersOrderDate: parseDate(data['buyersOrderDate']),
      dispatchDocNo: data['dispatchDocNo'] as String? ?? '',
      deliveryNoteDate: parseDate(data['deliveryNoteDate']),
      dispatchedThrough: data['dispatchedThrough'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      billOfLadingNo: data['billOfLadingNo'] as String? ?? '',
      vehicleNo: data['vehicleNo'] as String? ?? '',
      termsOfDelivery: data['termsOfDelivery'] as String? ?? '',
      irn: data['irn'] as String? ?? '',
      ackNo: data['ackNo'] as String? ?? '',
      ackDate: parseDate(data['ackDate']),
      companyDetails: CompanyBillingConfigModel.fromMap(rawCompany),
      customerId: data['customerId'] as String?,
      customerDetails: CustomerBillingModel.fromMap(
        data['customerId'] as String? ?? '',
        rawCustomer,
      ),
      items: rawItems
          .map((i) => InvoiceItemModel.fromMap(i as Map<String, dynamic>))
          .toList(),
      totalQuantity: (data['totalQuantity'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (data['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (data['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (data['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (data['igstAmount'] as num?)?.toDouble() ?? 0.0,
      totalTaxAmount: (data['totalTaxAmount'] as num?)?.toDouble() ?? 0.0,
      otherCharges: (data['otherCharges'] as num?)?.toDouble() ?? 0.0,
      roundOff: (data['roundOff'] as num?)?.toDouble() ?? 0.0,
      grandTotal: grandTotal,
      totalPaid: totalPaid,
      outstandingAmount: outstanding,
      amountInWords: data['amountInWords'] as String? ?? '',
      taxAmountInWords: data['taxAmountInWords'] as String? ?? '',
      isInterState: data['isInterState'] as bool? ?? false,
      cancellationReason: data['cancellationReason'] as String? ?? '',
      cancelledAt: parseDate(data['cancelledAt']),
      cancelledBy: data['cancelledBy'] as String?,
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Admin',
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber.trim(),
      'financialYear': financialYear.trim(),
      'sequenceNumber': sequenceNumber,
      'status': status.toUpperCase(),
      'paymentStatus': paymentStatus.toUpperCase(),
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'deliveryNote': deliveryNote.trim(),
      'paymentTerms': paymentTerms.trim(),
      'referenceNo': referenceNo.trim(),
      'referenceDate': referenceDate != null ? Timestamp.fromDate(referenceDate!) : null,
      'otherReferences': otherReferences.trim(),
      'buyersOrderNo': buyersOrderNo.trim(),
      'buyersOrderDate': buyersOrderDate != null ? Timestamp.fromDate(buyersOrderDate!) : null,
      'dispatchDocNo': dispatchDocNo.trim(),
      'deliveryNoteDate': deliveryNoteDate != null ? Timestamp.fromDate(deliveryNoteDate!) : null,
      'dispatchedThrough': dispatchedThrough.trim(),
      'destination': destination.trim(),
      'billOfLadingNo': billOfLadingNo.trim(),
      'vehicleNo': vehicleNo.trim(),
      'termsOfDelivery': termsOfDelivery.trim(),
      'irn': irn.trim(),
      'ackNo': ackNo.trim(),
      'ackDate': ackDate != null ? Timestamp.fromDate(ackDate!) : null,
      'companyDetails': companyDetails.toMap(),
      'customerId': customerId,
      'customerDetails': customerDetails.toMap(),
      'items': items.map((i) => i.toMap()).toList(),
      'totalQuantity': totalQuantity,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'totalTaxAmount': totalTaxAmount,
      'otherCharges': otherCharges,
      'roundOff': roundOff,
      'grandTotal': grandTotal,
      'totalPaid': totalPaid,
      'outstandingAmount': outstandingAmount,
      'amountInWords': amountInWords.trim(),
      'taxAmountInWords': taxAmountInWords.trim(),
      'isInterState': isInterState,
      'cancellationReason': cancellationReason.trim(),
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancelledBy': cancelledBy,
      'createdByUid': createdByUid,
      'createdByName': createdByName.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  InvoiceModel copyWith({
    String? id,
    String? invoiceNumber,
    String? financialYear,
    int? sequenceNumber,
    String? status,
    String? paymentStatus,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? deliveryNote,
    String? paymentTerms,
    String? referenceNo,
    DateTime? referenceDate,
    String? otherReferences,
    String? buyersOrderNo,
    DateTime? buyersOrderDate,
    String? dispatchDocNo,
    DateTime? deliveryNoteDate,
    String? dispatchedThrough,
    String? destination,
    String? billOfLadingNo,
    String? vehicleNo,
    String? termsOfDelivery,
    String? irn,
    String? ackNo,
    DateTime? ackDate,
    CompanyBillingConfigModel? companyDetails,
    String? customerId,
    CustomerBillingModel? customerDetails,
    List<InvoiceItemModel>? items,
    double? totalQuantity,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? totalTaxAmount,
    double? otherCharges,
    double? roundOff,
    double? grandTotal,
    double? totalPaid,
    double? outstandingAmount,
    String? amountInWords,
    String? taxAmountInWords,
    bool? isInterState,
    String? cancellationReason,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? createdBy,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      financialYear: financialYear ?? this.financialYear,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      referenceNo: referenceNo ?? this.referenceNo,
      referenceDate: referenceDate ?? this.referenceDate,
      otherReferences: otherReferences ?? this.otherReferences,
      buyersOrderNo: buyersOrderNo ?? this.buyersOrderNo,
      buyersOrderDate: buyersOrderDate ?? this.buyersOrderDate,
      dispatchDocNo: dispatchDocNo ?? this.dispatchDocNo,
      deliveryNoteDate: deliveryNoteDate ?? this.deliveryNoteDate,
      dispatchedThrough: dispatchedThrough ?? this.dispatchedThrough,
      destination: destination ?? this.destination,
      billOfLadingNo: billOfLadingNo ?? this.billOfLadingNo,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      termsOfDelivery: termsOfDelivery ?? this.termsOfDelivery,
      irn: irn ?? this.irn,
      ackNo: ackNo ?? this.ackNo,
      ackDate: ackDate ?? this.ackDate,
      companyDetails: companyDetails ?? this.companyDetails,
      customerId: customerId ?? this.customerId,
      customerDetails: customerDetails ?? this.customerDetails,
      items: items ?? this.items,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      totalTaxAmount: totalTaxAmount ?? this.totalTaxAmount,
      otherCharges: otherCharges ?? this.otherCharges,
      roundOff: roundOff ?? this.roundOff,
      grandTotal: grandTotal ?? this.grandTotal,
      totalPaid: totalPaid ?? this.totalPaid,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      amountInWords: amountInWords ?? this.amountInWords,
      taxAmountInWords: taxAmountInWords ?? this.taxAmountInWords,
      isInterState: isInterState ?? this.isInterState,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      createdByUid: createdBy ?? (createdByUid ?? this.createdByUid),
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
