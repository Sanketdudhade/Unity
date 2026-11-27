// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unity/core/constants/firestore_paths.dart';
import 'package:unity/features/employees/data/repositories/employee_repository.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockWriteBatch extends Mock implements WriteBatch {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

void main() {
  group('EmployeeRepository.deleteEmployee Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockWriteBatch mockBatch;
    late MockCollectionReference mockUsersCollection;
    late MockCollectionReference mockEmployeesCollection;
    late MockDocumentReference mockUserDoc;
    late MockDocumentReference mockEmpDoc;
    late EmployeeRepository repository;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockBatch = MockWriteBatch();
      mockUsersCollection = MockCollectionReference();
      mockEmployeesCollection = MockCollectionReference();
      mockUserDoc = MockDocumentReference();
      mockEmpDoc = MockDocumentReference();

      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockFirestore.collection(FirestorePaths.usersCollection))
          .thenReturn(mockUsersCollection);
      when(() => mockFirestore.collection(FirestorePaths.employeesCollection('org_unity_001')))
          .thenReturn(mockEmployeesCollection);

      when(() => mockUsersCollection.doc('emp_user_001')).thenReturn(mockUserDoc);
      when(() => mockEmployeesCollection.doc('emp_user_001')).thenReturn(mockEmpDoc);

      when(() => mockBatch.delete(mockUserDoc)).thenReturn(null);
      when(() => mockBatch.delete(mockEmpDoc)).thenReturn(null);
      when(() => mockBatch.commit()).thenAnswer((_) async {});

      repository = EmployeeRepository(firestore: mockFirestore);
    });

    test('deletes user profile and employee directory record in batch', () async {
      await repository.deleteEmployee(
        uid: 'emp_user_001',
        organizationId: 'org_unity_001',
      );

      verify(() => mockFirestore.batch()).called(1);
      verify(() => mockUsersCollection.doc('emp_user_001')).called(1);
      verify(() => mockEmployeesCollection.doc('emp_user_001')).called(1);
      verify(() => mockBatch.delete(mockUserDoc)).called(1);
      verify(() => mockBatch.delete(mockEmpDoc)).called(1);
      verify(() => mockBatch.commit()).called(1);
    });

    test('handles empty organizationId without deleting employee subcollection', () async {
      await repository.deleteEmployee(
        uid: 'emp_user_001',
        organizationId: '',
      );

      verify(() => mockFirestore.batch()).called(1);
      verify(() => mockUsersCollection.doc('emp_user_001')).called(1);
      verify(() => mockBatch.delete(mockUserDoc)).called(1);
      verifyNever(() => mockEmployeesCollection.doc(any()));
      verify(() => mockBatch.commit()).called(1);
    });
  });
}
