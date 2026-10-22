import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/errors/app_exceptions.dart';

/// Typed domain model representing a user in the system (`users/{uid}`).
class AppUserModel {
  final String uid;
  final String fullName;
  final String email;
  final UserRole role;
  final String organizationId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.organizationId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Strict deserialization from Firestore DocumentSnapshot.
  /// Throws [InvalidUserDataException] if any required field is missing or malformed.
  factory AppUserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const InvalidUserDataException(
        'User document does not contain data.',
      );
    }
    return AppUserModel.fromMap(data, snapshot.id);
  }

  /// Strict deserialization from Map.
  /// Validates all required fields, role values, and timestamps.
  factory AppUserModel.fromMap(Map<String, dynamic> map, String documentId) {
    // 1. UID validation
    final uid = map['uid'] as String? ?? documentId;
    if (uid.trim().isEmpty) {
      throw const InvalidUserDataException(
        'User profile is missing a valid UID.',
      );
    }

    // 2. Full Name validation
    final fullName = map['fullName'] as String?;
    if (fullName == null || fullName.trim().isEmpty) {
      throw const InvalidUserDataException(
        'User profile is missing "fullName".',
      );
    }

    // 3. Email validation
    final email = map['email'] as String?;
    if (email == null || email.trim().isEmpty || !email.contains('@')) {
      throw const InvalidUserDataException(
        'User profile has an invalid or missing "email".',
      );
    }

    // 4. Role validation (fail-closed: only 'ADMIN' or 'EMPLOYEE' allowed)
    final roleRaw = map['role'] as String?;
    final role = UserRole.fromString(roleRaw);
    if (role == null) {
      throw InvalidUserDataException(
        'User profile has an invalid or unsupported role: "$roleRaw". Must be ADMIN or EMPLOYEE.',
      );
    }

    // 5. Organization ID validation
    final organizationId = map['organizationId'] as String?;
    if (organizationId == null || organizationId.trim().isEmpty) {
      throw const InvalidUserDataException(
        'User profile is missing "organizationId".',
      );
    }

    // 6. Activation flag validation
    final isActive = map['isActive'];
    if (isActive is! bool) {
      throw const InvalidUserDataException(
        'User profile has an invalid or missing "isActive" boolean flag.',
      );
    }

    // 7. Created At & Updated At timestamps
    DateTime parseTimestamp(dynamic value, String fieldName) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      throw InvalidUserDataException(
        'User profile field "$fieldName" must be a valid Firestore Timestamp.',
      );
    }

    final createdAt = parseTimestamp(map['createdAt'], 'createdAt');
    final updatedAt = parseTimestamp(map['updatedAt'], 'updatedAt');

    return AppUserModel(
      uid: uid,
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      role: role,
      organizationId: organizationId.trim(),
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Converts the model into a Firestore map representation.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role.value,
      'organizationId': organizationId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppUserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    UserRole? role,
    String? organizationId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          role == other.role &&
          organizationId == other.organizationId &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      role.hashCode ^
      organizationId.hashCode ^
      isActive.hashCode;

  @override
  String toString() {
    return 'AppUserModel(uid: $uid, fullName: $fullName, email: $email, role: $role, org: $organizationId, active: $isActive)';
  }
}
