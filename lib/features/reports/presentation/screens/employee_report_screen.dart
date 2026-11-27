import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/utils/csv_exporter.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';
import 'package:unity/features/reports/presentation/widgets/csv_export_modal.dart';

/// Workforce & Employee Directory Audit Report with CSV Export.
class EmployeeReportScreen extends ConsumerWidget {
  const EmployeeReportScreen({super.key});

  void _exportCsv(BuildContext context, List<AppUserModel> employees) {
    final headers = [
      'Full Name',
      'Email',
      'Role',
      'Status',
      'Organization ID',
    ];

    final rows = employees.map((e) {
      return [
        e.fullName,
        e.email,
        e.role.value,
        e.isActive ? 'ACTIVE' : 'INACTIVE',
        e.organizationId,
      ];
    }).toList();

    final csvString = CsvExporter.generateCsv(headers: headers, rows: rows);

    CsvExportModal.show(
      context,
      title: 'Workforce Directory Report',
      filename: 'employee_directory_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csvString,
      recordCount: employees.length,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workforce Directory Report'),
        actions: [
          employeesAsync.maybeWhen(
            data: (employees) => IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _exportCsv(context, employees),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: employeesAsync.when(
        loading: () => const LoadingWidget(message: 'Loading workforce directory...'),
        error: (err, _) => Center(
          child: Text('Failed to load report: $err', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
        ),
        data: (employees) {
          if (employees.isEmpty) {
            return Center(
              child: Text('No employees registered.', style: AppTextStyles.bodyMedium),
            );
          }

          final activeCount = employees.where((e) => e.isActive).length;
          final adminCount = employees.where((e) => e.role == UserRole.admin).length;

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Total Staff', textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                          Text('${employees.length}', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Active Staff', textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                          Text('$activeCount', style: AppTextStyles.titleMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Supervisors/Admins', textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                          Text('$adminCount', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Employees List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final emp = employees[index];

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: emp.role == UserRole.admin
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.secondary.withValues(alpha: 0.2),
                          child: Icon(
                            emp.role == UserRole.admin ? Icons.shield_rounded : Icons.person_rounded,
                            color: emp.role == UserRole.admin ? AppColors.primary : AppColors.secondary,
                            size: 20,
                          ),
                        ),
                        title: Text(emp.fullName, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                        subtitle: Text(emp.email, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: emp.isActive
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            emp.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: emp.isActive ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
