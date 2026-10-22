import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/data/repositories/auth_repository.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;
  late StreamController<dynamic> authStateController;

  final testAdminUser = AppUserModel(
    uid: 'admin_1',
    fullName: 'Admin User',
    email: 'admin@unity.com',
    role: UserRole.admin,
    organizationId: 'org_001',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockRepository = MockAuthRepository();
    authStateController = StreamController<dynamic>.broadcast();
    when(() => mockRepository.authStateChanges)
        .thenAnswer((_) => authStateController.stream.cast());
    when(() => mockRepository.signOut()).thenAnswer((_) async {});
  });

  tearDown(() {
    authStateController.close();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockRepository)],
    );
  }

  group('AuthNotifier State Lifecycle', () {
    test('initializes with AuthStatus.initial', () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(authStateProvider).status, AuthStatus.initial);
    });

    test(
      'transitions to unauthenticated when authStateChanges emits null',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        // Trigger initialization by reading provider
        container.read(authStateProvider);

        authStateController.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(authStateProvider).status,
          AuthStatus.unauthenticated,
        );
        expect(container.read(authStateProvider).user, isNull);
      },
    );

    test(
      'rejects login with invalid email immediately without calling repository',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(authStateProvider.notifier);
        final result = await notifier.login(
          email: 'invalid-email',
          password: 'password123',
        );

        expect(result, isFalse);
        expect(container.read(authStateProvider).status, AuthStatus.error);
        expect(
          container.read(authStateProvider).errorMessage,
          contains('valid email'),
        );
        verifyNever(
          () => mockRepository.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    test('successful login transitions to authenticated state', () async {
      when(
        () => mockRepository.signInWithEmailAndPassword(
          email: 'admin@unity.com',
          password: 'validPassword123',
        ),
      ).thenAnswer((_) async {});
      when(() => mockRepository.getAuthenticatedUserProfile(forceRefresh: true))
          .thenAnswer((_) async => testAdminUser);

      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      final result = await notifier.login(
        email: 'admin@unity.com',
        password: 'validPassword123',
      );

      expect(result, isTrue);
      expect(
        container.read(authStateProvider).status,
        AuthStatus.authenticated,
      );
      expect(container.read(authStateProvider).user, testAdminUser);
      expect(container.read(authStateProvider).isAdmin, isTrue);
      expect(container.read(authStateProvider).isEmployee, isFalse);
    });

    test(
      'login with inactive account sets inactive state and signs out',
      () async {
        when(
          () => mockRepository.signInWithEmailAndPassword(
            email: 'admin@unity.com',
            password: 'validPassword123',
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getAuthenticatedUserProfile(forceRefresh: true),
        ).thenThrow(const AccountInactiveException());

        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(authStateProvider.notifier);
        final result = await notifier.login(
          email: 'admin@unity.com',
          password: 'validPassword123',
        );

        expect(result, isFalse);
        expect(container.read(authStateProvider).status, AuthStatus.inactive);
        verify(() => mockRepository.signOut()).called(1);
      },
    );

    test('logout clears user state to unauthenticated', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.logout();

      expect(
        container.read(authStateProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(container.read(authStateProvider).user, isNull);
      verify(() => mockRepository.signOut()).called(1);
    });
  });
}
