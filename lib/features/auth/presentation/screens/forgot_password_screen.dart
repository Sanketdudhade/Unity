import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/core/firebase/firebase_providers.dart';

/// Screen allowing users (Admin and Employee) to request a secure password reset email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _isSubmitting = false;
  bool _emailSent = false;
  String? _errorMessage;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _cooldownSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cooldownSeconds--;
          });
        }
      }
    });
  }

  Future<void> _handleSendResetLink() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSubmitting || _cooldownSeconds > 0) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final cleanEmail = _emailController.text.trim();

    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email: cleanEmail);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _emailSent = true;
          _errorMessage = null;
        });
        _startCooldown();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'An unexpected error occurred. Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Back to Login text button at top left
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(RouteNames.login);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Back to Sign In',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // App Brand Logo
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/icons/app_icon.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.precision_manufacturing_rounded,
                                color: Color(0xFF0F766E),
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Heading
                        Text(
                          'Forgot Password?',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineSmall,
                        ),
                        const SizedBox(height: 6),

                        // Description
                        Text(
                          _emailSent
                              ? 'Check your email inbox for the reset link'
                              : 'Enter your registered email address and we will send you a password reset link.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 24),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _errorMessage = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Success State View
                        if (_emailSent) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.mark_email_read_rounded,
                                  color: Colors.green,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Password reset instructions have been sent if this email is associated with an account. Please check your inbox and spam folder.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark ? Colors.green[200] : Colors.green[900],
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _emailController.text.trim(),
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Return to Login Button
                          ElevatedButton(
                            onPressed: () => context.go(RouteNames.login),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Return to Login'),
                          ),
                          const SizedBox(height: 14),

                          // Resend Email with Cooldown
                          Center(
                            child: _cooldownSeconds > 0
                                ? Text(
                                    'Resend link in ${_cooldownSeconds}s',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : TextButton.icon(
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Resend Reset Email'),
                                    onPressed: _isSubmitting ? null : _handleSendResetLink,
                                  ),
                          ),
                        ] else ...[
                          // Email Input Field
                          Text('Email Address', style: AppTextStyles.labelMedium),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enabled: !_isSubmitting,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSendResetLink(),
                            decoration: const InputDecoration(
                              hintText: 'name@organization.com',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              final clean = value.trim();
                              if (!clean.contains('@') || !clean.contains('.')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Send Reset Link Button
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSendResetLink,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Send Reset Link'),
                          ),
                          const SizedBox(height: 20),

                          // Back to login secondary link
                          Center(
                            child: TextButton(
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(RouteNames.login);
                                }
                              },
                              child: Text(
                                'Remember your password? Sign In',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ),
        ),
      ),
    );
  }
}
