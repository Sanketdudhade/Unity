import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';

class InvoiceNumberService {
  final FirebaseFirestore _firestore;
  final String? orgId;

  InvoiceNumberService({FirebaseFirestore? firestore, this.orgId})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String _counterCollectionPath() {
    if (orgId != null && orgId!.isNotEmpty) {
      return FirestorePaths.invoiceCountersCollection(orgId!);
    }
    return FirestorePaths.invoiceCounters;
  }

  /// Returns the Financial Year string for the given date (e.g. "2026-27").
  /// Indian FY runs from 1st April to 31st March.
  static String getFinancialYear([DateTime? date]) {
    final d = date ?? DateTime.now();
    final year = d.year;
    if (d.month >= 4) {
      final nextYearShort = ((year + 1) % 100).toString().padLeft(2, '0');
      return '$year-$nextYearShort';
    } else {
      final curYearShort = (year % 100).toString().padLeft(2, '0');
      return '${year - 1}-$curYearShort';
    }
  }

  /// Generates the next atomic sequential invoice number for the given financial year.
  /// Uses Firestore runTransaction to guarantee uniqueness and prevent race conditions.
  Future<String> generateNextInvoiceNumber({
    String prefix = 'UT',
    DateTime? date,
  }) async {
    final fy = getFinancialYear(date);
    final counterRef = _firestore
        .collection(_counterCollectionPath())
        .doc('FY_$fy');

    return await _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int nextSeq = 1;

      if (snapshot.exists && snapshot.data() != null) {
        final currentSeq = snapshot.data()!['lastSequence'] as int? ?? 0;
        nextSeq = currentSeq + 1;
        transaction.update(counterRef, {
          'lastSequence': nextSeq,
          'financialYear': fy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(counterRef, {
          'lastSequence': nextSeq,
          'financialYear': fy,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final seqPadded = nextSeq.toString().padLeft(4, '0');
      return '$prefix/$fy/$seqPadded';
    });
  }

  /// Peeks the next prospective invoice number without advancing the counter.
  Future<String> peekNextInvoiceNumber({
    String prefix = 'UT',
    DateTime? date,
  }) async {
    final fy = getFinancialYear(date);
    int nextSeq = 1;

    try {
      final counterDoc = await _firestore
          .collection(_counterCollectionPath())
          .doc('FY_$fy')
          .get();

      if (counterDoc.exists && counterDoc.data() != null) {
        final currentSeq = counterDoc.data()!['lastSequence'] as int? ?? 0;
        nextSeq = currentSeq + 1;
      }
    } catch (_) {
      // Fallback cleanly to sequence 1 if counter doc does not exist yet
      nextSeq = 1;
    }

    final seqPadded = nextSeq.toString().padLeft(4, '0');
    return '$prefix/$fy/$seqPadded';
  }
}
