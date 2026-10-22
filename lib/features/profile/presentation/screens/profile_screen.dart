import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';

/// User profile and security audit screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading user details...'),
      );
    }

    final isRoleAdmin = user.role.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Identity Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isRoleAdmin
                          ? AppColors.roleAdminBg
                          : AppColors.roleEmployeeBg,
                      child: Icon(
                        isRoleAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.engineering_rounded,
                        size: 38,
                        color: isRoleAdmin
                            ? AppColors.roleAdmin
                            : AppColors.roleEmployee,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.fullName,
                      style: AppTextStyles.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isRoleAdmin
                            ? AppColors.roleAdminBg
                            : AppColors.roleEmployeeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRoleAdmin
                              ? AppColors.roleAdmin.withValues(alpha: 0.3)
                              : AppColors.roleEmployee.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Role: ${user.role.value}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isRoleAdmin
                              ? AppColors.roleAdmin
                              : AppColors.roleEmployee,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account & Security Details
              Text('Account Information', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'User ID',
                      value: user.uid,
                      isMonospace: true,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Organization ID',
                      value: user.organizationId,
                      isMonospace: true,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Account Status',
                      value: user.isActive ? 'Active' : 'Inactive',
                      statusColor: user.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Created Date',
                      value: user.createdAt.toLocal().toString().split('.')[0],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Sign Out'),
                        content: const Text(
                          'Are you sure you want to log out of your account?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await ref.read(authStateProvider.notifier).logout();
                    }
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  label: Text(
                    'Sign Out',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;
  final Color? statusColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: isMonospace
                  ? AppTextStyles.bodyMedium.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: statusColor ?? AppColors.textPrimary,
                    )
                  : AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusColor ?? AppColors.textPrimary,
                    ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
