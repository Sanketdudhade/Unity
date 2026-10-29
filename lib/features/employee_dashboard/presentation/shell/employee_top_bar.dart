import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/app/theme/theme_mode_provider.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employee_dashboard/presentation/providers/employee_dashboard_provider.dart';

/// Modern Enterprise Top Bar for the Employee Terminal.
/// Fully responsive on Android smartphones, tablets, and Windows desktop.
class EmployeeTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool showDrawerButton;

  const EmployeeTopBar({
    super.key,
    this.showDrawerButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Production Terminal';
      case 1:
        return 'Station Queue (Stages)';
      case 2:
        return 'Assigned Work Tasks';
      case 3:
        return 'Material Consumption';
      case 4:
        return 'Floor Tickets & Support';
      default:
        return 'Terminal';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = context.adminTokens;
    final user = ref.watch(authStateProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final activeTab = ref.watch(employeeSelectedTabProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF152235) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
            child: Row(
              children: [
                // 1. Mobile Drawer Toggle Button
                if (showDrawerButton) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Open Station Navigation',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                  const SizedBox(width: 4),
                ],

                // 2. Terminal Title & Breadcrumb Context
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _getTabTitle(activeTab),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: tokens.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'STATION ONLINE',
                                    style: TextStyle(
                                      color: tokens.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isCompact)
                        Text(
                          'Shop-Floor Operations • Station Worker Workspace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),

                // 3. Organization Badge
                if (user?.organizationId.isNotEmpty == true) ...[
                  Tooltip(
                    message: 'Facility: ${user!.organizationId}',
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C2B41) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.factory_rounded,
                            size: 14,
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                          ),
                          if (!isCompact) ...[
                            const SizedBox(width: 6),
                            Text(
                              user.organizationId,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 4. Quick Theme Switcher Popup Menu
                PopupMenuButton<ThemeMode>(
                  tooltip: 'Select Theme Mode',
                  icon: Icon(
                    switch (themeMode) {
                      ThemeMode.light => Icons.light_mode_rounded,
                      ThemeMode.dark => Icons.dark_mode_rounded,
                      ThemeMode.system => Icons.brightness_auto_rounded,
                    },
                    size: 20,
                    color: isDark ? const Color(0xFFA6B6CB) : const Color(0xFF475569),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (mode) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: ThemeMode.system,
                      child: Row(
                        children: [
                          const Icon(Icons.brightness_auto_rounded, size: 18),
                          const SizedBox(width: 10),
                          const Text('Follow System'),
                          if (themeMode == ThemeMode.system) ...[
                            const Spacer(),
                            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0F766E)),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: ThemeMode.light,
                      child: Row(
                        children: [
                          const Icon(Icons.light_mode_rounded, size: 18),
                          const SizedBox(width: 10),
                          const Text('Light Theme'),
                          if (themeMode == ThemeMode.light) ...[
                            const Spacer(),
                            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0F766E)),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: ThemeMode.dark,
                      child: Row(
                        children: [
                          const Icon(Icons.dark_mode_rounded, size: 18),
                          const SizedBox(width: 10),
                          const Text('Dark Theme'),
                          if (themeMode == ThemeMode.dark) ...[
                            const Spacer(),
                            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0F766E)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 4),

                // 5. Worker Profile Avatar
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push(RouteNames.profile),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark ? const Color(0xFF1C2B41) : const Color(0xFF0F766E),
                      child: Text(
                        user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'W',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF2DD4BF) : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // 6. Sign Out Button
                IconButton(
                  tooltip: 'Sign Out Station',
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: const Text('Confirm Sign Out'),
                        content: const Text('Are you sure you want to log off from this manufacturing station?'),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
