import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/widgets/loading_widget.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';

/// Splash screen that displays app branding and handles session restoration.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Industrial Logo Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),

                // App Title
                Text(
                  'UNITY',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: Colors.white,
                    letterSpacing: 4.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Manufacturing & Production Tracking',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),

                // State presentation
                if (authState.status == AuthStatus.error ||
                    authState.status == AuthStatus.inactive) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Column(
                      children: [
                        Text(
                          authState.errorMessage ?? 'Authentication failure.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(authStateProvider.notifier).clearError();
                            context.go(RouteNames.login);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          child: const Text('Proceed to Login'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const LoadingWidget(
                    color: AppColors.secondaryLight,
                    message: null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
