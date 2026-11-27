import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/company_billing_config_model.dart';
import '../../data/models/customer_billing_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/invoice_payment_model.dart';
import '../../data/repositories/billing_repository.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId ?? 'org_unity_001';
  return BillingRepository(orgId: orgId);
});

/// Company Billing Config Provider
final companyBillingConfigProvider =
    FutureProvider<CompanyBillingConfigModel>((ref) async {
  final repo = ref.watch(billingRepositoryProvider);
  return repo.getCompanyBillingConfig();
});

/// Stream of all saved customers
final billingCustomersStreamProvider =
    StreamProvider<List<CustomerBillingModel>>((ref) {
  final repo = ref.watch(billingRepositoryProvider);
  return repo.streamCustomers();
});

/// Stream of all invoices
final invoicesStreamProvider = StreamProvider<List<InvoiceModel>>((ref) {
  final repo = ref.watch(billingRepositoryProvider);
  return repo.streamInvoices();
});

/// Stream of payments for a specific invoice
final invoicePaymentsStreamProvider =
    StreamProvider.family<List<InvoicePaymentModel>, String>((ref, invoiceId) {
  final repo = ref.watch(billingRepositoryProvider);
  return repo.streamPayments(invoiceId);
});

/// Filter state class
class BillingFilterState {
  final String searchQuery;
  final String paymentStatusFilter; // 'ALL', 'PAID', 'PENDING', 'PARTIAL', 'OVERDUE'
  final String financialYearFilter; // 'ALL' or specific like '2026-27'
  final DateTime? startDate;
  final DateTime? endDate;

  const BillingFilterState({
    this.searchQuery = '',
    this.paymentStatusFilter = 'ALL',
    this.financialYearFilter = 'ALL',
    this.startDate,
    this.endDate,
  });

  BillingFilterState copyWith({
    String? searchQuery,
    String? paymentStatusFilter,
    String? financialYearFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
  }) {
    return BillingFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      paymentStatusFilter: paymentStatusFilter ?? this.paymentStatusFilter,
      financialYearFilter: financialYearFilter ?? this.financialYearFilter,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }
}

class BillingFilterNotifier extends Notifier<BillingFilterState> {
  @override
  BillingFilterState build() => const BillingFilterState();

  void update(BillingFilterState Function(BillingFilterState) updater) {
    state = updater(state);
  }

  void reset() {
    state = const BillingFilterState();
  }
}

final billingFilterProvider =
    NotifierProvider<BillingFilterNotifier, BillingFilterState>(
  BillingFilterNotifier.new,
);

/// Filtered invoices list
final filteredInvoicesProvider = Provider<List<InvoiceModel>>((ref) {
  final invoicesAsync = ref.watch(invoicesStreamProvider);
  final filter = ref.watch(billingFilterProvider);

  return invoicesAsync.maybeWhen(
    data: (invoices) {
      return invoices.where((inv) {
        // Search query filter
        if (filter.searchQuery.trim().isNotEmpty) {
          final query = filter.searchQuery.toLowerCase().trim();
          final matchNum = inv.invoiceNumber.toLowerCase().contains(query);
          final matchCust =
              inv.customerSnapshot.customerName.toLowerCase().contains(query);
          final matchGstin =
              inv.customerSnapshot.gstin.toLowerCase().contains(query);
          if (!matchNum && !matchCust && !matchGstin) return false;
        }

        // Payment status filter
        if (filter.paymentStatusFilter != 'ALL') {
          final isOverdue = inv.paymentStatusEnum != InvoicePaymentStatus.paid &&
              inv.dueDate != null &&
              inv.dueDate!.isBefore(DateTime.now());

          if (filter.paymentStatusFilter == 'OVERDUE') {
            if (!isOverdue) return false;
          } else {
            if (inv.paymentStatus.toUpperCase() != filter.paymentStatusFilter) {
              return false;
            }
          }
        }

        // Financial year filter
        if (filter.financialYearFilter != 'ALL') {
          if (inv.financialYear != filter.financialYearFilter) return false;
        }

        // Date range filter
        if (filter.startDate != null) {
          if (inv.invoiceDate.isBefore(filter.startDate!)) return false;
        }
        if (filter.endDate != null) {
          final endOfDay = DateTime(
            filter.endDate!.year,
            filter.endDate!.month,
            filter.endDate!.day,
            23,
            59,
            59,
          );
          if (inv.invoiceDate.isAfter(endOfDay)) return false;
        }

        return true;
      }).toList();
    },
    orElse: () => [],
  );
});

/// KPI Metrics model
class BillingKpiMetrics {
  final int totalInvoices;
  final double totalAmount;
  final int paidInvoices;
  final double paidAmount;
  final int pendingInvoices;
  final double pendingAmount;
  final int overdueInvoices;
  final double overdueAmount;

  const BillingKpiMetrics({
    this.totalInvoices = 0,
    this.totalAmount = 0.0,
    this.paidInvoices = 0,
    this.paidAmount = 0.0,
    this.pendingInvoices = 0,
    this.pendingAmount = 0.0,
    this.overdueInvoices = 0,
    this.overdueAmount = 0.0,
  });
}

/// Computed KPI Metrics
final billingKpiMetricsProvider = Provider<BillingKpiMetrics>((ref) {
  final invoicesAsync = ref.watch(invoicesStreamProvider);

  return invoicesAsync.maybeWhen(
    data: (invoices) {
      int totalInvoices = 0;
      double totalAmount = 0;
      int paidCount = 0;
      double paidAmt = 0;
      int pendingCount = 0;
      double pendingAmt = 0;
      int overdueCount = 0;
      double overdueAmt = 0;

      final now = DateTime.now();

      for (final inv in invoices) {
        if (inv.invoiceStatus == InvoiceRecordStatus.cancelled) continue;

        totalInvoices++;
        totalAmount += inv.grandTotal;

        if (inv.paymentStatusEnum == InvoicePaymentStatus.paid) {
          paidCount++;
          paidAmt += inv.grandTotal;
        } else {
          final isOverdue =
              inv.dueDate != null && inv.dueDate!.isBefore(now);
          if (isOverdue) {
            overdueCount++;
            overdueAmt += inv.outstandingAmount;
          } else {
            pendingCount++;
            pendingAmt += inv.outstandingAmount;
          }
        }
      }

      return BillingKpiMetrics(
        totalInvoices: totalInvoices,
        totalAmount: totalAmount,
        paidInvoices: paidCount,
        paidAmount: paidAmt,
        pendingInvoices: pendingCount,
        pendingAmount: pendingAmt,
        overdueInvoices: overdueCount,
        overdueAmount: overdueAmt,
      );
    },
    orElse: () => const BillingKpiMetrics(),
  );
});
