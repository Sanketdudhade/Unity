  import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/app/app.dart';
import 'package:unity/app/theme/app_colors.dart';
import 'package:unity/app/theme/app_text_styles.dart';
import 'package:unity/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safeguard: On Android devices mirrored via PC tools (e.g., scrcpy), synthetic mouse hover
  // packets trigger an internal Flutter framework MouseTracker assertion in debug mode
  // (!'_debugDuringDeviceUpdate'). Filtering out hover packets on Android eliminates this assertion
  // while preserving all touches, clicks, drags, and scrolling intact.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final originalOnPointerDataPacket = WidgetsBinding.instance.platformDispatcher.onPointerDataPacket;
    if (originalOnPointerDataPacket != null) {
      WidgetsBinding.instance.platformDispatcher.onPointerDataPacket = (PointerDataPacket packet) {
        final sanitizedData = packet.data.where((p) => p.change != PointerChange.hover).toList();
        if (sanitizedData.isNotEmpty) {
          originalOnPointerDataPacket(PointerDataPacket(data: sanitizedData));
        }
      };
    }
  }

  // Suppress repetitive internal framework mouse_tracker assertion loop in debug console
  // and safeguard widget inspector against secondary crashes on deactivated elements
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('_debugDuringDeviceUpdate')) {
      return;
    }
    try {
      originalOnError?.call(details);
    } catch (_) {
      // Fall back to clean error output if widget inspector fails during ancestor inspection
      FlutterError.dumpErrorToConsole(details);
    }
  };

  String? initError;

  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Attempts platform default (e.g. google-services.json on Android)
      await Firebase.initializeApp();
    }
  } catch (e) {
    initError = e.toString();
  }

  if (initError != null) {
    runApp(FirebaseInitErrorApp(errorMessage: initError));
  } else {
    runApp(const ProviderScope(child: App()));
  }
}

/// Fallback application displaying clear setup guidance when Firebase is unconfigured.
class FirebaseInitErrorApp extends StatelessWidget {
  final String errorMessage;

  const FirebaseInitErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.cloud_off_rounded,
                              color: AppColors.error,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Firebase Setup Required',
                              style: AppTextStyles.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'The application started successfully, but Firebase requires project linking or configuration credentials before accessing cloud services.',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontFamily: 'monospace',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Required Action:', style: AppTextStyles.titleSmall),
                      const SizedBox(height: 8),
                      Text(
                        '1. Run `flutterfire configure` in your terminal.\n'
                        '2. Or provide valid Firebase credentials in `.env` and pass `--dart-define-from-file=.env`.\n'
                        '3. Place `google-services.json` in `android/app/`.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
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
