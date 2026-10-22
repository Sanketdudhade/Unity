/// Application user roles for Role-Based Access Control (RBAC).
enum UserRole {
  admin('ADMIN'),
  employee('EMPLOYEE');

  final String value;
  const UserRole(this.value);

  /// Safe deserialization from String with strict validation.
  /// Returns null if the value is invalid or unrecognized.
  static UserRole? fromString(String? roleStr) {
    if (roleStr == null) return null;
    final normalized = roleStr.trim().toUpperCase();
    for (final role in UserRole.values) {
      if (role.value == normalized) {
        return role;
      }
    }
    return null;
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isEmployee => this == UserRole.employee;

  @override
  String toString() => value;
}

/// Authentication & session lifecycle statuses.
enum AuthStatus {
  /// App is launching / checking stored credentials.
  initial,

  /// Login request is in-flight.
  authenticating,

  /// User is authenticated, claims are valid, and profile is active.
  authenticated,

  /// User is not logged in.
  unauthenticated,

  /// Authenticated user account is disabled/inactive (`isActive == false`).
  inactive,

  /// An error occurred during authentication or claims verification.
  error,
}
