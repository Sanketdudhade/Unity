import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unity/app/theme/app_theme.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/data/repositories/auth_repository.dart';
import 'package:unity/features/auth/presentation/screens/login_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  testWidgets('LoginScreen renders inputs and validates empty credentials', (
    WidgetTester tester,
  ) async {
    final mockRepository = MockAuthRepository();
    final controller = StreamController<dynamic>.broadcast();
    when(() => mockRepository.authStateChanges)
        .thenAnswer((_) => controller.stream.cast());

    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(mockRepository)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    // Verify initial layout
    expect(find.text('System Access'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // Trigger Sign In with empty fields to trigger validation
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    // Verify field validation triggers
    expect(find.text('Email is required'), findsOneWidget);
  });
}
