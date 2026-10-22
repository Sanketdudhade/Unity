import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';

/// Repository for managing employees and staff within the organization.
class EmployeeRepository {
  final FirebaseFirestore firestore;

  EmployeeRepository({required this.firestore});

  /// Real-time stream of all employees and personnel belonging to [orgId].
  Stream<List<AppUserModel>> getEmployeesStream(String orgId) {
    return firestore
        .collection(FirestorePaths.usersCollection)
        .where('organizationId', isEqualTo: orgId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUserModel.fromFirestore(doc))
          .toList()
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    });
  }

  /// Creates a new employee user account and stores their profile in Firestore.
  /// Uses a temporary secondary FirebaseApp instance to prevent signing out the current Admin.
  Future<void> createEmployee({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required String organizationId,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      final appName = 'EmpProvision_${DateTime.now().millisecondsSinceEpoch}';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final uid = userCred.user!.uid;

      // Update display name
      await userCred.user?.updateDisplayName(fullName.trim());

      // Write profile to users/{uid}
      await firestore.collection(FirestorePaths.usersCollection).doc(uid).set({
        'uid': uid,
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'role': role.value,
        'organizationId': organizationId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write directory record to organizations/{orgId}/employees/{uid}
      await firestore.collection(FirestorePaths.employeesCollection(organizationId)).doc(uid).set({
        'uid': uid,
        'employeeCode': 'EMP-${uid.substring(0, 5).toUpperCase()}',
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'role': role.value,
        'department': role.isAdmin ? 'Management' : 'Shop-Floor Operations',
        'organizationId': organizationId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw const AuthException('An account already exists with this email address.');
        case 'weak-password':
          throw const AuthException('The password is too weak. Please use at least 6 characters.');
        case 'invalid-email':
          throw const AuthException('The email address is invalid.');
        default:
          throw AuthException(e.message ?? 'Failed to create user account.');
      }
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to create employee profile: ${e.message}', code: e.code);
    } finally {
      await secondaryApp?.delete();
    }
  }

  /// Updates the active status of an employee document.
  Future<void> setEmployeeStatus({
    required String uid,
    required bool isActive,
    String? orgId,
  }) async {
    try {
      await firestore.collection(FirestorePaths.usersCollection).doc(uid).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (orgId != null && orgId.isNotEmpty) {
        await firestore.collection(FirestorePaths.employeesCollection(orgId)).doc(uid).update({
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to update employee status: ${e.message}', code: e.code);
    }
  }
}


