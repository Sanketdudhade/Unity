import 'package:flutter/material.dart';

/// Custom theme extension for Modern Enterprise design tokens.
@immutable
class AdminThemeExtension extends ThemeExtension<AdminThemeExtension> {
  final Color canvasBackground;
  final Color surfaceRaised;
  final Color sidebarBackground;
  final Color primarySoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const AdminThemeExtension({
    required this.canvasBackground,
    required this.surfaceRaised,
    required this.sidebarBackground,
    required this.primarySoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Light theme token values conforming to Redesign Spec Section A3
  static const light = AdminThemeExtension(
    canvasBackground: Color(0xFFF5F7FA),
    surfaceRaised: Color(0xFFFFFFFF),
    sidebarBackground: Color(0xFF142238),
    primarySoft: Color(0xFFE6F5F2),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    info: Color(0xFF1D4ED8),
  );

  /// Dark theme token values conforming to Redesign Spec Section A3
  static const dark = AdminThemeExtension(
    canvasBackground: Color(0xFF0B1220),
    surfaceRaised: Color(0xFF1C2B41),
    sidebarBackground: Color(0xFF0E1728),
    primarySoft: Color(0xFF123A3A),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
  );

  @override
  AdminThemeExtension copyWith({
    Color? canvasBackground,
    Color? surfaceRaised,
    Color? sidebarBackground,
    Color? primarySoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return AdminThemeExtension(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      primarySoft: primarySoft ?? this.primarySoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AdminThemeExtension lerp(ThemeExtension<AdminThemeExtension>? other, double t) {
    if (other is! AdminThemeExtension) return this;
    return AdminThemeExtension(
      canvasBackground: Color.lerp(canvasBackground, other.canvasBackground, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      sidebarBackground: Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension AdminThemeExtensionGetter on BuildContext {
  AdminThemeExtension get adminTokens {
    return Theme.of(this).extension<AdminThemeExtension>() ??
        (Theme.of(this).brightness == Brightness.dark
            ? AdminThemeExtension.dark
            : AdminThemeExtension.light);
  }
}
