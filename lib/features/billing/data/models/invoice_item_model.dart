/// Single line item within a GST Invoice.
class InvoiceItemModel {
  final int slNo;
  final String? productId;
  final String? productCode;
  final String description;
  final String hsnSac;
  final double quantity;
  final String unit;
  final double rate;
  final double discountPercentage;
  final double taxableAmount;
  final double gstRate; // e.g. 18.0
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double igstRate;
  final double igstAmount;
  final double totalAmount;

  const InvoiceItemModel({
    this.slNo = 1,
    this.productId,
    this.productCode,
    required this.description,
    this.hsnSac = '',
    required this.quantity,
    this.unit = 'NOS',
    required this.rate,
    double? discountPercent,
    double discountPercentage = 0.0,
    double? discountAmount,
    required this.taxableAmount,
    this.gstRate = 18.0,
    this.cgstRate = 0.0,
    this.cgstAmount = 0.0,
    this.sgstRate = 0.0,
    this.sgstAmount = 0.0,
    this.igstRate = 0.0,
    this.igstAmount = 0.0,
    required this.totalAmount,
  }) : discountPercentage = discountPercent ?? discountPercentage;

  double get discountPercent => discountPercentage;
  double get grossAmount => quantity * rate;
  double get discountAmount => grossAmount * (discountPercentage / 100.0);
  double get totalTax => isInterState ? igstAmount : (cgstAmount + sgstAmount);
  bool get isInterState => igstAmount > 0 || (igstRate > 0 && cgstRate == 0);

  /// Helper factory to compute all amounts cleanly based on intra- vs inter-state rules
  factory InvoiceItemModel.calculate({
    int slNo = 1,
    String? productId,
    String? productCode,
    required String description,
    String hsnSac = '',
    required double quantity,
    String unit = 'NOS',
    required double rate,
    double? discountPercent,
    double discountPercentage = 0.0,
    double gstRate = 18.0,
    bool isInterState = false,
    bool? isIntraState,
  }) {
    final effectiveDiscount = discountPercent ?? discountPercentage;
    final effectiveIsInterState = isIntraState != null ? !isIntraState : isInterState;
    final gross = quantity * rate;
    final discount = gross * (effectiveDiscount / 100.0);
    final taxable = (gross - discount).clamp(0.0, double.infinity);

    final double cgstRate;
    final double cgstAmount;
    final double sgstRate;
    final double sgstAmount;
    final double igstRate;
    final double igstAmount;

    if (effectiveIsInterState) {
      cgstRate = 0.0;
      cgstAmount = 0.0;
      sgstRate = 0.0;
      sgstAmount = 0.0;
      igstRate = gstRate;
      igstAmount = taxable * (igstRate / 100.0);
    } else {
      cgstRate = gstRate / 2.0;
      cgstAmount = taxable * (cgstRate / 100.0);
      sgstRate = gstRate / 2.0;
      sgstAmount = taxable * (sgstRate / 100.0);
      igstRate = 0.0;
      igstAmount = 0.0;
    }

    final total = taxable + (effectiveIsInterState ? igstAmount : (cgstAmount + sgstAmount));

    return InvoiceItemModel(
      slNo: slNo,
      productId: productId,
      productCode: productCode,
      description: description,
      hsnSac: hsnSac,
      quantity: quantity,
      unit: unit,
      rate: rate,
      discountPercentage: effectiveDiscount,
      taxableAmount: taxable,
      gstRate: gstRate,
      cgstRate: cgstRate,
      cgstAmount: cgstAmount,
      sgstRate: sgstRate,
      sgstAmount: sgstAmount,
      igstRate: igstRate,
      igstAmount: igstAmount,
      totalAmount: total,
    );
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> data) {
    return InvoiceItemModel(
      slNo: (data['slNo'] as num?)?.toInt() ?? 1,
      productId: data['productId'] as String?,
      productCode: data['productCode'] as String?,
      description: data['description'] as String? ?? '',
      hsnSac: data['hsnSac'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: data['unit'] as String? ?? 'NOS',
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      discountPercentage:
          (data['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (data['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (data['gstRate'] as num?)?.toDouble() ?? 18.0,
      cgstRate: (data['cgstRate'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (data['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstRate: (data['sgstRate'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (data['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      igstRate: (data['igstRate'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (data['igstAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slNo': slNo,
      'productId': productId,
      'productCode': productCode,
      'description': description.trim(),
      'hsnSac': hsnSac.trim(),
      'quantity': quantity,
      'unit': unit.trim(),
      'rate': rate,
      'discountPercentage': discountPercentage,
      'taxableAmount': taxableAmount,
      'gstRate': gstRate,
      'cgstRate': cgstRate,
      'cgstAmount': cgstAmount,
      'sgstRate': sgstRate,
      'sgstAmount': sgstAmount,
      'igstRate': igstRate,
      'igstAmount': igstAmount,
      'totalAmount': totalAmount,
    };
  }

  InvoiceItemModel copyWith({
    int? slNo,
    String? productId,
    String? productCode,
    String? description,
    String? hsnSac,
    double? quantity,
    String? unit,
    double? rate,
    double? discountPercentage,
    double? taxableAmount,
    double? gstRate,
    double? cgstRate,
    double? cgstAmount,
    double? sgstRate,
    double? sgstAmount,
    double? igstRate,
    double? igstAmount,
    double? totalAmount,
  }) {
    return InvoiceItemModel(
      slNo: slNo ?? this.slNo,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      description: description ?? this.description,
      hsnSac: hsnSac ?? this.hsnSac,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      gstRate: gstRate ?? this.gstRate,
      cgstRate: cgstRate ?? this.cgstRate,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstRate: sgstRate ?? this.sgstRate,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstRate: igstRate ?? this.igstRate,
      igstAmount: igstAmount ?? this.igstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
