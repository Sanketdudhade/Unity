import 'package:cloud_firestore/cloud_firestore.dart';

/// Single component row in an M/G or VMC Jobwork Purchase Order.
/// For M/G:
/// SR NO | DESCRIPTION | THK | WIDTH | LENGTH | GRADE | NOS | MILLING | GRINDING | RATE | TOTAL
/// For VMC:
/// SR NO | Description of Goods | HSN CODE | Quantity NOS | Rate | per | Amount
class JobworkPoItemModel {
  final int srNo;
  final String bomComponentId;
  final String description; // Name of component from BOM
  final String hsnCode; // Default 998898
  final String thk; // Thickness in mm (M/G)
  final String width; // Width in mm (M/G)
  final String length; // Length in mm (M/G)
  final String grade; // Material grade (e.g. MS, D2IMP)
  final int nos; // Quantity / pieces
  final String per; // Unit, default 'NOS'
  final double milling; // Milling value / rate (M/G)
  final double grinding; // Grinding value / rate (M/G)
  final double rate; // Unit rate
  final double total; // Total amount = rate * nos

  const JobworkPoItemModel({
    required this.srNo,
    this.bomComponentId = '',
    required this.description,
    this.hsnCode = '998898',
    this.thk = '',
    this.width = '',
    this.length = '',
    this.grade = '',
    this.nos = 1,
    this.per = 'NOS',
    this.milling = 0.0,
    this.grinding = 0.0,
    this.rate = 0.0,
    required this.total,
  });

  factory JobworkPoItemModel.fromMap(Map<String, dynamic> map) {
    return JobworkPoItemModel(
      srNo: (map['srNo'] as num?)?.toInt() ?? 1,
      bomComponentId: (map['bomComponentId'] as String? ?? '').trim(),
      description: (map['description'] as String? ?? '').trim(),
      hsnCode: (map['hsnCode'] as String? ?? '998898').trim(),
      thk: (map['thk'] as String? ?? '').trim(),
      width: (map['width'] as String? ?? '').trim(),
      length: (map['length'] as String? ?? '').trim(),
      grade: (map['grade'] as String? ?? '').trim(),
      nos: (map['nos'] as num?)?.toInt() ?? 1,
      per: (map['per'] as String? ?? 'NOS').trim(),
      milling: (map['milling'] as num?)?.toDouble() ?? 0.0,
      grinding: (map['grinding'] as num?)?.toDouble() ?? 0.0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'srNo': srNo,
      'bomComponentId': bomComponentId,
      'description': description.trim(),
      'hsnCode': hsnCode.trim(),
      'thk': thk.trim(),
      'width': width.trim(),
      'length': length.trim(),
      'grade': grade.trim(),
      'nos': nos,
      'per': per.trim(),
      'milling': milling,
      'grinding': grinding,
      'rate': rate,
      'total': total,
    };
  }

  JobworkPoItemModel copyWith({
    int? srNo,
    String? bomComponentId,
    String? description,
    String? hsnCode,
    String? thk,
    String? width,
    String? length,
    String? grade,
    int? nos,
    String? per,
    double? milling,
    double? grinding,
    double? rate,
    double? total,
  }) {
    return JobworkPoItemModel(
      srNo: srNo ?? this.srNo,
      bomComponentId: bomComponentId ?? this.bomComponentId,
      description: description ?? this.description,
      hsnCode: hsnCode ?? this.hsnCode,
      thk: thk ?? this.thk,
      width: width ?? this.width,
      length: length ?? this.length,
      grade: grade ?? this.grade,
      nos: nos ?? this.nos,
      per: per ?? this.per,
      milling: milling ?? this.milling,
      grinding: grinding ?? this.grinding,
      rate: rate ?? this.rate,
      total: total ?? this.total,
    );
  }
}

/// Represents a Jobwork Purchase Order created for Process 4 (M&G) or Process 9 (VMC).
class JobworkPoModel {
  final String id;
  final String poNumber; // e.g. "345/2026-27" or "011/2026-27"
  final String orderId;
  final String orderNumber;
  final String productName;
  final String processId;
  final String poType; // 'M_G' or 'VMC'
  final DateTime date;
  final String deliveryNote;
  final String suppliersRef; // e.g. "UT-3077"
  final String otherReference; // e.g. for VMC
  final String paymentTerms; // e.g. "PAYMENT = 90 DAYS"
  final String dispatchedThrough;
  final String destination;
  final String cityPortLoading; // e.g. for VMC
  final String cityPortDischarge; // e.g. for VMC

