import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/company_billing_config_model.dart';
import '../models/customer_billing_model.dart';
import '../models/invoice_model.dart';
import '../models/invoice_payment_model.dart';
import '../services/invoice_number_service.dart';

class BillingRepository {
  final FirebaseFirestore _firestore;
  final String? orgId;
  final InvoiceNumberService _numberService;

  BillingRepository({
    FirebaseFirestore? firestore,
    this.orgId,
    InvoiceNumberService? numberService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _numberService = numberService ??
            InvoiceNumberService(firestore: firestore, orgId: orgId);

  String _invoicesPath() => (orgId != null && orgId!.isNotEmpty)
      ? FirestorePaths.invoicesCollection(orgId!)
      : FirestorePaths.invoices;

  String _customersPath() => (orgId != null && orgId!.isNotEmpty)
      ? FirestorePaths.billingCustomersCollection(orgId!)
      : FirestorePaths.customers;

  String _billingConfigDocPath() => (orgId != null && orgId!.isNotEmpty)
      ? FirestorePaths.billingConfigDoc(orgId!)
      : 'billingConfig/company_profile';

  // ==================== INVOICES ====================

  Stream<List<InvoiceModel>> streamInvoices() {
    return _firestore
        .collection(_invoicesPath())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvoiceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<InvoiceModel?> getInvoice(String invoiceId) async {
    final doc = await _firestore.collection(_invoicesPath()).doc(invoiceId).get();
    if (!doc.exists || doc.data() == null) return null;
    return InvoiceModel.fromMap(doc.data()!, doc.id);
  }

  /// Creates a new invoice. If the invoice number is blank, generates one atomically.
  Future<String> createInvoice(InvoiceModel invoice, {required String userId}) async {
    final docRef = _firestore.collection(_invoicesPath()).doc();
    String finalInvoiceNumber = invoice.invoiceNumber;

    if (finalInvoiceNumber.isEmpty || finalInvoiceNumber.startsWith('PREVIEW')) {
      finalInvoiceNumber = await _numberService.generateNextInvoiceNumber(
        date: invoice.invoiceDate,
      );
    }

    final toSave = invoice.copyWith(
      id: docRef.id,
      invoiceNumber: finalInvoiceNumber,
      createdBy: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      outstandingAmount: invoice.grandTotal - invoice.totalPaid,
    );

    await docRef.set(toSave.toMap());
    return docRef.id;
  }

  /// Updates an existing draft invoice
  Future<void> updateDraftInvoice(InvoiceModel invoice, {required String userId}) async {
    final docRef = _firestore.collection(_invoicesPath()).doc(invoice.id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw Exception('Invoice ${invoice.id} not found.');
    }

    final existingStatus = snapshot.data()?['status'] as String? ??
        snapshot.data()?['invoiceStatus'] as String?;
    if (existingStatus != null &&
        existingStatus.toUpperCase() != 'DRAFT') {
      throw Exception('Only draft invoices can be edited directly.');
    }

    final toSave = invoice.copyWith(
      updatedAt: DateTime.now(),
      outstandingAmount: invoice.grandTotal - invoice.totalPaid,
    );

    await docRef.update(toSave.toMap());
  }

  /// Cancels an issued invoice with an audit reason
  Future<void> cancelInvoice({
    required String invoiceId,
    required String reason,
    required String userId,
  }) async {
    final docRef = _firestore.collection(_invoicesPath()).doc(invoiceId);
    await docRef.update({
      'status': 'CANCELLED',
      'cancellationReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes draft invoice permanently (allowed only for drafts)
  Future<void> deleteDraftInvoice(String invoiceId) async {
    final docRef = _firestore.collection(_invoicesPath()).doc(invoiceId);
    final snapshot = await docRef.get();
    if (snapshot.exists &&
        (snapshot.data()?['status'] == 'DRAFT' ||
            snapshot.data()?['invoiceStatus'] == 'DRAFT')) {
      await docRef.delete();
    } else {
      throw Exception('Only draft invoices can be deleted.');
    }
  }

  // ==================== PAYMENTS ====================

  Stream<List<InvoicePaymentModel>> streamPayments(String invoiceId) {
    return _firestore
        .collection(_invoicesPath())
        .doc(invoiceId)
        .collection('payments')
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvoicePaymentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> recordPayment({
    required String invoiceId,
    required InvoicePaymentModel payment,
    required String userId,
  }) async {
    final invoiceRef = _firestore.collection(_invoicesPath()).doc(invoiceId);
    final paymentRef = invoiceRef.collection('payments').doc();

    await _firestore.runTransaction((transaction) async {
      final invoiceDoc = await transaction.get(invoiceRef);
      if (!invoiceDoc.exists || invoiceDoc.data() == null) {
        throw Exception('Invoice $invoiceId does not exist.');
      }

      final data = invoiceDoc.data()!;
      final grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
      final currentPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;

      final newTotalPaid = currentPaid + payment.amount;
      final newOutstanding = max(0.0, grandTotal - newTotalPaid);

      String newPaymentStatus;
      if (newOutstanding <= 0.01) {
        newPaymentStatus = 'PAID';
      } else if (newTotalPaid > 0) {
        newPaymentStatus = 'PARTIAL';
      } else {
        newPaymentStatus = 'PENDING';
      }

      final paymentData = payment.copyWith(
        id: paymentRef.id,
        invoiceId: invoiceId,
        recordedBy: userId,
        createdAt: DateTime.now(),
      );

      transaction.set(paymentRef, paymentData.toMap());
      transaction.update(invoiceRef, {
        'totalPaid': newTotalPaid,
        'outstandingAmount': newOutstanding,
        'paymentStatus': newPaymentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ==================== CUSTOMERS ====================

  Stream<List<CustomerBillingModel>> streamCustomers() {
    return _firestore
        .collection(_customersPath())
        .orderBy('customerName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CustomerBillingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> saveCustomer(CustomerBillingModel customer) async {
    final docRef = customer.id.isNotEmpty
        ? _firestore.collection(_customersPath()).doc(customer.id)
        : _firestore.collection(_customersPath()).doc();

    await docRef.set(customer.copyWith(id: docRef.id).toMap(), SetOptions(merge: true));
  }

  // ==================== COMPANY CONFIG ====================

  Future<CompanyBillingConfigModel> getCompanyBillingConfig() async {
    final doc = await _firestore.doc(_billingConfigDocPath()).get();

    if (doc.exists && doc.data() != null) {
      return CompanyBillingConfigModel.fromMap(doc.data()!);
    }
    return CompanyBillingConfigModel.defaultConfig();
  }

  Future<void> saveCompanyBillingConfig(CompanyBillingConfigModel config) async {
    await _firestore
        .doc(_billingConfigDocPath())
        .set(config.toMap(), SetOptions(merge: true));
  }
}
