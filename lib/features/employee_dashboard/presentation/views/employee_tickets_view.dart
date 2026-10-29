import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/process_queries/presentation/providers/query_providers.dart';
import 'package:unity/features/process_queries/presentation/screens/raise_query_screen.dart';

/// Shop-floor maintenance and blocker tickets tab conforming to Section 6.
class EmployeeTicketsView extends ConsumerWidget {
  const EmployeeTicketsView({super.key});

  Color _getSeverityColor(BuildContext context, String severity) {
    final tokens = context.adminTokens;
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return tokens.danger;
      case 'medium':
        return tokens.warning;
      case 'low':
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color _getStatusColor(BuildContext context, String status) {
    final tokens = context.adminTokens;
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return tokens.success;
      case 'in_progress':
        return const Color(0xFF2563EB);
      case 'open':
      default:
        return tokens.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    final user = ref.watch(authStateProvider).user;
    final queriesAsync = ref.watch(queriesStreamProvider);

    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(queriesStreamProvider);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Bar with Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Floor Tickets & Maintenance',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Report machine bottlenecks, tooling issues, or rework blockers directly to supervisors.',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RaiseQueryScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.warning,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Tickets List
            queriesAsync.when(
              loading: () => const LoadingWidget(message: 'Loading shop-floor tickets...'),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Error: $e', style: TextStyle(color: tokens.danger)),
              ),
              data: (queries) {
                // Prioritize user's tickets or open tickets
                if (queries.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF152235) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 40, color: tokens.success),
                        const SizedBox(height: 12),
                        Text(
                          'No active blocker tickets',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Everything on the shop-floor is currently running smoothly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: queries.map((query) {
                    final sevColor = _getSeverityColor(context, query.severity);
                    final statusColor = _getStatusColor(context, query.status);
                    final isMyTicket = user != null && query.reportedByUid == user.uid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF152235) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  query.ticketNumber,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              if (isMyTicket) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'MY REPORT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sevColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: sevColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  query.severity.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: sevColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  query.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            query.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          if (query.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              query.description,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (query.workOrder.isNotEmpty) ...[
                                Icon(Icons.assignment_outlined, size: 13, color: textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  query.workOrder,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (query.stage.isNotEmpty) ...[
                                Icon(Icons.precision_manufacturing_outlined, size: 13, color: textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  query.stage,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Icon(Icons.person_outline_rounded, size: 13, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                query.reportedByName,
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
