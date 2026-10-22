import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/auth/presentation/providers/auth_provider.dart';
import 'package:unity/features/employees/data/repositories/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return EmployeeRepository(firestore: firestore);
});

/// Stream provider for all organization employees.
final employeesStreamProvider = StreamProvider<List<AppUserModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final orgId = authState.user?.organizationId;

  if (orgId == null || orgId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(employeeRepositoryProvider);
  return repository.getEmployeesStream(orgId);
});

/// Count of total active & registered employees in the organization.
final employeeCountProvider = Provider<int>((ref) {
  final employeesAsync = ref.watch(employeesStreamProvider);
  return employeesAsync.maybeWhen(
    data: (employees) => employees.length,
    orElse: () => 0,
  );
});
