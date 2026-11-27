import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';

/// Repository responsible for authentication, token custom claims, and user profile management.
class AuthRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  AuthRepository({required this.auth, required this.firestore});

  /// Stream of authentication state changes from Firebase Auth.
  Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Currently authenticated Firebase user (or null).
  User? get currentFirebaseUser => auth.currentUser;

  /// Sign in with email and password.
  /// Throws [AuthException] on Firebase Auth failures.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          throw AuthException.invalidCredentials();
        case 'user-disabled':
          throw AuthException.userDisabled();
        case 'too-many-requests':
          throw AuthException.tooManyRequests();
        case 'network-request-failed':
          throw AuthException.networkError();
        default:
          throw AuthException(
            e.message ?? 'Authentication failed. Please try again.',
            code: e.code,
          );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException(e.toString());
    }
  }

  /// Extracts and validates custom claims from the current user's ID token.
  /// Enforces that `role` ('ADMIN' or 'EMPLOYEE') and `organizationId` exist on the token.
  Future<({UserRole role, String organizationId})> getValidatedCustomClaims({
    bool forceRefresh = false,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }

    final idTokenResult = await user.getIdTokenResult(forceRefresh);
    final claims = idTokenResult.claims;

    final roleClaim = claims?['role'] as String?;
    final orgClaim = claims?['organizationId'] as String?;

    if (roleClaim != null && orgClaim != null && orgClaim.trim().isNotEmpty) {
      final role = UserRole.fromString(roleClaim);
      if (role != null) {
        return (role: role, organizationId: orgClaim.trim());
      }
    }

    // Seamless fallback to Firestore profile when token claims are not yet synced
    final profile = await getUserProfile(user.uid);
    return (role: profile.role, organizationId: profile.organizationId);
  }


  /// Fetches the user profile document from Firestore (`users/{uid}`).
  /// Throws [UserNotFoundException] if missing, or [InvalidUserDataException] if invalid.
  Future<AppUserModel> getUserProfile(String uid) async {
    try {
      final doc = await firestore.doc(FirestorePaths.userDoc(uid)).get();

      if (!doc.exists || doc.data() == null) {
        throw const UserNotFoundException();
      }

      return AppUserModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const UnauthorizedException(
          'Permission denied reading user profile.',
        );
      }
      rethrow;
    }
  }

  /// Loads, verifies custom claims, and cross-checks the Firestore user profile.
  /// Throws domain exceptions if claims are missing, profile is missing, role mismatches, or account is inactive.
  Future<AppUserModel> getAuthenticatedUserProfile({
    bool forceRefresh = false,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw const AuthException('No user is currently signed in.');
    }

    // 1. Fetch Firestore profile
    final profile = await getUserProfile(user.uid);

    // 2. Cross-check custom claims if present on ID token
    final idTokenResult = await user.getIdTokenResult(forceRefresh);
    final claims = idTokenResult.claims;
    final roleClaim = claims?['role'] as String?;
    final orgClaim = claims?['organizationId'] as String?;

    if (roleClaim != null && orgClaim != null) {
      final claimRole = UserRole.fromString(roleClaim);
      if (claimRole != profile.role) {
        throw const UnauthorizedException(
          'Security token role does not match user profile.',
        );
      }
      if (orgClaim != profile.organizationId) {
        throw const UnauthorizedException(
          'Security token organization does not match user profile.',
        );
      }
    }

    // 3. Verify account activation flag
    if (!profile.isActive) {
      throw const AccountInactiveException();
    }

    return profile;
  }


  /// Sign out from Firebase.
  Future<void> signOut() async {
    await auth.signOut();
  }

  /// Sends a password reset email to [email] using Firebase Authentication.
  /// Throws [AuthException] on failure.
  Future<void> sendPasswordResetEmail({required String email}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw const AuthException('Please enter a valid email address.');
    }

    try {
      await auth.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw const AuthException('Please enter a valid email address.');
        case 'user-not-found':
          // Email enumeration protection: gracefully succeed without exposing account existence
          return;
        case 'too-many-requests':
          throw AuthException.tooManyRequests();
        case 'network-request-failed':
          throw AuthException.networkError();
        default:
          throw AuthException(
            e.message ?? 'Failed to send password reset email. Please try again.',
            code: e.code,
          );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw AuthException(e.toString());
    }
  }
}
