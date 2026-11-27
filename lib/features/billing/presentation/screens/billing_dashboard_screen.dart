import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import '../../data/models/company_billing_config_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/services/indian_currency_formatter.dart';
import '../../data/services/invoice_pdf_service.dart';
import '../providers/billing_providers.dart';
import '../widgets/company_billing_config_dialog.dart';
import '../widgets/record_payment_dialog.dart';

class BillingDashboardScreen extends ConsumerStatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  ConsumerState<BillingDashboardScreen> createState() =>
      _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {
  final _searchCtrl = TextEditingController();
  final _pdfService = InvoicePdfService();

  int _currentPage = 0;
  static const int _pageSize = 15;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kpis = ref.watch(billingKpiMetricsProvider);
    final filteredInvoices = ref.watch(filteredInvoicesProvider);
    final filterState = ref.watch(billingFilterProvider);
    final compConfigAsync = ref.watch(companyBillingConfigProvider);
    final authState = ref.watch(authStateProvider);
    final userId = authState.user?.id ?? 'admin';

    // Pagination
    final totalItems = filteredInvoices.length;
    final maxPages = (totalItems / _pageSize).ceil();
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;
    final currentSlice = (startIndex < totalItems)
        ? filteredInvoices.sublist(startIndex, endIndex)
        : <InvoiceModel>[];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Bar
            _buildHeader(compConfigAsync.value),
            const SizedBox(height: 20),

            // 2. KPI Summary Cards
            _buildKpiCards(kpis),
            const SizedBox(height: 24),

            // 3. Search & Filter Bar
            _buildFilterToolbar(filterState),
            const SizedBox(height: 16),

            // 4. Invoices Table Card
            _buildTableCard(
              currentSlice: currentSlice,
              totalItems: totalItems,
              maxPages: maxPages,
              userId: userId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CompanyBillingConfigModel? compConfig) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 780;

        final titleBlock = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt_long,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Billing & Invoices',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 18 : 22,
                        ),
                  ),
                  Text(
                    'GST Invoices, customer billing, tax compliance & receipts',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: isCompact ? 11 : 13,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionsBlock = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                CompanyBillingConfigDialog.show(
                  context,
                  compConfig ?? CompanyBillingConfigModel.defaultConfig(),
                );
              },
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Company Profile'),
            ),
            FilledButton.icon(
              onPressed: () => context.goNamed(RouteNames.adminBillingCreate),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Invoice'),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              actionsBlock,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actionsBlock,
          ],
        );
      },
    );
  }

  Widget _buildKpiCards(BillingKpiMetrics kpis) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        final double childAspectRatio;

        if (width >= 1200) {
          crossAxisCount = 5;
          childAspectRatio = 1.6;
        } else if (width >= 800) {
          crossAxisCount = 3;
          childAspectRatio = 1.7;
        } else if (width >= 500) {
          crossAxisCount = 2;
          childAspectRatio = 1.65;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 2.4;
        }

        final cards = [
          _kpiCard('Total Invoices', '${kpis.totalInvoices}', IndianCurrencyFormatter.format(kpis.totalAmount), Colors.blue, Icons.receipt),
          _kpiCard('Total Revenue', IndianCurrencyFormatter.format(kpis.totalAmount), 'All issued invoices', Colors.indigo, Icons.account_balance_wallet),
          _kpiCard('Paid Invoices', '${kpis.paidInvoices}', IndianCurrencyFormatter.format(kpis.paidAmount), Colors.green, Icons.check_circle_outline),
          _kpiCard('Pending', '${kpis.pendingInvoices}', IndianCurrencyFormatter.format(kpis.pendingAmount), Colors.amber[800]!, Icons.pending_actions),
          _kpiCard('Overdue', '${kpis.overdueInvoices}', IndianCurrencyFormatter.format(kpis.overdueAmount), Colors.red, Icons.warning_amber),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _kpiCard(String title, String mainVal, String subVal, Color color, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mainVal,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subVal,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterToolbar(BillingFilterState filter) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final searchWidth = isNarrow ? constraints.maxWidth : 260.0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Input
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search invoice #, customer, GSTIN...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(billingFilterProvider.notifier).update((s) =>
                                    s.copyWith(searchQuery: ''));
                              },
                            )
                          : null,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (val) {
                      ref.read(billingFilterProvider.notifier).update((s) =>
                          s.copyWith(searchQuery: val));
                    },
                  ),
                ),

            // Status Filter Dropdown
            DropdownButton<String>(
              value: filter.paymentStatusFilter,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                DropdownMenuItem(value: 'PAID', child: Text('Status: Paid')),
                DropdownMenuItem(value: 'PENDING', child: Text('Status: Pending')),
                DropdownMenuItem(value: 'PARTIAL', child: Text('Status: Partial')),
                DropdownMenuItem(value: 'OVERDUE', child: Text('Status: Overdue')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(billingFilterProvider.notifier).update((s) =>
                      s.copyWith(paymentStatusFilter: val));
                }
              },
            ),

            // FY Filter Dropdown
            DropdownButton<String>(
              value: filter.financialYearFilter,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('FY: All')),
                DropdownMenuItem(value: '2026-27', child: Text('FY 2026-27')),
                DropdownMenuItem(value: '2025-26', child: Text('FY 2025-26')),
                DropdownMenuItem(value: '2024-25', child: Text('FY 2024-25')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(billingFilterProvider.notifier).update((s) =>
                      s.copyWith(financialYearFilter: val));
                }
              },
            ),

            // Date Range Picker
            OutlinedButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (range != null) {
                  ref.read(billingFilterProvider.notifier).update((s) => s.copyWith(
                    startDate: range.start,
                    endDate: range.end,
                  ));
                }
              },
              icon: const Icon(Icons.date_range, size: 16),
              label: Text(
                filter.startDate != null && filter.endDate != null
                    ? '${filter.startDate!.day}/${filter.startDate!.month} - ${filter.endDate!.day}/${filter.endDate!.month}'
                    : 'Filter Date',
              ),
            ),

            if (filter.startDate != null ||
                filter.paymentStatusFilter != 'ALL' ||
                filter.financialYearFilter != 'ALL' ||
                filter.searchQuery.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  ref.read(billingFilterProvider.notifier).reset();
                },
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text('Reset Filters'),
              ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildTableCard({
    required List<InvoiceModel> currentSlice,
    required int totalItems,
    required int maxPages,
    required String userId,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice History ($totalItems)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (currentSlice.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text(
                      'No invoices found matching criteria.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.goNamed(RouteNames.adminBillingCreate),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create First Invoice'),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                columns: const [
                  DataColumn(label: Text('Invoice No.')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Customer Name')),
                  DataColumn(label: Text('Customer GSTIN')),
                  DataColumn(label: Text('Total Amount')),
                  DataColumn(label: Text('Outstanding')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: currentSlice.map((inv) {
                  return DataRow(
                    cells: [
                      DataCell(
                        InkWell(
                          onTap: () => context.goNamed(
                            RouteNames.adminBillingDetails,
                            pathParameters: {'id': inv.id},
                          ),
                          child: Text(
                            inv.invoiceNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text('${inv.invoiceDate.day}/${inv.invoiceDate.month}/${inv.invoiceDate.year}')),
                      DataCell(Text(inv.customerSnapshot.customerName)),
                      DataCell(Text(inv.customerSnapshot.gstin)),
                      DataCell(Text(IndianCurrencyFormatter.format(inv.grandTotal))),
                      DataCell(
                        Text(
                          IndianCurrencyFormatter.format(inv.outstandingAmount),
                          style: TextStyle(
                            color: inv.outstandingAmount > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(_buildStatusBadge(inv)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              tooltip: 'View Invoice',
                              onPressed: () => context.goNamed(
                                RouteNames.adminBillingDetails,
                                pathParameters: {'id': inv.id},
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 18),
                              tooltip: 'Print Invoice',
                              onPressed: () => _pdfService.printInvoice(inv),
                            ),
                            if (inv.outstandingAmount > 0.01 &&
                                inv.invoiceStatus != InvoiceRecordStatus.cancelled)
                              IconButton(
                                icon: const Icon(Icons.payment, size: 18, color: Colors.green),
                                tooltip: 'Record Payment',
                                onPressed: () => RecordPaymentDialog.show(
                                  context,
                                  invoice: inv,
                                  userId: userId,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          // Pagination Controls
          if (maxPages > 1) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Page ${_currentPage + 1} of $maxPages',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < maxPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(InvoiceModel inv) {
    if (inv.invoiceStatus == InvoiceRecordStatus.cancelled) {
      return _badge('CANCELLED', Colors.red);
    }
    if (inv.invoiceStatus == InvoiceRecordStatus.draft) {
      return _badge('DRAFT', Colors.grey);
    }

    final isOverdue = inv.paymentStatusEnum != InvoicePaymentStatus.paid &&
        inv.dueDate != null &&
        inv.dueDate!.isBefore(DateTime.now());

    if (inv.paymentStatusEnum == InvoicePaymentStatus.paid) {
      return _badge('PAID', Colors.green);
    } else if (isOverdue) {
      return _badge('OVERDUE', Colors.deepOrange);
    } else if (inv.paymentStatusEnum == InvoicePaymentStatus.partial) {
      return _badge('PARTIAL', Colors.orange);
    } else {
      return _badge('PENDING', Colors.blue);
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
