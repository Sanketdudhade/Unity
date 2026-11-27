import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/auth/data/repositories/auth_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('Forgot Password & Password Reset Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late AuthRepository authRepository;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      authRepository = AuthRepository(auth: mockAuth, firestore: mockFirestore);
    });

    test('RouteNames.forgotPassword is correct', () {
      expect(RouteNames.forgotPassword, equals('/forgot-password'));
    });

    test('sendPasswordResetEmail invokes firebaseAuth with trimmed email', () async {
      when(() => mockAuth.sendPasswordResetEmail(email: 'user@unity.com'))
          .thenAnswer((_) async {});

      await authRepository.sendPasswordResetEmail(email: '  user@unity.com  ');

      verify(() => mockAuth.sendPasswordResetEmail(email: 'user@unity.com')).called(1);
    });

    test('sendPasswordResetEmail throws AuthException when email is empty or invalid', () async {
      expect(
        () => authRepository.sendPasswordResetEmail(email: '   '),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('valid email'))),
      );

      expect(
        () => authRepository.sendPasswordResetEmail(email: 'invalid-email-format'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('valid email'))),
      );

      verifyNever(() => mockAuth.sendPasswordResetEmail(email: any(named: 'email')));
    });

    test('sendPasswordResetEmail succeeds gracefully on user-not-found for enumeration protection', () async {
      when(() => mockAuth.sendPasswordResetEmail(email: 'nonexistent@unity.com'))
          .thenThrow(FirebaseAuthException(code: 'user-not-found', message: 'No user found'));

      // Should complete without throwing, preventing account discovery
      await authRepository.sendPasswordResetEmail(email: 'nonexistent@unity.com');

      verify(() => mockAuth.sendPasswordResetEmail(email: 'nonexistent@unity.com')).called(1);
    });

    test('sendPasswordResetEmail maps too-many-requests properly', () async {
      when(() => mockAuth.sendPasswordResetEmail(email: 'busy@unity.com'))
          .thenThrow(FirebaseAuthException(code: 'too-many-requests'));

      expect(
        () => authRepository.sendPasswordResetEmail(email: 'busy@unity.com'),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', equals('too-many-requests'))),
      );
    });

    test('sendPasswordResetEmail maps network-request-failed properly', () async {
      when(() => mockAuth.sendPasswordResetEmail(email: 'offline@unity.com'))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      expect(
        () => authRepository.sendPasswordResetEmail(email: 'offline@unity.com'),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', equals('network-request-failed'))),
      );
    });
  });
}
