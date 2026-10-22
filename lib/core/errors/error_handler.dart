import 'app_exceptions.dart';

/// Centralized utility for extracting user-facing error messages from exceptions.
class ErrorHandler {
  ErrorHandler._();

  /// Converts any exception into a safe, user-friendly message.
  static String getUserMessage(dynamic error) {
    if (error == null) {
      return 'An unexpected error occurred.';
    }

    if (error is AppException) {
      return error.message;
    }

    // Handles Firebase Auth error codes without hard dependency on Firebase packages in this file
    final errorStr = error.toString();

    if (errorStr.contains('user-not-found') ||
        errorStr.contains('wrong-password') ||
        errorStr.contains('invalid-credential')) {
      return 'Invalid email or password. Please try again.';
    }

    if (errorStr.contains('user-disabled')) {
      return 'This account has been disabled. Please contact your administrator.';
    }

    if (errorStr.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a few moments before trying again.';
    }

    if (errorStr.contains('network-request-failed') ||
        errorStr.contains('SocketException') ||
        errorStr.contains('ClientException')) {
      return 'Network connection issue. Please check your internet connection.';
    }

    if (errorStr.contains('permission-denied')) {
      return 'Access denied. You do not have permissions for this action.';
    }

    return 'An unexpected error occurred. Please try again or contact support.';
  }
}
