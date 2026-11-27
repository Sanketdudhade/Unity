import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/utils/date_utils.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/process_queries/data/models/process_query_model.dart';
import 'package:unity/features/process_queries/presentation/providers/query_providers.dart';

/// Detailed view and resolution flow for a shop-floor query / maintenance ticket.
class QueryDetailsScreen extends ConsumerStatefulWidget {
  final ProcessQuery query;

  const QueryDetailsScreen({
    super.key,
    required this.query,
  });

  @override
  ConsumerState<QueryDetailsScreen> createState() => _QueryDetailsScreenState();
}

class _QueryDetailsScreenState extends ConsumerState<QueryDetailsScreen> {
  late ProcessQuery _currentQuery;

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
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

  void _showResolveDialog(BuildContext context, String orgId) {
    final messenger = ScaffoldMessenger.of(context);
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Ticket'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ticket: ${_currentQuery.ticketNumber}', style: AppTextStyles.labelMedium),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Resolution Notes / Corrective Actions *',
                  hintText: 'e.g. Replaced optical lens, re-calibrated axis 3, part cleared.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) return;

              Navigator.pop(ctx);
              try {
                await ref.read(queryRepositoryProvider).updateQueryStatus(
                      orgId: orgId,
                      queryId: _currentQuery.id,
                      status: 'resolved',
                      resolutionNotes: notes,
                    );

                setState(() {
                  _currentQuery = ProcessQuery(
                    id: _currentQuery.id,
                    ticketNumber: _currentQuery.ticketNumber,
                    title: _currentQuery.title,
                    description: _currentQuery.description,
                    workOrder: _currentQuery.workOrder,
                    stage: _currentQuery.stage,
                    severity: _currentQuery.severity,
                    status: 'resolved',
                    reportedByName: _currentQuery.reportedByName,
                    reportedByUid: _currentQuery.reportedByUid,
                    resolutionNotes: notes,
                    createdAt: _currentQuery.createdAt,
                    updatedAt: DateTime.now(),
                  );
                });

                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Ticket marked as RESOLVED.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to resolve ticket: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );
  }

  void _updateStatus(String orgId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(queryRepositoryProvider).updateQueryStatus(
            orgId: orgId,
            queryId: _currentQuery.id,
            status: newStatus,
          );

      setState(() {
        _currentQuery = ProcessQuery(
          id: _currentQuery.id,
          ticketNumber: _currentQuery.ticketNumber,
          title: _currentQuery.title,
          description: _currentQuery.description,
          workOrder: _currentQuery.workOrder,
          stage: _currentQuery.stage,
          severity: _currentQuery.severity,
          status: newStatus,
          reportedByName: _currentQuery.reportedByName,
          reportedByUid: _currentQuery.reportedByUid,
          resolutionNotes: _currentQuery.resolutionNotes,
          createdAt: _currentQuery.createdAt,
          updatedAt: DateTime.now(),
        );
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('Status updated to ${newStatus.toUpperCase()}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final orgId = user?.organizationId ?? 'org_unity_001';
    final isAdmin = user?.role == UserRole.admin;

    final sevColor = _getSeverityColor(_currentQuery.severity);
    final statusColor = _getStatusColor(_currentQuery.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_currentQuery.ticketNumber),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sevColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentQuery.severity.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(color: sevColor, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentQuery.status.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _currentQuery.createdAt != null
                              ? FactoryDateUtils.formatFactoryDate(_currentQuery.createdAt!)
                              : '',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_currentQuery.title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reported by: ${_currentQuery.reportedByName}',
                            style: AppTextStyles.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_currentQuery.workOrder.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.precision_manufacturing_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Work Order: ${_currentQuery.workOrder}',
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_currentQuery.stage.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.engineering_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Stage: ${_currentQuery.stage}',
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Problem Description card
            Text('Problem Description', style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _currentQuery.description,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.4),
              ),
            ),
            const SizedBox(height: 20),

            // Resolution Notes (if resolved)
            if (_currentQuery.resolutionNotes.isNotEmpty) ...[
              Text('Resolution & Corrective Actions', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'RESOLVED',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentQuery.resolutionNotes,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Supervisor / Admin Actions
            if (isAdmin) ...[
              Text('Supervisor Actions', style: AppTextStyles.titleSmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_currentQuery.isOpen)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.hourglass_top_rounded, size: 16),
                        label: const Text('Start Review'),
                        onPressed: () => _updateStatus(orgId, 'in_review'),
                      ),
                    ),
                  if (_currentQuery.isOpen) const SizedBox(width: 10),
                  if (!_currentQuery.isResolved)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text('Resolve Ticket'),
                        onPressed: () => _showResolveDialog(context, orgId),
                      ),
                    ),
                  if (_currentQuery.isResolved)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('Re-open Ticket'),
                        onPressed: () => _updateStatus(orgId, 'open'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
