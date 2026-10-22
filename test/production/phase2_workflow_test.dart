import 'package:flutter_test/flutter_test.dart';
import 'package:unity/features/processes/data/models/process_template_model.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';

void main() {
  group('Phase 2: ProductModel Tests', () {
    test('ProductModel parses valid document map and serializes accurately', () {
      final map = {
        'partCode': 'PRD-FB-001',
        'name': 'Flange Bushing 25mm',
        'description': 'Precision brass flange bushing for motor mounting',
        'drawingNumber': 'DWG-FB-2026-A',
        'revision': 'R2',
        'unit': 'PCS',
        'customerReference': 'Tata Motors - PO#8892',
        'isActive': true,
      };

      final product = ProductModel.fromMap('prod_01', map);

      expect(product.id, equals('prod_01'));
      expect(product.partCode, equals('PRD-FB-001'));
      expect(product.name, equals('Flange Bushing 25mm'));
      expect(product.drawingNumber, equals('DWG-FB-2026-A'));
      expect(product.revision, equals('R2'));
      expect(product.unit, equals('PCS'));
      expect(product.isActive, isTrue);

      final outMap = product.toMap();
      expect(outMap['partCode'], equals('PRD-FB-001'));
      expect(outMap['name'], equals('Flange Bushing 25mm'));
      expect(outMap['drawingNumber'], equals('DWG-FB-2026-A'));
      expect(outMap['revision'], equals('R2'));
    });

    test('ProductModel handles fallback defaults when optional fields are omitted', () {
      final map = {
        'name': 'Hex Bolt M8',
      };

      final product = ProductModel.fromMap('prod_02', map);

      expect(product.id, equals('prod_02'));
      expect(product.name, equals('Hex Bolt M8'));
      expect(product.partCode, equals('PRD-NEW'));
      expect(product.drawingNumber, equals(''));
      expect(product.revision, equals('Rev A'));
      expect(product.unit, equals('PCS'));
      expect(product.isActive, isTrue);
    });
  });

  group('Phase 2: ProcessTemplateModel & 17-Stage Manufacturing Flow', () {
    test('Default 17-Stage Flow contains exactly 17 sequential stages', () {
      final steps = ProcessTemplateModel.default17Stages();

      expect(steps.length, equals(17));

      // Assert continuous sequences 1..17
      for (int i = 0; i < steps.length; i++) {
        expect(steps[i].sequence, equals(i + 1));
      }

      // Assert key sequential manufacturing checkpoints from flowchart
      expect(steps[0].name, equals('RFQ received'));
      expect(steps[0].dependsOnStepSequence, isEmpty);

      expect(steps[1].name, equals('Feasibility study'));
      expect(steps[1].dependsOnStepSequence, equals([1]));

      expect(steps[2].name, equals('Quotation'));
      expect(steps[2].dependsOnStepSequence, equals([2]));

      // Quality Inspection checkpoint
      final inspectionStep = steps.firstWhere((s) => s.sequence == 16);
      expect(inspectionStep.name, equals('Inspection'));
      expect(inspectionStep.dependsOnStepSequence, equals([15]));

      // Final dispatch checkpoint
      final dispatchStep = steps.last;
      expect(dispatchStep.sequence, equals(17));
      expect(dispatchStep.name, equals('Dispatch'));
      expect(dispatchStep.dependsOnStepSequence, equals([16]));
    });

    test('ProcessTemplateModel serializes with versioning metadata', () {
      final template = ProcessTemplateModel(
        id: 'tmpl_std_17',
        name: 'Standard 17-Stage Flow',
        version: 1,
        steps: ProcessTemplateModel.default17Stages(),
        isActive: true,
      );

      final map = template.toMap();
      expect(map['name'], equals('Standard 17-Stage Flow'));
      expect(map['version'], equals(1));
      expect(map['isActive'], isTrue);
    });
  });

  group('Phase 2: Sequential Stage Dependency & Lock Enforcement', () {
    test('Initial stage with empty dependencies is unlocked by default', () {
      final stage1 = OrderProcessModel(
        id: 'proc_1',
        templateStepId: 'step_1',
        name: 'Drawing Review & Approval',
        sequence: 1,
        dependsOnStepSequence: const [],
        assignedEmployeeUid: 'emp_01',
        assignedEmployeeName: 'Lead Engineer',
        targetQty: 200,
        completedQty: 0,
        status: 'NOT_STARTED',
      );

      final statusMap = <int, String>{1: 'NOT_STARTED'};
      expect(stage1.isUnlocked(statusMap), isTrue);
    });

    test('Subsequent stage remains locked when prerequisite stage is incomplete', () {
      final stage2 = OrderProcessModel(
        id: 'proc_2',
        templateStepId: 'step_2',
        name: 'RM Inward & Inspection',
        sequence: 2,
        dependsOnStepSequence: const [1],
        assignedEmployeeUid: '',
        assignedEmployeeName: 'Unassigned',
        targetQty: 200,
        completedQty: 0,
        status: 'NOT_STARTED',
      );

      // Prerequisite step 1 is still NOT_STARTED
      final statusMapNotStarted = <int, String>{1: 'NOT_STARTED', 2: 'NOT_STARTED'};
      expect(stage2.isUnlocked(statusMapNotStarted), isFalse);

      // Prerequisite step 1 is IN_PROGRESS
      final statusMapInProgress = <int, String>{1: 'IN_PROGRESS', 2: 'NOT_STARTED'};
      expect(stage2.isUnlocked(statusMapInProgress), isFalse);

      // Prerequisite step 1 is completed
      final statusMapCompleted = <int, String>{1: 'COMPLETED', 2: 'NOT_STARTED'};
      expect(stage2.isUnlocked(statusMapCompleted), isTrue);
    });

    test('Stage with multiple dependencies unlocks only when ALL dependencies are COMPLETED', () {
      final assemblyStage = OrderProcessModel(
        id: 'proc_sub_assy',
        templateStepId: 'step_10',
        name: 'Final Assembly & Fastening',
        sequence: 10,
        dependsOnStepSequence: const [8, 9], // Depends on Surface Treatment (8) AND In-Process QC (9)
        assignedEmployeeUid: '',
        assignedEmployeeName: 'Unassigned',
        targetQty: 100,
        completedQty: 0,
        status: 'NOT_STARTED',
      );

      // Only step 8 is completed, step 9 is not
      expect(
        assemblyStage.isUnlocked({8: 'COMPLETED', 9: 'IN_PROGRESS', 10: 'NOT_STARTED'}),
        isFalse,
      );

      // Only step 9 is completed, step 8 is not
      expect(
        assemblyStage.isUnlocked({8: 'IN_PROGRESS', 9: 'COMPLETED', 10: 'NOT_STARTED'}),
        isFalse,
      );

      // Both step 8 and 9 are COMPLETED
      expect(
        assemblyStage.isUnlocked({8: 'COMPLETED', 9: 'COMPLETED', 10: 'NOT_STARTED'}),
        isTrue,
      );
    });

    test('OrderProcessModel status helpers detect active, completed, and pause states', () {
      final stage = OrderProcessModel(
        id: 'proc_test',
        templateStepId: 'step_test',
        name: 'CNC Milling',
        sequence: 5,
        dependsOnStepSequence: const [4],
        assignedEmployeeUid: 'emp_machinist',
        assignedEmployeeName: 'Machinist A',
        targetQty: 50,
        completedQty: 50,
        status: 'COMPLETED',
      );

      expect(stage.isCompleted, isTrue);
      expect(stage.isInProgress, isFalse);
      expect(stage.isNotStarted, isFalse);

      final inProgressStage = stage.copyWith(status: 'IN_PROGRESS');
      expect(inProgressStage.isInProgress, isTrue);
      expect(inProgressStage.isCompleted, isFalse);
    });
  });
}
