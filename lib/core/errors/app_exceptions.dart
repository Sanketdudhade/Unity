/// Base exception class for the application.
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

/// Authentication-related exceptions.
class AuthException extends AppException {
  const AuthException(super.message, {super.code});

  factory AuthException.invalidCredentials() => const AuthException(
    'Invalid email or password. Please try again.',
    code: 'invalid-credentials',
  );

  factory AuthException.userDisabled() => const AuthException(
    'This account has been disabled. Please contact your administrator.',
    code: 'user-disabled',
  );

  factory AuthException.userNotFound() => const AuthException(
    'No account found with this email address.',
    code: 'user-not-found',
  );

  factory AuthException.wrongPassword() => const AuthException(
    'Incorrect password. Please verify and try again.',
    code: 'wrong-password',
  );

  factory AuthException.tooManyRequests() => const AuthException(
    'Too many failed attempts. Please wait a few minutes before trying again.',
    code: 'too-many-requests',
  );

  factory AuthException.networkError() => const AuthException(
    'Network error. Please check your internet connection.',
    code: 'network-request-failed',
  );
}

/// Thrown when an authenticated user does not exist in the Firestore users collection.
class UserNotFoundException extends AppException {
  const UserNotFoundException([
    super.message =
        'User profile record was not found. Please contact administration.',
  ]) : super(code: 'user-doc-not-found');
}

/// Thrown when an account has `isActive == false`.
class AccountInactiveException extends AppException {
  const AccountInactiveException([
    super.message = 'Your account is currently inactive. Contact your supervisor for access.',
  ]) : super(code: 'account-inactive');
}

/// Thrown when user data retrieved from Firestore is malformed, missing required fields, or has an invalid role.
class InvalidUserDataException extends AppException {
  const InvalidUserDataException([
    super.message =
        'User profile contains invalid or malformed data. Access denied.',
  ]) : super(code: 'invalid-user-data');
}

/// Thrown when a Firebase Auth ID token is missing required custom claims (role or organizationId).
class MissingClaimsException extends AppException {
  const MissingClaimsException([
    super.message = 'Security token is missing required role or organization claims. Access denied.',
  ]) : super(code: 'missing-claims');
}

/// Thrown when a user attempts an action or route outside their permitted role or organization.
class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'You do not have permission to access this resource.',
  ]) : super(code: 'unauthorized');
}

/// Thrown when a Firestore or storage operation fails.
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code});
}

/// Thrown when a business logic rule or sequential dependency validation fails.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

/// Thrown when an inventory deduction or allocation would breach zero-balance invariants.
class InsufficientStockException extends AppException {
  const InsufficientStockException([
    super.message = 'Insufficient inventory stock to complete this transaction.',
  ]) : super(code: 'insufficient-stock');
}

