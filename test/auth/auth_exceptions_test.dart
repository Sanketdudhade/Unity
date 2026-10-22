import 'package:flutter_test/flutter_test.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/core/errors/error_handler.dart';

void main() {
  group('ErrorHandler and Exceptions', () {
    test('converts AuthException.invalidCredentials to readable message', () {
      final message = ErrorHandler.getUserMessage(
        AuthException.invalidCredentials(),
      );
      expect(message, contains('Invalid email or password'));
    });

    test('converts AuthException.userDisabled to readable message', () {
      final message = ErrorHandler.getUserMessage(AuthException.userDisabled());
      expect(message, contains('disabled'));
    });

    test('handles AccountInactiveException', () {
      const exception = AccountInactiveException();
      expect(exception.message, contains('inactive'));
      expect(ErrorHandler.getUserMessage(exception), contains('inactive'));
    });

    test('handles MissingClaimsException', () {
      const exception = MissingClaimsException();
      expect(exception.message, contains('missing required role'));
      expect(
        ErrorHandler.getUserMessage(exception),
        contains('missing required role'),
      );
    });

    test(
      'translates raw Firebase error strings safely without leaking secrets',
      () {
        final rawError = Exception(
          '[firebase_auth/user-not-found] There is no user record',
        );
        final message = ErrorHandler.getUserMessage(rawError);
        expect(message, 'Invalid email or password. Please try again.');
      },
    );

    test('translates network exceptions safely', () {
      final networkError = Exception('SocketException: Failed host lookup');
      final message = ErrorHandler.getUserMessage(networkError);
      expect(message, contains('Network connection issue'));
    });
  });
}
