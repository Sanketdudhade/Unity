import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/admin_page_header.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/empty_state.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
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
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
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
          backgroundColor: theme.colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_add_rounded, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add Employee',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
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
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Organizational Role',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: UserRole.employee,
                            child: Text('EMPLOYEE (Standard Access)', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: UserRole.admin,
                            child: Text('ADMIN (Full Control)', overflow: TextOverflow.ellipsis),
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
                            backgroundColor: tokens.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('$e'),
                            backgroundColor: tokens.danger,
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
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final newStatus = !employee.isActive;
    final action = newStatus ? 'Reactivate' : 'Deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        title: Text(
          '$action Employee',
          style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to $action ${employee.fullName}? ${newStatus ? "They will regain access to their portal." : "They will be immediately blocked from signing in."}',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? tokens.success : tokens.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(employeeRepositoryProvider).setEmployeeStatus(
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
            backgroundColor: tokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteEmployee(AppUserModel employee) async {
    final theme = Theme.of(context);
    final tokens = context.adminTokens;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Employee',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete ${employee.fullName} (${employee.email})?',
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All access for this employee account will be revoked permanently.',
                      style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(employeeRepositoryProvider).deleteEmployee(
              uid: employee.uid,
              organizationId: employee.organizationId,
            );

        messenger.showSnackBar(
          SnackBar(
            content: Text('${employee.fullName} was deleted successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete employee: $e'),
            backgroundColor: tokens.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final employeesAsync = ref.watch(employeesStreamProvider);
    final currentUser = ref.watch(authStateProvider).user;
    final orgId = currentUser?.organizationId ?? 'org_unity_001';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. Admin Page Header
          AdminPageHeader(
            title: 'Employee Directory',
            subtitle: 'Manage organizational access, roles, and employee accounts',
            icon: Icons.people_alt_rounded,
            trailing: ElevatedButton.icon(
              onPressed: () => _showAddEmployeeDialog(context, orgId),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Employee'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          // 2. Search & Filter Bar
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final searchField = SizedBox(
                  width: isWide ? 340 : double.infinity,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

                final filterChips = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('ADMIN'),
                    const SizedBox(width: 8),
                    _buildFilterChip('EMPLOYEE'),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: [
                      searchField,
                      const SizedBox(width: 16),
                      filterChips,
                      const Spacer(),
                      employeesAsync.maybeWhen(
                        data: (list) => Text(
                          '${list.length} total members',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: filterChips,
                      ),
                    ],
                  );
                }
              },
            ),
          ),

          // 3. Employee List Content
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
                  return EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: 'No personnel found',
                    description: query.isNotEmpty
                        ? 'No employee accounts matched "$query".'
                        : 'No team members in this filter category.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final employee = filtered[index];
                    final isAdmin = employee.role == UserRole.admin;
                    final isSelf = employee.uid == currentUser?.uid;

                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isAdmin
                              ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0E7FF))
                              : (isDark ? const Color(0xFF132D28) : const Color(0xFFE6F5F2)),
                          foregroundColor: isAdmin
                              ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6))
                              : theme.colorScheme.primary,
                          child: Text(
                            employee.fullName.isNotEmpty ? employee.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                employee.fullName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.primarySoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              employee.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                StatusChip(
                                  label: employee.role.value,
                                  variant: isAdmin ? StatusVariant.info : StatusVariant.neutral,
                                  icon: isAdmin ? Icons.shield_outlined : Icons.person_outline_rounded,
                                ),
                                StatusChip(
                                  label: employee.isActive ? 'ACTIVE' : 'INACTIVE',
                                  variant: employee.isActive ? StatusVariant.success : StatusVariant.error,
                                  icon: employee.isActive ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: isSelf
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: employee.isActive ? 'Deactivate Employee' : 'Reactivate Employee',
                                    icon: Icon(
                                      employee.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                      color: employee.isActive ? tokens.success : theme.colorScheme.onSurfaceVariant,
                                      size: 34,
                                    ),
                                    onPressed: () => _confirmToggleStatus(employee),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Delete Employee',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                    onPressed: () => _confirmDeleteEmployee(employee),
                                  ),
                                ],
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
                  child: Text(
                    'Error loading directory: $err',
                    style: TextStyle(color: tokens.danger),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == label;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFA6B6CB) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
