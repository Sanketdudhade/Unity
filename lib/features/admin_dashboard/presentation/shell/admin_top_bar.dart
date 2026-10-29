import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/theme_mode_provider.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'admin_nav_destination.dart';

/// Modern Enterprise Admin Top Bar chrome conforming to Section A4.
class AdminTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final String currentPath;
  final bool showDrawerButton;

  const AdminTopBar({
    super.key,
    required this.currentPath,
    this.showDrawerButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 600;

    final title = AdminNavDestination.getPageTitle(currentPath);

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
                // 1. Mobile / Tablet Drawer Hamburger
                if (showDrawerButton) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Open Navigation Drawer',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                  const SizedBox(width: 4),
                ],

            // 2. Page Title & Breadcrumb Context
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!isCompact)
                    Text(
                      'Manufacturing Operations Platform',
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
                message: 'Org: ${user!.organizationId}',
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C2B41)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_rounded,
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
              const SizedBox(width: 4),
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
                    const Text('Light Mode'),
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
                    const Text('Dark Mode'),
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

          // 5. User Profile Button
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push(RouteNames.profile),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? const Color(0xFF1C2B41) : const Color(0xFF0F766E),
                child: Text(
                  user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'A',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF2DD4BF) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
);
  }
}
