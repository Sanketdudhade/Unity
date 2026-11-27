import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/admin_theme_extension.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/app/theme/theme_mode_provider.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/inventory/presentation/providers/inventory_providers.dart';
import 'admin_nav_destination.dart';

/// Modern Enterprise Admin Sidebar chrome conforming to Section A4.
class AdminSidebar extends ConsumerWidget {
  final String currentPath;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final bool isDrawer;

  const AdminSidebar({
    super.key,
    required this.currentPath,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.adminTokens;
    final user = ref.watch(authStateProvider).user;
    final lowStockCount = ref.watch(lowStockCountProvider);
    final themeMode = ref.watch(themeModeProvider);

    final groups = ['Overview', 'Operations', 'Management', 'Insights'];

    return Container(
      width: isCollapsed ? 76 : 256,
      decoration: BoxDecoration(
        color: tokens.sidebarBackground,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : const Color(0xFF1E2D4A),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: isDrawer,
        bottom: isDrawer,
        child: Column(
          children: [
            // 1. Sidebar Brand Header
            _buildBrandHeader(context, isCollapsed),

            const Divider(color: Color(0xFF1E2D4A), height: 1),

            // 2. Navigation Items (Grouped)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  for (final group in groups) ...[
                    if (!isCollapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(
                          group.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ...AdminNavDestination.all
                        .where((d) => d.group == group)
                        .map((dest) {
                      final isSelected = currentPath.startsWith(dest.route);
                      final badge = (dest.hasBadge && lowStockCount > 0)
                          ? lowStockCount
                          : null;

                      return _NavItemTile(
                        destination: dest,
                        isSelected: isSelected,
                        isCollapsed: isCollapsed,
                        badgeCount: badge,
                        onTap: () {
                          final router = GoRouter.of(context);
                          if (isDrawer) Navigator.of(context).pop();
                          if (currentPath != dest.route) {
                            router.go(dest.route);
                          }
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),

            const Divider(color: Color(0xFF1E2D4A), height: 1),

            // 3. Bottom Footer (Theme Switcher, Profile & Sign Out)
            _buildFooter(context, ref, user, themeMode, isCollapsed),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context, bool isCollapsed) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 18),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.precision_manufacturing_rounded,
                color: Color(0xFF2DD4BF),
                size: 20,
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'UNITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Manufacturing ERP',
                    style: TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    ThemeMode themeMode,
    bool isCollapsed,
  ) {
    final themeIcon = switch (themeMode) {
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };

    final themeLabel = switch (themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Theme Switcher Row / Button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showThemeSelectionMenu(context, ref, themeMode),
              hoverColor: Colors.white.withValues(alpha: 0.06),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? 6 : 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(themeIcon, size: 18, color: const Color(0xFFA6B6CB)),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 10),
                          const Text(
                            'Theme',
                            style: TextStyle(
                              color: Color(0xFFE8EEF7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isCollapsed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          themeLabel,
                          style: const TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // User Profile & Sign Out Row
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                final router = GoRouter.of(context);
                if (isDrawer) Navigator.of(context).pop();
                router.push(RouteNames.profile);
              },
              hoverColor: Colors.white.withValues(alpha: 0.06),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? 6 : 8,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment: isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF0F766E),
                      child: Text(
                        user?.fullName.isNotEmpty == true
                            ? user!.fullName[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!isCollapsed) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Administrator',
                              style: const TextStyle(
                                color: Color(0xFFE8EEF7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign Out',
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: Color(0xFFA6B6CB),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _confirmSignOut(context, ref),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Optional Sidebar Collapse Toggle
          if (onToggleCollapse != null && !isDrawer) ...[
            const SizedBox(height: 4),
            IconButton(
              tooltip: isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
              icon: Icon(
                isCollapsed
                    ? Icons.keyboard_double_arrow_right_rounded
                    : Icons.keyboard_double_arrow_left_rounded,
                color: const Color(0xFF64748B),
                size: 18,
              ),
              onPressed: onToggleCollapse,
            ),
          ],
        ],
      ),
    );
  }

  void _showThemeSelectionMenu(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Select Display Theme', style: AppTextStyles.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_auto_rounded),
                title: const Text('Follow System'),
                trailing: currentMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded, color: Color(0xFF0F766E))
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_rounded),
                title: const Text('Light Mode'),
                trailing: currentMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded, color: Color(0xFF0F766E))
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: const Text('Dark Mode'),
                trailing: currentMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded, color: Color(0xFF0F766E))
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to end your administrative session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }
}

class _NavItemTile extends StatelessWidget {
  final AdminNavDestination destination;
  final bool isSelected;
  final bool isCollapsed;
  final int? badgeCount;
  final VoidCallback onTap;

  const _NavItemTile({
    required this.destination,
    required this.isSelected,
    required this.isCollapsed,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = const Color(0xFF0F766E).withValues(alpha: 0.22);
    final activeBorder = const Color(0xFF2DD4BF);
    final textStyle = TextStyle(
      color: isSelected ? Colors.white : const Color(0xFFA6B6CB),
      fontSize: 13,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 10,
        vertical: 2,
      ),
      child: Tooltip(
        message: isCollapsed ? destination.title : '',
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            hoverColor: Colors.white.withValues(alpha: 0.06),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 0 : 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isSelected && !isCollapsed
                    ? Border(left: BorderSide(color: activeBorder, width: 3))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    isSelected ? destination.selectedIcon : destination.icon,
                    size: 19,
                    color: isSelected ? activeBorder : const Color(0xFFA6B6CB),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.title,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeCount != null && badgeCount! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB91C1C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
