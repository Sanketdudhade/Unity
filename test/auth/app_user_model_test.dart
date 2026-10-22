import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';

void main() {
  group('AppUserModel', () {
    final validMap = {
      'uid': 'user_123',
      'fullName': 'John Doe',
      'email': 'john.doe@unity.com',
      'role': 'ADMIN',
      'organizationId': 'org_unity_001',
      'isActive': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
    };

    test('successfully parses valid document map for ADMIN', () {
      final user = AppUserModel.fromMap(validMap, 'user_123');

      expect(user.uid, 'user_123');
      expect(user.fullName, 'John Doe');
      expect(user.email, 'john.doe@unity.com');
      expect(user.role, UserRole.admin);
      expect(user.organizationId, 'org_unity_001');
      expect(user.isActive, isTrue);
      expect(user.createdAt, DateTime(2026, 1, 1));
      expect(user.updatedAt, DateTime(2026, 1, 2));
    });

    test('successfully parses valid document map for EMPLOYEE', () {
      final employeeMap = Map<String, dynamic>.from(validMap)
        ..['role'] = 'EMPLOYEE';

      final user = AppUserModel.fromMap(employeeMap, 'user_123');
      expect(user.role, UserRole.employee);
      expect(user.role.isEmployee, isTrue);
      expect(user.role.isAdmin, isFalse);
    });

    test('toMap converts model back to Firestore representation', () {
      final user = AppUserModel.fromMap(validMap, 'user_123');
      final map = user.toMap();

      expect(map['uid'], 'user_123');
      expect(map['fullName'], 'John Doe');
      expect(map['email'], 'john.doe@unity.com');
      expect(map['role'], 'ADMIN');
      expect(map['organizationId'], 'org_unity_001');
      expect(map['isActive'], isTrue);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('throws InvalidUserDataException when fullName is empty', () {
      final invalidMap = Map<String, dynamic>.from(validMap)..['fullName'] = '';
      expect(
        () => AppUserModel.fromMap(invalidMap, 'user_123'),
        throwsA(isA<InvalidUserDataException>()),
      );
    });

    test('throws InvalidUserDataException when email is malformed', () {
      final invalidMap = Map<String, dynamic>.from(validMap)
        ..['email'] = 'not-an-email';
      expect(
        () => AppUserModel.fromMap(invalidMap, 'user_123'),
        throwsA(isA<InvalidUserDataException>()),
      );
    });

    test(
      'throws InvalidUserDataException when role is unsupported or missing',
      () {
        final invalidRole = Map<String, dynamic>.from(validMap)
          ..['role'] = 'SUPER_USER';
        expect(
          () => AppUserModel.fromMap(invalidRole, 'user_123'),
          throwsA(isA<InvalidUserDataException>()),
        );

        final missingRole = Map<String, dynamic>.from(validMap)..remove('role');
        expect(
          () => AppUserModel.fromMap(missingRole, 'user_123'),
          throwsA(isA<InvalidUserDataException>()),
        );
      },
    );

    test('throws InvalidUserDataException when organizationId is empty', () {
      final invalidMap = Map<String, dynamic>.from(validMap)
        ..['organizationId'] = ' ';
      expect(
        () => AppUserModel.fromMap(invalidMap, 'user_123'),
        throwsA(isA<InvalidUserDataException>()),
      );
    });

    test(
      'throws InvalidUserDataException when isActive flag is not boolean',
      () {
        final invalidMap = Map<String, dynamic>.from(validMap)
          ..['isActive'] = 'yes';
        expect(
          () => AppUserModel.fromMap(invalidMap, 'user_123'),
          throwsA(isA<InvalidUserDataException>()),
        );
      },
    );
  });
}
