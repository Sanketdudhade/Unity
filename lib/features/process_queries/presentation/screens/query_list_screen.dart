import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/process_queries/data/models/process_query_model.dart';
import 'package:unity/features/process_queries/presentation/providers/query_providers.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';

class QueryListScreen extends ConsumerStatefulWidget {
  const QueryListScreen({super.key});

  @override
  ConsumerState<QueryListScreen> createState() => _QueryListScreenState();
}

class _QueryListScreenState extends ConsumerState<QueryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      case 'low':
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return AppColors.error;
      case 'in_review':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  void _showRaiseTicketDialog(BuildContext context, String orgId) {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final user = ref.read(authStateProvider).user;

    final ticketNum = 'TK-${DateTime.now().year}-${(100 + (DateTime.now().millisecond % 900))}';
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final woController = TextEditingController();
    String selectedSeverity = 'medium';
    String selectedStage = 'Cutting & Forming';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final orders = ref.watch(productionOrdersStreamProvider).value ?? [];

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Raise Shop-Floor Ticket', style: AppTextStyles.titleMedium),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Issue Summary *',
                          hintText: 'e.g. Hydraulic pressure drop on Lathe 2',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Summary is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedSeverity,
                              decoration: const InputDecoration(
                                labelText: 'Severity',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Low')),
                                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                DropdownMenuItem(value: 'high', child: Text('High')),
                                DropdownMenuItem(value: 'critical', child: Text('Critical')),
                              ],
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedSeverity = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStage,
                              decoration: const InputDecoration(
                                labelText: 'Process Stage',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Cutting & Forming', child: Text('Cutting')),
                                DropdownMenuItem(value: 'Machining', child: Text('Machining')),
                                DropdownMenuItem(value: 'Welding', child: Text('Welding')),
                                DropdownMenuItem(value: 'Assembly', child: Text('Assembly')),
                                DropdownMenuItem(value: 'Inspection', child: Text('Inspection')),
                                DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                              ],
                              onChanged: (v) {
                                if (v != null) setDialogState(() => selectedStage = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (orders.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: null,
                          decoration: const InputDecoration(
                            labelText: 'Related Work Order (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select work order...'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('None / General Facility')),
                            ...orders.map((o) => DropdownMenuItem(
                                  value: o.orderNumber,
                                  child: Text('${o.orderNumber} (${o.productName})', overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) => woController.text = v ?? '',
                        )
                      else
                        TextFormField(
                          controller: woController,
                          decoration: const InputDecoration(
                            labelText: 'Work Order (Optional)',
                            hintText: 'e.g. WO-2026-081',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Detailed Description *',
                          hintText: 'Describe machine condition, error code, or defect observed...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final query = ProcessQuery(
                          id: '',
                          ticketNumber: ticketNum,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          workOrder: woController.text.trim(),
                          stage: selectedStage,
                          severity: selectedSeverity,
                          status: 'open',
                          reportedByName: user?.fullName ?? 'Operator',
                          reportedByUid: user?.uid ?? '',
                          createdAt: DateTime.now(),
                        );

                        try {
                          await ref.read(queryRepositoryProvider).createQuery(orgId, query);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Ticket ${query.ticketNumber} submitted successfully!'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to submit ticket: $e'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Ticket'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResolveDialog(BuildContext context, String orgId, ProcessQuery query) {
    final messenger = ScaffoldMessenger.of(context);
    final resolutionController = TextEditingController(text: query.resolutionNotes);
    String selectedStatus = query.status == 'resolved' ? 'resolved' : 'resolved';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Resolve Ticket ${query.ticketNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(query.title, style: AppTextStyles.titleSmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Update Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'in_review', child: Text('In Review / Investigating')),
                  DropdownMenuItem(value: 'resolved', child: Text('Mark as Resolved')),
                  DropdownMenuItem(value: 'open', child: Text('Reopen Ticket')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedStatus = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: resolutionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Resolution / Action Taken Notes *',
                  hintText: 'e.g. Replaced hydraulic filter, pressure normalized to 120 PSI.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(queryRepositoryProvider).updateQueryStatus(
                          orgId: orgId,
                          queryId: query.id,
                          status: selectedStatus,
                          resolutionNotes: resolutionController.text.trim(),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Ticket ${query.ticketNumber} marked as $selectedStatus.'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';
    final queriesAsync = ref.watch(queriesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shop-Floor Queries & Tickets'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRaiseTicketDialog(context, orgId),
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Raise Ticket'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: queriesAsync.when(
        loading: () => const LoadingWidget(message: 'Loading shop-floor tickets...'),
        error: (err, _) => Center(
          child: Text('Error loading queries: $err', style: AppTextStyles.bodyMedium),
        ),
        data: (queries) {
          final query = _searchController.text.trim().toLowerCase();
          final filtered = queries.where((q) {
            final matchesFilter = _selectedFilter == 'All' ||
                (_selectedFilter == 'Open' && q.isOpen) ||
                (_selectedFilter == 'In Review' && q.isInReview) ||
                (_selectedFilter == 'Resolved' && q.isResolved);

            final matchesQuery = query.isEmpty ||
                q.title.toLowerCase().contains(query) ||
                q.ticketNumber.toLowerCase().contains(query) ||
                q.workOrder.toLowerCase().contains(query) ||
                q.reportedByName.toLowerCase().contains(query);

            return matchesFilter && matchesQuery;
          }).toList();

          final openCount = queries.where((q) => q.isOpen).length;
          final reviewCount = queries.where((q) => q.isInReview).length;
          final resolvedCount = queries.where((q) => q.isResolved).length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(queriesStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top Status Overview
                Row(
                  children: [
                    _QueryMetricCard(
                      label: 'Open Issues',
                      count: openCount,
                      color: AppColors.error,
                      icon: Icons.error_outline_rounded,
                    ),
                    const SizedBox(width: 8),
                    _QueryMetricCard(
                      label: 'In Review',
                      count: reviewCount,
                      color: AppColors.warning,
                      icon: Icons.hourglass_top_rounded,
                    ),
                    const SizedBox(width: 8),
                    _QueryMetricCard(
                      label: 'Resolved',
                      count: resolvedCount,
                      color: AppColors.success,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tickets, work orders, reporters...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Filters
                Row(
                  children: ['All', 'Open', 'In Review', 'Resolved'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(filter),
                        selectedColor: AppColors.primaryLight,
                        labelStyle: AppTextStyles.labelSmall.copyWith(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.help_outline_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          queries.isEmpty
                              ? 'No shop-floor tickets reported.\nOperators can submit tickets directly from the floor.'
                              : 'No tickets match your filter criteria.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((q) {
                    final sevColor = _getSeverityColor(q.severity);
                    final statColor = _getStatusColor(q.status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: q.severity == 'critical' && !q.isResolved
                              ? AppColors.error.withValues(alpha: 0.6)
                              : AppColors.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  q.ticketNumber,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sevColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  q.severity.toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: sevColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  q.status.replaceAll('_', ' ').toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: statColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(q.title, style: AppTextStyles.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            q.description,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              if (q.workOrder.isNotEmpty) ...[
                                const Icon(Icons.assignment_outlined, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(q.workOrder, style: AppTextStyles.labelSmall),
                                const SizedBox(width: 12),
                              ],
                              if (q.stage.isNotEmpty) ...[
                                const Icon(Icons.precision_manufacturing_outlined, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(q.stage, style: AppTextStyles.labelSmall),
                                const SizedBox(width: 12),
                              ],
                              const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(q.reportedByName, style: AppTextStyles.labelSmall),
                            ],
                          ),

                          if (q.resolutionNotes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Resolution: ${q.resolutionNotes}',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => _showResolveDialog(context, orgId, q),
                              icon: Icon(
                                q.isResolved ? Icons.edit_note_rounded : Icons.check_circle_outline_rounded,
                                size: 15,
                              ),
                              label: Text(q.isResolved ? 'Edit Resolution' : 'Update / Resolve'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: q.isResolved ? AppColors.textSecondary : AppColors.success,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                textStyle: AppTextStyles.labelSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QueryMetricCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _QueryMetricCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
