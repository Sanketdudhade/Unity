import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unity/app/router/route_names.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/features/admin_dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/auth/presentation/screens/login_screen.dart';
import 'package:unity/features/auth/presentation/screens/splash_screen.dart';
import 'package:unity/features/employee_dashboard/presentation/screens/employee_dashboard_screen.dart';
import 'package:unity/features/employees/presentation/screens/employee_list_screen.dart';
import 'package:unity/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:unity/features/process_queries/presentation/screens/query_list_screen.dart';
import 'package:unity/features/production/presentation/screens/production_list_screen.dart';
import 'package:unity/features/products/presentation/screens/product_list_screen.dart';
import 'package:unity/features/profile/presentation/screens/profile_screen.dart';
import 'package:unity/features/reports/presentation/screens/reports_screen.dart';
import 'package:unity/features/admin_dashboard/presentation/shell/admin_shell.dart';

/// Listenable bridge allowing GoRouter to respond reactively to Riverpod auth state updates.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Central GoRouter provider with strict role-based route protection.
final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: routerNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);
      final status = authState.status;
      final user = authState.user;
      final location = state.matchedLocation;

      final isSplash = location == RouteNames.splash;
      final isLogin = location == RouteNames.login;

      // 1. Initializing: stay on splash
      if (status == AuthStatus.initial) {
        return isSplash ? null : RouteNames.splash;
      }

      // 2. Unauthenticated: always navigate to login
      if (status == AuthStatus.unauthenticated) {
        return isLogin ? null : RouteNames.login;
      }

      // 3. Inactive or Error state:
      if (status == AuthStatus.inactive || status == AuthStatus.error) {
        // Allow splash to show the error message card, or stay on login
        if (isSplash || isLogin) return null;
        return RouteNames.login;
      }

      // 4. Authenticated: navigate to role-specific dashboard
      if (authState.isAuthenticated && user != null) {
        if (isSplash || isLogin) {
          return user.role.isAdmin
              ? RouteNames.adminDashboard
              : RouteNames.employeeDashboard;
        }

        // 4. Role Guards:
        // Employee attempting to access Admin routes -> redirected to employee dashboard
        if (location.startsWith('/admin') && !user.role.isAdmin) {
          return RouteNames.employeeDashboard;
        }

        // Admin attempting to access Employee routes -> redirected to admin dashboard
        if (location.startsWith('/employee') && !user.role.isEmployee) {
          return RouteNames.adminDashboard;
        }

        // Allow navigation to legitimate target (e.g. /profile, /admin/dashboard, /employee/dashboard)
        return null;
      }

      // Default fallback: send unauthenticated users to login
      return isLogin ? null : RouteNames.login;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.employeeDashboard,
        builder: (context, state) => const EmployeeDashboardScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminShell(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: RouteNames.adminDashboard,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: RouteNames.adminEmployees,
            builder: (context, state) => const EmployeeListScreen(),
          ),
          GoRoute(
            path: RouteNames.adminProducts,
            builder: (context, state) => const ProductListScreen(),
          ),
          GoRoute(
            path: RouteNames.adminInventory,
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: RouteNames.adminProduction,
            builder: (context, state) => const ProductionListScreen(),
          ),
          GoRoute(
            path: RouteNames.adminQueries,
            builder: (context, state) => const QueryListScreen(),
          ),
          GoRoute(
            path: RouteNames.adminReports,
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
