import 'package:flutter/material.dart';

enum StatusVariant {
  success,
  warning,
  error,
  info,
  neutral,
}

/// Reusable Modern Enterprise Status Chip with strong contrast.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusVariant variant;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  factory StatusChip.fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'active':
      case 'optimal':
        return StatusChip(
          label: status.toUpperCase(),
          variant: StatusVariant.success,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'in_production':
      case 'in_progress':
      case 'running':
        return StatusChip(
          label: status.replaceAll('_', ' ').toUpperCase(),
          variant: StatusVariant.info,
          icon: Icons.precision_manufacturing_rounded,
        );
      case 'scheduled':
      case 'pending':
      case 'assigned':
      case 'paused':
        return StatusChip(
          label: status.replaceAll('_', ' ').toUpperCase(),
          variant: StatusVariant.warning,
          icon: Icons.schedule_rounded,
        );
      case 'on_hold':
      case 'blocked':
      case 'error':
      case 'inactive':
      case 'low_stock':
        return StatusChip(
          label: status.replaceAll('_', ' ').toUpperCase(),
          variant: StatusVariant.error,
          icon: Icons.warning_amber_rounded,
        );
      default:
        return StatusChip(
          label: status.replaceAll('_', ' ').toUpperCase(),
          variant: StatusVariant.neutral,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (Color bg, Color fg) = switch (variant) {
      StatusVariant.success => isDark
          ? (const Color(0xFF15803D).withValues(alpha: 0.25), const Color(0xFF4ADE80))
          : (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      StatusVariant.warning => isDark
          ? (const Color(0xFFB45309).withValues(alpha: 0.25), const Color(0xFFFBBF24))
          : (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      StatusVariant.error => isDark
          ? (const Color(0xFFB91C1C).withValues(alpha: 0.25), const Color(0xFFF87171))
          : (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      StatusVariant.info => isDark
          ? (const Color(0xFF1D4ED8).withValues(alpha: 0.25), const Color(0xFF60A5FA))
          : (const Color(0xFFE0F2FE), const Color(0xFF1D4ED8)),
      StatusVariant.neutral => isDark
          ? (const Color(0xFF1E293B), const Color(0xFFA6B6CB))
          : (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
