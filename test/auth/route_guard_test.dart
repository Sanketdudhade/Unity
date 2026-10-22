import 'package:flutter_test/flutter_test.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';

/// Test helper simulating GoRouter redirect logic in isolation.
String? testRouteRedirect({
  required AuthState authState,
  required String location,
}) {
  final status = authState.status;
  final user = authState.user;

  final isSplash = location == RouteNames.splash;
  final isLogin = location == RouteNames.login;

  // 1. Initializing state
  if (status == AuthStatus.initial) {
    return isSplash ? null : RouteNames.splash;
  }

  // 2. Unauthenticated, inactive, or error: Fail-closed to login
  if (!authState.isAuthenticated || user == null) {
    if (!isLogin && !isSplash) {
      return RouteNames.login;
    }
    return null;
  }

  // 3. Authenticated user on splash or login: redirect to respective dashboard
  if (isSplash || isLogin) {
    return user.role.isAdmin
        ? RouteNames.adminDashboard
        : RouteNames.employeeDashboard;
  }

  // 4. Role Guards
  if (location.startsWith('/admin') && !user.role.isAdmin) {
    return RouteNames.employeeDashboard;
  }

  if (location.startsWith('/employee') && !user.role.isEmployee) {
    return RouteNames.adminDashboard;
  }

  return null;
}

void main() {
  group('GoRouter Role-Based Access Control Guards', () {
    final adminUser = AppUserModel(
      uid: 'admin_1',
      fullName: 'Facility Admin',
      email: 'admin@unity.com',
      role: UserRole.admin,
      organizationId: 'org_001',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final employeeUser = AppUserModel(
      uid: 'emp_1',
      fullName: 'Floor Worker',
      email: 'worker@unity.com',
      role: UserRole.employee,
      organizationId: 'org_001',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('unauthenticated users are redirected to /login when requesting protected routes', () {
      final unauthState = AuthState.unauthenticated();

      expect(
        testRouteRedirect(
          authState: unauthState,
          location: RouteNames.adminDashboard,
        ),
        RouteNames.login,
      );
      expect(
        testRouteRedirect(
          authState: unauthState,
          location: RouteNames.employeeDashboard,
        ),
        RouteNames.login,
      );
      expect(
        testRouteRedirect(authState: unauthState, location: RouteNames.profile),
        RouteNames.login,
      );
      expect(
        testRouteRedirect(authState: unauthState, location: RouteNames.login),
        isNull,
      );
    });

    test('authenticated ADMIN navigating to login or splash is sent to /admin/dashboard', () {
      final adminState = AuthState.authenticated(adminUser);

      expect(
        testRouteRedirect(authState: adminState, location: RouteNames.login),
        RouteNames.adminDashboard,
      );
      expect(
        testRouteRedirect(authState: adminState, location: RouteNames.splash),
        RouteNames.adminDashboard,
      );
      expect(
        testRouteRedirect(
          authState: adminState,
          location: RouteNames.adminDashboard,
        ),
        isNull,
      );
      expect(
        testRouteRedirect(authState: adminState, location: RouteNames.profile),
        isNull,
      );
    });

    test('authenticated EMPLOYEE navigating to login or splash is sent to /employee/dashboard', () {
      final empState = AuthState.authenticated(employeeUser);

      expect(
        testRouteRedirect(authState: empState, location: RouteNames.login),
        RouteNames.employeeDashboard,
      );
      expect(
        testRouteRedirect(authState: empState, location: RouteNames.splash),
        RouteNames.employeeDashboard,
      );
      expect(
        testRouteRedirect(
          authState: empState,
          location: RouteNames.employeeDashboard,
        ),
        isNull,
      );
    });

    test('EMPLOYEE is strictly denied access to /admin routes and redirected to employee dashboard', () {
      final empState = AuthState.authenticated(employeeUser);

      expect(
        testRouteRedirect(
          authState: empState,
          location: RouteNames.adminDashboard,
        ),
        RouteNames.employeeDashboard,
      );
    });

    test('ADMIN is redirected to admin dashboard if navigating to /employee routes', () {
      final adminState = AuthState.authenticated(adminUser);

      expect(
        testRouteRedirect(
          authState: adminState,
          location: RouteNames.employeeDashboard,
        ),
        RouteNames.adminDashboard,
      );
    });

    test('inactive account fails closed and is redirected to login', () {
      final inactiveState = AuthState.inactive('Account inactive');

      expect(
        testRouteRedirect(
          authState: inactiveState,
          location: RouteNames.adminDashboard,
        ),
        RouteNames.login,
      );
      expect(
        testRouteRedirect(
          authState: inactiveState,
          location: RouteNames.employeeDashboard,
        ),
        RouteNames.login,
      );
    });
  });
}
