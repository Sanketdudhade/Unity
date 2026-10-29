import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/employee_dashboard/presentation/providers/employee_dashboard_provider.dart';
import 'package:unity/features/tasks/presentation/providers/task_providers.dart';
import 'package:unity/features/tasks/presentation/widgets/process_task_card.dart';

/// Assigned tasks tab conforming to Section 5C & 6: Search, filter, and operations.
class EmployeeTasksView extends ConsumerWidget {
  const EmployeeTasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    final tasksAsync = ref.watch(tasksStreamProvider);
    final filteredTasks = ref.watch(filteredEmployeeTasksProvider);
    final selectedFilter = ref.watch(employeeTaskFilterProvider);

    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);

    final filters = ['All', 'In Progress', 'Pending', 'Paused', 'Completed'];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tasksStreamProvider);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Bar
            Text(
              'My Assigned Tasks',
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Production tasks, work order assignments, and operations dispatched to you.',
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
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by task title, work order, stage...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(employeeTaskSearchProvider.notifier).state = val;
                    },
                  ),
                  const SizedBox(height: 10),

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
                              ref.read(employeeTaskFilterProvider.notifier).state = f;
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

            // 3. Task Cards List
            tasksAsync.when(
              loading: () => const LoadingWidget(message: 'Loading assigned tasks...'),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Error: $e', style: TextStyle(color: tokens.danger)),
              ),
              data: (_) {
                if (filteredTasks.isEmpty) {
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
                        Icon(Icons.assignment_turned_in_outlined, size: 40, color: textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No tasks matching current filter',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All tasks are clear or no tasks match your search criteria.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: filteredTasks.map((task) => ProcessTaskCard(task: task)).toList(),
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
