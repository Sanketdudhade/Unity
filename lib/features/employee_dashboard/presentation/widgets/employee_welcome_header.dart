import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';

/// Modern Enterprise Welcome & Shift Header conforming to Section 5A.
class EmployeeWelcomeHeader extends ConsumerWidget {
  final VoidCallback onUpdateStatus;
  final VoidCallback onLogMaterial;
  final VoidCallback onRaiseTicket;

  const EmployeeWelcomeHeader({
    super.key,
    required this.onUpdateStatus,
    required this.onLogMaterial,
    required this.onRaiseTicket,
  });

  String _formatDate(DateTime now) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).user;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    final headerBg = isDark ? const Color(0xFF152235) : Colors.white;
    final headerBorder = isDark ? const Color(0xFF304155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFA6B6CB) : const Color(0xFF64748B);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Welcome back, ${user?.fullName ?? "Operator"}',
              style: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
              ),
              child: Text(
                user?.role.value.toUpperCase() ?? 'OPERATOR',
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Here's your production work overview • ${_formatDate(DateTime.now())}",
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: onUpdateStatus,
          icon: const Icon(Icons.edit_note_rounded, size: 16),
          label: const Text('Update Status'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onLogMaterial,
          icon: const Icon(Icons.inventory_2_outlined, size: 16),
          label: const Text('Log Material'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
            side: BorderSide(
              color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRaiseTicket,
          icon: const Icon(Icons.help_outline_rounded, size: 16),
          label: const Text('Raise Ticket'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
            side: BorderSide(
              color: isDark ? const Color(0xFF304155) : const Color(0xFFCBD5E1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                actionButtons,
              ],
            )
          : Row(
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                actionButtons,
              ],
            ),
    );
  }
}
