import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/presentation/providers/employee_providers.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'ADMIN', 'EMPLOYEE'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEmployeeDialog(BuildContext context, String orgId) {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: 'Password123!');
    UserRole selectedRole = UserRole.employee;
    bool isSubmitting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_add_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('Add Employee'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. John Doe',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      hintText: 'e.g. john@unity.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@') || !v.contains('.')) return 'Invalid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    enabled: !isSubmitting,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Initial Password *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Organizational Role',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.employee,
                        child: Text('EMPLOYEE (Standard Access)'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('ADMIN (Full Control)'),
                      ),
                    ],
                    onChanged: isSubmitting
                        ? null
                        : (val) {
                            if (val != null) setDialogState(() => selectedRole = val);
                          },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isSubmitting = true);

                      try {
                        await ref.read(employeeRepositoryProvider).createEmployee(
                              fullName: nameController.text.trim(),
                              email: emailController.text.trim(),
                              password: passwordController.text,
                              role: selectedRole,
                              organizationId: orgId,
                            );

                        if (ctx.mounted) Navigator.pop(ctx);

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Employee ${nameController.text.trim()} created successfully.'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('$e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Employee'),
            ),
          ],
        ),
      ),
    );
  }


  void _confirmToggleStatus(AppUserModel employee) async {
    final messenger = ScaffoldMessenger.of(context);
    final newStatus = !employee.isActive;
    final action = newStatus ? 'Reactivate' : 'Deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Employee'),
        content: Text(
          'Are you sure you want to $action ${employee.fullName}? ${newStatus ? "They will regain access to their portal." : "They will be immediately blocked from signing in."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(employeeRepositoryProvider)
            .setEmployeeStatus(
              uid: employee.uid,
              isActive: newStatus,
              orgId: employee.organizationId,
            );

        messenger.showSnackBar(
          SnackBar(
            content: Text('${employee.fullName} is now ${newStatus ? "Active" : "Inactive"}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final currentUser = ref.watch(authStateProvider).user;
    final orgId = currentUser?.organizationId ?? 'org_unity_001';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Employee Directory'),
        actions: [
          IconButton(
            tooltip: 'Add Employee',
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => _showAddEmployeeDialog(context, orgId),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _filterChip('All'),
                    const SizedBox(width: 8),
                    _filterChip('ADMIN'),
                    const SizedBox(width: 8),
                    _filterChip('EMPLOYEE'),
                  ],
                ),
              ],
            ),
          ),

          // Employees List
          Expanded(
            child: employeesAsync.when(
              data: (employees) {
                final query = _searchController.text.toLowerCase().trim();
                final filtered = employees.where((emp) {
                  final matchesQuery = emp.fullName.toLowerCase().contains(query) ||
                      emp.email.toLowerCase().contains(query);
                  final matchesRole = _selectedFilter == 'All' || emp.role.value == _selectedFilter;
                  return matchesQuery && matchesRole;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text('No personnel found', style: AppTextStyles.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            query.isNotEmpty
                                ? 'No results matched your search.'
                                : 'Add team members using the provision button above.',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {

                    final employee = filtered[index];
                    final isAdmin = employee.role == UserRole.admin;
                    final isSelf = employee.uid == currentUser?.uid;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isAdmin ? AppColors.roleAdminBg : AppColors.roleEmployeeBg,
                          foregroundColor: isAdmin ? AppColors.roleAdmin : AppColors.roleEmployee,
                          child: Text(
                            employee.fullName.isNotEmpty ? employee.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                employee.fullName,
                                style: AppTextStyles.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('You', style: AppTextStyles.labelSmall),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(employee.email, style: AppTextStyles.bodySmall),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAdmin ? AppColors.roleAdminBg : AppColors.roleEmployeeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    employee.role.value,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isAdmin ? AppColors.roleAdmin : AppColors.roleEmployee,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: employee.isActive ? AppColors.successLight : AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    employee.isActive ? 'Active' : 'Inactive',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: employee.isActive ? AppColors.success : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isSelf
                            ? null
                            : IconButton(
                                tooltip: employee.isActive ? 'Deactivate Employee' : 'Reactivate Employee',
                                icon: Icon(
                                  employee.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                  color: employee.isActive ? AppColors.success : AppColors.textMuted,
                                  size: 36,
                                ),
                                onPressed: () => _confirmToggleStatus(employee),
                              ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(message: 'Loading employee directory...'),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading directory: $err', style: AppTextStyles.bodyMedium),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(context, orgId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Employee'),
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }
}
