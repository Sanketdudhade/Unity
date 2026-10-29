import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/employee_dashboard/presentation/providers/employee_dashboard_provider.dart';
import 'package:unity/features/employee_dashboard/presentation/widgets/assigned_stage_card.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/providers/production_providers.dart';

/// Station Queue tab conforming to Section 5D & 6: Detailed 17-stage flow management assigned to the operator.
class EmployeeStationQueueView extends ConsumerWidget {
  const EmployeeStationQueueView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    final stagesAsync = ref.watch(employeeAssignedProcessesStreamProvider);
    final filteredStages = ref.watch(filteredEmployeeStagesProvider);
    final ordersAsync = ref.watch(productionOrdersStreamProvider);
    final selectedFilter = ref.watch(employeeStageFilterProvider);
    final orders = ordersAsync.value ?? [];

    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);

    final filters = ['All', 'In Progress', 'Assigned', 'Attention / Blocked', 'Completed'];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(employeeAssignedProcessesStreamProvider);
        ref.invalidate(productionOrdersStreamProvider);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Bar
            Text(
              'Station Manufacturing Queue',
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sequential manufacturing process stages assigned to your station across active batches.',
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
              ),
            ),

            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF152235) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search TextField
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by stage name, order number...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(employeeStageSearchProvider.notifier).state = val;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((f) {
                        final isSelected = selectedFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: isSelected,
                            onSelected: (_) {
                              ref.read(employeeStageFilterProvider.notifier).state = f;
                            },
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : textSecondary,
                            ),
                            selectedColor: const Color(0xFF0F766E),
                            backgroundColor: isDark ? const Color(0xFF1E2B41) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Stage Cards List
            stagesAsync.when(
              loading: () => const LoadingWidget(message: 'Loading assigned stages...'),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Error: $e', style: TextStyle(color: tokens.danger)),
              ),
              data: (_) {
                if (filteredStages.isEmpty) {
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
                        Icon(Icons.filter_list_off_rounded, size: 40, color: textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No stages matching current filter',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try clearing your search query or selecting a different status filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: filteredStages.map((stage) {
                    final matchingOrder = orders.cast<ProductionOrder?>().firstWhere(
                          (o) => o != null && (o.id == stage.orderId || o.orderNumber == stage.orderId),
                          orElse: () => null,
                        );
                    return AssignedStageCard(stage: stage, order: matchingOrder);
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