  // Vendor Details ("To,")
  final String vendorName; // e.g. "S.S Engineering" (VMC) or "SANKET ENGINEERING" (M&G)
  final String vendorAddress; // e.g. "Gat No.50, Dehu-Alandi Road, Talwade, Pune..."
  final String vendorGstin; // e.g. "27AJKPI1882P1ZJ"

  // Company Details
  final String companyName; // "UNITY TECHNOLOGIES"
  final String companyAddress; // "E-70/14, MIDC WALUJ, AURANGABAD 431136."
  final String companyGstin; // "27AXEPD7534P1Z1"
  final String companyEmail; // "unitytech17@gmail.com"

  // Line Items
  final List<JobworkPoItemModel> items;

  // Totals & Taxes
  final double subTotal;
  final double taxRate; // default 18.0%
  final double cgstAmount;
  final double sgstAmount;
  final double grandTotal;

  // Terms and conditions
  final List<String> termsAndConditions;

  final String status; // 'DRAFT', 'ISSUED', 'COMPLETED', 'CANCELLED'
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const JobworkPoModel({
    required this.id,
    required this.poNumber,
    required this.orderId,
    required this.orderNumber,
    required this.productName,
    required this.processId,
    this.poType = 'M_G',
    required this.date,
    this.deliveryNote = '',
    this.suppliersRef = 'UT-3077',
    this.otherReference = '',
    this.paymentTerms = 'PAYMENT = 90 DAYS',
    this.dispatchedThrough = '',
    this.destination = 'Waluj MIDC, Aurangabad',
    this.cityPortLoading = '',
    this.cityPortDischarge = '',
    required this.vendorName,
    this.vendorAddress = '',
    this.vendorGstin = '',
    this.companyName = 'UNITY TECHNOLOGIES',
    this.companyAddress = 'E-70/14, MIDC WALUJ, AURANGABAD 431136.',
    this.companyGstin = '27AXEPD7534P1Z1',
    this.companyEmail = 'unitytech17@gmail.com',
    required this.items,
    required this.subTotal,
    this.taxRate = 18.0,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.grandTotal,
    this.termsAndConditions = const [
      'PAYMENT = 90 DAYS',
      'DELIVERY PERIOD AS PER DISCUSS',
      'TAXES - AS A APPLICABLE  18% (C GST & S GST )',
    ],
    this.status = 'ISSUED',
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isVmc => poType == 'VMC';
  int get totalNos => items.fold(0, (acc, item) => acc + item.nos);

  factory JobworkPoModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    final rawItems = (data['items'] as List<dynamic>?) ?? [];
    final itemsList = rawItems
        .map((e) => JobworkPoItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return JobworkPoModel(
      id: id ?? (data['id'] as String? ?? ''),
      poNumber: (data['poNumber'] as String? ?? '').trim(),
      orderId: (data['orderId'] as String? ?? '').trim(),
      orderNumber: (data['orderNumber'] as String? ?? '').trim(),
      productName: (data['productName'] as String? ?? '').trim(),
      processId: (data['processId'] as String? ?? '').trim(),
      poType: (data['poType'] as String? ?? 'M_G').trim(),
      date: parseDate(data['date']) ?? DateTime.now(),
      deliveryNote: (data['deliveryNote'] as String? ?? '').trim(),
      suppliersRef: (data['suppliersRef'] as String? ?? 'UT-3077').trim(),
      otherReference: (data['otherReference'] as String? ?? '').trim(),
      paymentTerms: (data['paymentTerms'] as String? ?? 'PAYMENT = 90 DAYS').trim(),
      dispatchedThrough: (data['dispatchedThrough'] as String? ?? '').trim(),
      destination: (data['destination'] as String? ?? '').trim(),
      cityPortLoading: (data['cityPortLoading'] as String? ?? '').trim(),
      cityPortDischarge: (data['cityPortDischarge'] as String? ?? '').trim(),
      vendorName: (data['vendorName'] as String? ?? '').trim(),
      vendorAddress: (data['vendorAddress'] as String? ?? '').trim(),
      vendorGstin: (data['vendorGstin'] as String? ?? '').trim(),
      companyName: (data['companyName'] as String? ?? 'UNITY TECHNOLOGIES').trim(),
      companyAddress: (data['companyAddress'] as String? ?? 'E-70/14, MIDC WALUJ, AURANGABAD 431136.').trim(),
      companyGstin: (data['companyGstin'] as String? ?? '27AXEPD7534P1Z1').trim(),
      companyEmail: (data['companyEmail'] as String? ?? 'unitytech17@gmail.com').trim(),
      items: itemsList,
      subTotal: (data['subTotal'] as num?)?.toDouble() ?? 0.0,
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 18.0,
      cgstAmount: (data['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (data['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (data['grandTotal'] as num?)?.toDouble() ?? 0.0,
      termsAndConditions: (data['termsAndConditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [
            'PAYMENT = 90 DAYS',
            'DELIVERY PERIOD AS PER DISCUSS',
            'TAXES - AS A APPLICABLE  18% (C GST & S GST )',
          ],
      status: (data['status'] as String? ?? 'ISSUED').toUpperCase(),
      createdBy: (data['createdBy'] as String? ?? '').trim(),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'poNumber': poNumber.trim(),
      'orderId': orderId.trim(),
      'orderNumber': orderNumber.trim(),
      'productName': productName.trim(),
      'processId': processId.trim(),
      'poType': poType.trim(),
      'date': Timestamp.fromDate(date),
      'deliveryNote': deliveryNote.trim(),
      'suppliersRef': suppliersRef.trim(),
      'otherReference': otherReference.trim(),
      'paymentTerms': paymentTerms.trim(),
      'dispatchedThrough': dispatchedThrough.trim(),
      'destination': destination.trim(),
      'cityPortLoading': cityPortLoading.trim(),
      'cityPortDischarge': cityPortDischarge.trim(),
      'vendorName': vendorName.trim(),
      'vendorAddress': vendorAddress.trim(),
      'vendorGstin': vendorGstin.trim(),
      'companyName': companyName.trim(),
      'companyAddress': companyAddress.trim(),
      'companyGstin': companyGstin.trim(),
      'companyEmail': companyEmail.trim(),
      'items': items.map((e) => e.toMap()).toList(),
      'subTotal': subTotal,
      'taxRate': taxRate,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'grandTotal': grandTotal,
      'termsAndConditions': termsAndConditions,
      'status': status.toUpperCase(),
      'createdBy': createdBy.trim(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  JobworkPoModel copyWith({
    String? id,
    String? poNumber,
    String? orderId,
    String? orderNumber,
    String? productName,
    String? processId,
    String? poType,
    DateTime? date,
    String? deliveryNote,
    String? suppliersRef,
    String? otherReference,
    String? paymentTerms,
    String? dispatchedThrough,
    String? destination,
    String? cityPortLoading,
    String? cityPortDischarge,
    String? vendorName,
    String? vendorAddress,
    String? vendorGstin,
    String? companyName,
    String? companyAddress,
    String? companyGstin,
    String? companyEmail,
    List<JobworkPoItemModel>? items,
    double? subTotal,
    double? taxRate,
    double? cgstAmount,
    double? sgstAmount,
    double? grandTotal,
    List<String>? termsAndConditions,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobworkPoModel(
      id: id ?? this.id,
      poNumber: poNumber ?? this.poNumber,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      productName: productName ?? this.productName,
      processId: processId ?? this.processId,
      poType: poType ?? this.poType,
      date: date ?? this.date,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      suppliersRef: suppliersRef ?? this.suppliersRef,
      otherReference: otherReference ?? this.otherReference,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      dispatchedThrough: dispatchedThrough ?? this.dispatchedThrough,
      destination: destination ?? this.destination,
      cityPortLoading: cityPortLoading ?? this.cityPortLoading,
      cityPortDischarge: cityPortDischarge ?? this.cityPortDischarge,
      vendorName: vendorName ?? this.vendorName,
      vendorAddress: vendorAddress ?? this.vendorAddress,
      vendorGstin: vendorGstin ?? this.vendorGstin,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      companyGstin: companyGstin ?? this.companyGstin,
      companyEmail: companyEmail ?? this.companyEmail,
      items: items ?? this.items,
      subTotal: subTotal ?? this.subTotal,
      taxRate: taxRate ?? this.taxRate,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
