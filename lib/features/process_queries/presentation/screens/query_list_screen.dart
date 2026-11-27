import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/admin_page_header.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/empty_state.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
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

  void _showRaiseTicketDialog(BuildContext context, String orgId) {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
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
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.help_outline_rounded, color: tokens.danger, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Raise Shop-Floor Ticket',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(440.0, MediaQuery.sizeOf(context).width - 32),
              ),
              child: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
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
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Summary is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedSeverity,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Severity',
                              ),
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Low', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'medium', child: Text('Medium', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'high', child: Text('High', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'critical', child: Text('Critical', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: isSaving ? null : (v) => setDialogState(() => selectedSeverity = v ?? 'medium'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStage,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Station / Stage',
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Raw Material Prep', child: Text('Prep', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Cutting & Forming', child: Text('Cutting', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'CNC Machining', child: Text('CNC Machining', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Welding & Assembly', child: Text('Welding', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Surface Treatment', child: Text('Surface Treatment', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Quality Inspection', child: Text('QA Inspection', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Packaging & Dispatch', child: Text('Packaging', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: isSaving ? null : (v) => setDialogState(() => selectedStage = v ?? selectedStage),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: woController.text.isNotEmpty ? woController.text : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Associated Work Order (Optional)',
                          prefixIcon: Icon(Icons.assignment_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: '', child: Text('None / General Maintenance', overflow: TextOverflow.ellipsis)),
                          ...orders.map((o) => DropdownMenuItem(
                                value: o.orderNumber,
                                child: Text('${o.orderNumber} - ${o.productName}', overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: isSaving ? null : (v) => woController.text = v ?? '',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Detailed Description of Blockage *',
                          hintText: 'Describe machine condition, error code, or missing materials.',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                      ),
                    ],
                  ),
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
                          stage: selectedStage,
                          workOrder: woController.text.trim(),
                          reportedByUid: user?.uid ?? 'admin',
                          reportedByName: user?.fullName ?? 'Floor Supervisor',
                          severity: selectedSeverity,
                          status: 'open',
                          createdAt: DateTime.now(),
                        );

                        try {
                          await ref.read(queryRepositoryProvider).createQuery(orgId, query);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Ticket ${query.ticketNumber} submitted!'),
                                backgroundColor: tokens.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: tokens.danger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final resolutionController = TextEditingController(text: query.resolutionNotes);
    String selectedStatus = query.status == 'resolved' ? 'resolved' : 'resolved';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          title: Text(
            'Resolve Ticket ${query.ticketNumber}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(440.0, MediaQuery.sizeOf(context).width - 32),
            ),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      query.title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Update Status',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'in_review', child: Text('In Review / Investigating', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'resolved', child: Text('Mark as Resolved', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'open', child: Text('Reopen Ticket', overflow: TextOverflow.ellipsis)),
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
                      ),
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
                              backgroundColor: tokens.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: tokens.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.success,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? '';
    final queriesAsync = ref.watch(queriesStreamProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Page Header
          AdminPageHeader(
            title: 'Shop-Floor Queries & Tickets',
            subtitle: 'Incident tracking, station blockage alerts, and operator support tickets',
            icon: Icons.support_agent_rounded,
            trailing: ElevatedButton.icon(
              onPressed: () => _showRaiseTicketDialog(context, orgId),
              icon: const Icon(Icons.add_alert_rounded, size: 18),
              label: const Text('Raise Ticket'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // 2. Metrics & Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF152235) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: queriesAsync.maybeWhen(
              data: (queries) {
                final openCount = queries.where((q) => q.isOpen).length;
                final reviewCount = queries.where((q) => q.isInReview).length;
                final resolvedCount = queries.where((q) => q.isResolved).length;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;

                    final metricBadges = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniQueryBadge(
                          label: 'Open Issues',
                          count: openCount,
                          color: tokens.danger,
                          icon: Icons.error_outline_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MiniQueryBadge(
                          label: 'In Review',
                          count: reviewCount,
                          color: tokens.warning,
                          icon: Icons.hourglass_top_rounded,
                        ),
                        const SizedBox(width: 8),
                        _MiniQueryBadge(
                          label: 'Resolved',
                          count: resolvedCount,
                          color: tokens.success,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    );

                    final searchField = SizedBox(
                      width: isWide ? 280 : double.infinity,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search tickets, orders, reporter...',
                          hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0E1728) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                    );

                    final filterRow = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['All', 'Open', 'In Review', 'Resolved'].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setState(() => _selectedFilter = filter),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : (isDark ? const Color(0xFF0E1728) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                                  ),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? const Color(0xFFA6B6CB) : const Color(0xFF475569)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          metricBadges,
                          const Spacer(),
                          searchField,
                          const SizedBox(width: 10),
                          filterRow,
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: metricBadges,
                          ),
                          const SizedBox(height: 10),
                          searchField,
                          const SizedBox(height: 8),
                          filterRow,
                        ],
                      );
                    }
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // 3. Ticket List
          Expanded(
            child: queriesAsync.when(
              loading: () => const LoadingWidget(message: 'Loading shop-floor tickets...'),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading queries: $err', style: TextStyle(color: tokens.danger)),
                ),
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

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.support_agent_outlined,
                    title: queries.isEmpty ? 'No tickets reported' : 'No matching tickets',
                    description: queries.isEmpty
                        ? 'Operators can submit tickets directly from the floor.'
                        : 'No tickets match your filter criteria "$query".',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(queriesStreamProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final q = filtered[index];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: q.severity == 'critical' && !q.isResolved
                                ? tokens.danger.withValues(alpha: 0.6)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tokens.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    q.ticketNumber,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusChip(
                                  label: q.severity.toUpperCase(),
                                  variant: switch (q.severity.toLowerCase()) {
                                    'critical' => StatusVariant.error,
                                    'high' => StatusVariant.warning,
                                    'medium' => StatusVariant.info,
                                    _ => StatusVariant.neutral,
                                  },
                                  icon: Icons.flag_rounded,
                                ),
                                const Spacer(),
                                StatusChip.fromStatus(q.status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              q.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              q.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                if (q.workOrder.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.assignment_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        q.workOrder,
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                if (q.stage.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.precision_manufacturing_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        q.stage,
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      q.reportedByName,
                                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            if (q.resolutionNotes.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tokens.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 16, color: tokens.success),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Resolution: ${q.resolutionNotes}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                                        ),
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
                                  foregroundColor: q.isResolved ? theme.colorScheme.onSurfaceVariant : tokens.success,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniQueryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MiniQueryBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1728) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
