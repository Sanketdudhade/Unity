import 'package:cloud_firestore/cloud_firestore.dart';

/// Company settings and bank/tax profile used as the default emitter on all invoices.
class CompanyBillingConfigModel {
  final String companyName;
  final String address;
  final String state;
  final String stateCode;
  final String gstin;
  final String email;
  final String pan;
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String branch;
  final String ifscCode;
  final String declaration;
  final String authorisedSignatory;
  final DateTime? updatedAt;
  final String? updatedByUid;

  String get registeredAddress => address;

  const CompanyBillingConfigModel({
    this.companyName = 'Unity Technologies',
    String? registeredAddress,
    this.address = 'B-15/2/61, MIDC Waluj, Dist. Aurangabad, 431136',
    this.state = 'Maharashtra',
    this.stateCode = '27',
    this.gstin = '27AXEPD7534P1Z1',
    this.email = 'info@unitytechnologies.in',
    this.pan = 'AXEPD7534P',
    this.bankName = 'State Bank of India',
    this.accountHolderName = 'UNITY TECHNOLOGIES',
    this.accountNumber = '345678901234',
    this.branch = 'Waluj MIDC, Aurangabad',
    this.ifscCode = 'SBIN0001234',
    this.declaration =
        'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.',
    this.authorisedSignatory = 'For UNITY TECHNOLOGIES',
    this.updatedAt,
    this.updatedByUid,
  });

  factory CompanyBillingConfigModel.defaultConfig() {
    return const CompanyBillingConfigModel();
  }

  factory CompanyBillingConfigModel.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return CompanyBillingConfigModel(
      companyName: data['companyName'] as String? ?? 'Unity Technologies',
      address: data['address'] as String? ??
          'B-15/2/61, MIDC Waluj, Dist. Aurangabad, 431136',
      state: data['state'] as String? ?? 'Maharashtra',
      stateCode: data['stateCode'] as String? ?? '27',
      gstin: data['gstin'] as String? ?? '27AXEPD7534P1Z1',
      email: data['email'] as String? ?? 'info@unitytechnologies.in',
      pan: data['pan'] as String? ?? 'AXEPD7534P',
      bankName: data['bankName'] as String? ?? 'State Bank of India',
      accountHolderName:
          data['accountHolderName'] as String? ?? 'UNITY TECHNOLOGIES',
      accountNumber: data['accountNumber'] as String? ?? '345678901234',
      branch: data['branch'] as String? ?? 'Waluj MIDC, Aurangabad',
      ifscCode: data['ifscCode'] as String? ?? 'SBIN0001234',
      declaration: data['declaration'] as String? ??
          'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.',
      authorisedSignatory:
          data['authorisedSignatory'] as String? ?? 'For UNITY TECHNOLOGIES',
      updatedAt: parseDate(data['updatedAt']),
      updatedByUid: data['updatedByUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName.trim(),
      'address': address.trim(),
      'state': state.trim(),
      'stateCode': stateCode.trim(),
      'gstin': gstin.trim().toUpperCase(),
      'email': email.trim().toLowerCase(),
      'pan': pan.trim().toUpperCase(),
      'bankName': bankName.trim(),
      'accountHolderName': accountHolderName.trim(),
      'accountNumber': accountNumber.trim(),
      'branch': branch.trim(),
      'ifscCode': ifscCode.trim().toUpperCase(),
      'declaration': declaration.trim(),
      'authorisedSignatory': authorisedSignatory.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
    };
  }

  CompanyBillingConfigModel copyWith({
    String? companyName,
    String? registeredAddress,
    String? address,
    String? state,
    String? stateCode,
    String? gstin,
    String? email,
    String? pan,
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? branch,
    String? ifscCode,
    String? declaration,
    String? authorisedSignatory,
    DateTime? updatedAt,
    String? updatedByUid,
  }) {
    return CompanyBillingConfigModel(
      companyName: companyName ?? this.companyName,
      address: registeredAddress ?? (address ?? this.address),
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      gstin: gstin ?? this.gstin,
      email: email ?? this.email,
      pan: pan ?? this.pan,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      branch: branch ?? this.branch,
      ifscCode: ifscCode ?? this.ifscCode,
      declaration: declaration ?? this.declaration,
      authorisedSignatory: authorisedSignatory ?? this.authorisedSignatory,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }
}
