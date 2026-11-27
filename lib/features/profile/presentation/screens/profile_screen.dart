import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/core/widgets/responsive_layout.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/admin_page_header.dart';
import 'package:unity/features/admin_dashboard/presentation/widgets/status_chip.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';

/// User profile and security audit screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading user details...'),
      );
    }

    final isRoleAdmin = user.role.isAdmin;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: !isRoleAdmin
          ? AppBar(title: const Text('My Profile'))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (isRoleAdmin)
              AdminPageHeader(
                title: 'User Profile & Security',
                subtitle: 'Manage administrative credentials, organization tenancy, and active session',
                icon: Icons.manage_accounts_rounded,
              ),
            Expanded(
              child: ResponsiveContainer(
                scrollable: true,
                maxWidth: 800,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Identity Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: isRoleAdmin
                                  ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0E7FF))
                                  : tokens.primarySoft,
                              foregroundColor: isRoleAdmin
                                  ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6))
                                  : theme.colorScheme.primary,
                              child: Icon(
                                isRoleAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.engineering_rounded,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user.fullName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            StatusChip(
                              label: 'ROLE: ${user.role.value}',
                              variant: isRoleAdmin ? StatusVariant.info : StatusVariant.neutral,
                              icon: isRoleAdmin ? Icons.shield_outlined : Icons.person_outline_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Account & Security Details
                      Text(
                        'Account Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              label: 'User ID',
                              value: user.uid,
                              isMonospace: true,
                            ),
                            Divider(height: 1, color: theme.colorScheme.outline),
                            _InfoRow(
                              label: 'Organization ID',
                              value: user.organizationId,
                              isMonospace: true,
                            ),
                            Divider(height: 1, color: theme.colorScheme.outline),
                            _InfoRow(
                              label: 'Account Status',
                              value: user.isActive ? 'Active' : 'Inactive',
                              statusVariant: user.isActive ? StatusVariant.success : StatusVariant.error,
                            ),
                            Divider(height: 1, color: theme.colorScheme.outline),
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
                                backgroundColor: theme.colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: theme.colorScheme.outline),
                                ),
                                title: Text(
                                  'Confirm Sign Out',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                content: Text(
                                  'Are you sure you want to log out of your account?',
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
                                      backgroundColor: tokens.danger,
                                      foregroundColor: Colors.white,
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
                          icon: Icon(Icons.logout_rounded, color: tokens.danger),
                          label: Text(
                            'Sign Out',
                            style: TextStyle(
                              color: tokens.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: tokens.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;
  final StatusVariant? statusVariant;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.statusVariant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (statusVariant != null)
            StatusChip(
              label: value.toUpperCase(),
              variant: statusVariant!,
            )
          else
            Flexible(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: isMonospace ? 'monospace' : null,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
