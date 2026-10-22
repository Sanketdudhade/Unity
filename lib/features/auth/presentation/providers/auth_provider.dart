import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/core/errors/error_handler.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/data/repositories/auth_repository.dart';

/// State representation for authentication and RBAC session lifecycle.
class AuthState {
  final AuthStatus status;
  final AppUserModel? user;
  final String? errorMessage;

  const AuthState({required this.status, this.user, this.errorMessage});

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.authenticating([AppUserModel? user]) =>
      AuthState(status: AuthStatus.authenticating, user: user);

  factory AuthState.authenticated(AppUserModel user) =>
      AuthState(status: AuthStatus.authenticated, user: user);

  factory AuthState.unauthenticated() =>
      const AuthState(status: AuthStatus.unauthenticated);

  factory AuthState.inactive(String message) =>
      AuthState(status: AuthStatus.inactive, errorMessage: message);

  factory AuthState.error(String message) =>
      AuthState(status: AuthStatus.error, errorMessage: message);

  bool get isLoading =>
      status == AuthStatus.initial || status == AuthStatus.authenticating;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  bool get isAdmin => isAuthenticated && user!.role.isAdmin;
  bool get isEmployee => isAuthenticated && user!.role.isEmployee;

  AuthState copyWith({
    AuthStatus? status,
    AppUserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => status.hashCode ^ user.hashCode ^ errorMessage.hashCode;
}

/// State notifier managing session state, credentials verification, and RBAC authorization.
class AuthNotifier extends Notifier<AuthState> {
  final AuthRepository? _injectedRepository;
  StreamSubscription? _authSubscription;

  AuthNotifier([this._injectedRepository]);

  AuthRepository get _repository =>
      _injectedRepository ?? ref.read(authRepositoryProvider);

  @override
  AuthState get state => super.state;

  @override
  set state(AuthState value) => super.state = value;

  @override
  AuthState build() {
    _initialize();
    ref.onDispose(() {
      _authSubscription?.cancel();
    });
    return AuthState.initial();
  }

  void _initialize() {
    _authSubscription?.cancel();
    _authSubscription = _repository.authStateChanges.listen(
      (user) async {
        if (user == null) {
          state = AuthState.unauthenticated();
        } else {
          await _restoreSession();
        }
      },
      onError: (error) {
        state = AuthState.error(ErrorHandler.getUserMessage(error));
      },
    );
  }

  /// Restores existing authenticated session and verifies custom claims and profile.
  Future<void> _restoreSession() async {
    try {
      final profile = await _repository
          .getAuthenticatedUserProfile(forceRefresh: true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const AuthException(
              'Session restoration timed out. Please sign in.',
            ),
          );
      state = AuthState.authenticated(profile);
    } on AccountInactiveException catch (e) {
      await _repository.signOut();
      state = AuthState.inactive(e.message);
    } on AppException catch (e) {
      await _repository.signOut();
      state = AuthState.error(e.message);
    } catch (e) {
      await _repository.signOut();
      state = AuthState.error(ErrorHandler.getUserMessage(e));
    }
  }

  /// Signs in with email and password and loads user profile.
  Future<bool> login({required String email, required String password}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      state = AuthState.error('Please enter a valid email address.');
      return false;
    }
    if (password.isEmpty) {
      state = AuthState.error('Please enter your password.');
      return false;
    }

    state = AuthState.authenticating();

    try {
      await _repository
          .signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const AuthException(
              'Sign in timed out. Please check your connection.',
            ),
          );

      // Force refresh claims on fresh login
      final profile = await _repository
          .getAuthenticatedUserProfile(forceRefresh: true)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const AuthException(
              'Profile retrieval timed out.',
            ),
          );

      state = AuthState.authenticated(profile);
      return true;

    } on AccountInactiveException catch (e) {
      await _repository.signOut();
      state = AuthState.inactive(e.message);
      return false;
    } on AppException catch (e) {
      await _repository.signOut();
      state = AuthState.error(e.message);
      return false;
    } catch (e) {
      await _repository.signOut();
      state = AuthState.error(ErrorHandler.getUserMessage(e));
      return false;
    }
  }

  /// Logs out the user and clears session state.
  Future<void> logout() async {
    try {
      state = AuthState.authenticating(state.user);
      await _repository.signOut();
      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(ErrorHandler.getUserMessage(e));
    }
  }

  /// Clears any active error banner.
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}

/// Global provider for [AuthNotifier] and [AuthState].
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
