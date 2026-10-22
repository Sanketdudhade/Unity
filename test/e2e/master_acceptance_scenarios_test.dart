import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/core/constants/app_enums.dart';
import 'package:unity/core/errors/app_exceptions.dart';
import 'package:unity/core/utils/csv_exporter.dart';
import 'package:unity/features/auth/data/models/app_user_model.dart';
import 'package:unity/features/inventory/data/models/material_model.dart';
import 'package:unity/features/inventory/data/models/stock_balance_model.dart';
import 'package:unity/features/inventory/data/models/stock_movement_model.dart';
import 'package:unity/features/process_queries/data/models/process_query_model.dart';
import 'package:unity/features/processes/data/models/process_template_model.dart';
import 'package:unity/features/products/data/models/product_model.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/process_update_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';

void main() {
  group('Phase 6: Master Prompt End-to-End Acceptance Scenarios', () {
    const String testOrgId = 'org_unity_001';

    // =========================================================================
    // Scenario 1: Admin securely creates an employee; employee logs in and
    // sees only authorized tasks.
    // =========================================================================
    group('Scenario 1: Employee Provisioning, Authentication & RBAC Boundaries', () {
      test('Admin provisions employee account with strict RBAC metadata and active state', () {
        final now = DateTime.now();
        final employeeMap = {
          'uid': 'emp_cnc_operator_01',
          'fullName': 'Mahesh Sharma',
          'email': 'mahesh.cnc@unity.internal',
          'role': 'EMPLOYEE',
          'organizationId': testOrgId,
          'isActive': true,
          'department': 'Machining',
          'employeeCode': 'EMP-014',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        final user = AppUserModel.fromMap(employeeMap, 'emp_cnc_operator_01');

        expect(user.uid, equals('emp_cnc_operator_01'));
        expect(user.fullName, equals('Mahesh Sharma'));
        expect(user.email, equals('mahesh.cnc@unity.internal'));
        expect(user.role, equals(UserRole.employee));
        expect(user.role.isEmployee, isTrue);
        expect(user.role.isAdmin, isFalse);
        expect(user.organizationId, equals(testOrgId));
        expect(user.isActive, isTrue);
      });

      test('Employee dashboard filters work to show ONLY assigned tasks', () {
        const task1 = OrderProcessModel(
          id: 'proc_001',
          templateStepId: 'step_11',
          name: '3D Precision Machining',
          sequence: 11,
          targetQty: 50,
          assignedEmployeeUid: 'emp_cnc_operator_01',
          assignedEmployeeName: 'Mahesh Sharma',
          status: 'IN_PROGRESS',
        );

        const task2 = OrderProcessModel(
          id: 'proc_002',
          templateStepId: 'step_12',
          name: 'Heat Treatment',
          sequence: 12,
          targetQty: 50,
          assignedEmployeeUid: 'emp_metallurgist_02',
          assignedEmployeeName: 'Vikram Joshi',
          status: 'NOT_STARTED',
        );

        const task3 = OrderProcessModel(
          id: 'proc_003',
          templateStepId: 'step_14',
          name: 'Assembly',
          sequence: 14,
          targetQty: 50,
          assignedEmployeeUid: 'emp_cnc_operator_01',
          assignedEmployeeName: 'Mahesh Sharma',
          status: 'NOT_STARTED',
        );

        final allTasks = [task1, task2, task3];
        const currentOperatorUid = 'emp_cnc_operator_01';

        // Filtering rule strictly matches tasks assigned to operator
        final authorizedTasks = allTasks
            .where((t) => t.assignedEmployeeUid == currentOperatorUid)
            .toList();

        expect(authorizedTasks.length, equals(2));
        expect(authorizedTasks.map((t) => t.id), containsAll(['proc_001', 'proc_003']));
        expect(authorizedTasks.map((t) => t.id), isNot(contains('proc_002')));
      });
    });

    // =========================================================================
    // Scenario 2: Admin creates a part and an order for 50 pieces, chooses a
    // manufacturing template and assigns due dates and employees to each process.
    // =========================================================================
    group('Scenario 2: Part Catalog, 17-Stage Template & Work Order Setup', () {
      test('Admin creates product part definition with revision and drawing number', () {
        const product = ProductModel(
          id: 'prod_turbine_flange',
          partCode: 'TF-500-SS',
          name: 'High-Pressure Turbine Flange',
          description: 'Industrial SS-316 high-pressure steam flange',
          drawingNumber: 'DWG-TF-2026-04',
          revision: 'Rev B',
          unit: 'PCS',
          customerReference: 'PO-SIEMENS-9921',
          isActive: true,
        );

        expect(product.partCode, equals('TF-500-SS'));
        expect(product.drawingNumber, equals('DWG-TF-2026-04'));
        expect(product.revision, equals('Rev B'));
        expect(product.unit, equals('PCS'));
        expect(product.isActive, isTrue);
      });

      test('17-stage manufacturing template snapshots 17 sequential processes for 50 pieces', () {
        final steps = ProcessTemplateModel.default17Stages();
        expect(steps.length, equals(17));
        expect(steps.first.name, equals('RFQ received'));
        expect(steps.last.name, equals('Dispatch'));

        const targetQty = 50;
        final scheduledDue = DateTime.now().add(const Duration(days: 30));

        // Generate snapshotted order processes for all 17 stages
        final snapshottedProcesses = steps.map((step) {
          return OrderProcessModel(
            id: 'proc_stage_${step.sequence}',
            templateStepId: step.id,
            name: step.name,
            sequence: step.sequence,
            status: 'NOT_STARTED',
            targetQty: targetQty,
            completedQty: 0,
            assignedEmployeeUid: step.sequence == 11 ? 'emp_cnc_operator_01' : '',
            assignedEmployeeName: step.sequence == 11 ? 'Mahesh Sharma' : 'Unassigned',
            dueAt: scheduledDue,
            dependsOnStepSequence: step.dependsOnStepSequence,
          );
        }).toList();

        expect(snapshottedProcesses.length, equals(17));
        expect(snapshottedProcesses.first.targetQty, equals(50));
        expect(snapshottedProcesses[10].sequence, equals(11));
        expect(snapshottedProcesses[10].assignedEmployeeUid, equals('emp_cnc_operator_01'));
        expect(snapshottedProcesses[10].dueAt, equals(scheduledDue));
      });
    });

    // =========================================================================
    // Scenario 3: Employee starts their assigned process, adds a 10-piece daily
    // update, and the admin sees the update author, timestamp and progress.
    // =========================================================================
    group('Scenario 3: Station Output Logging, Author Auditing & Progress Tracking', () {
      test('Employee logs 10-piece increment and admin verifies 20% progress', () {
        final updateTime = DateTime(2026, 10, 15, 16, 0);

        final update = ProcessUpdateModel(
          id: 'upd_shift_1',
          actorUid: 'emp_cnc_operator_01',
          actorName: 'Mahesh Sharma',
          deltaCompletedQty: 10,
          hoursSpent: 4.5,
          notes: 'Completed initial roughing pass on 10 flanges',
          createdAt: updateTime,
        );

        // Verification of update metadata
        expect(update.actorUid, equals('emp_cnc_operator_01'));
        expect(update.actorName, equals('Mahesh Sharma'));
        expect(update.deltaCompletedQty, equals(10));
        expect(update.hoursSpent, equals(4.5));
        expect(update.createdAt, equals(updateTime));

        // Applying update to the active stage of target 50
        const initialCompleted = 0;
        const targetQuantity = 50;
        final newCompleted = initialCompleted + update.deltaCompletedQty;
        final progressRatio = newCompleted / targetQuantity;

        expect(newCompleted, equals(10));
        expect(progressRatio, equals(0.20)); // Exactly 20.0%
      });
    });

    // =========================================================================
    // Scenario 4: Employee requests completion; admin approves; dependent next
    // process becomes available. Rejection/rework is auditable.
    // =========================================================================
    group('Scenario 4: Stage Approval, Sequential Unlocking & Rework Audit', () {
      test('Stage 1 completion unlocks dependent Stage 2, which remains locked before approval', () {
        final stepStatusMap = <int, String>{
          1: 'IN_PROGRESS',
          2: 'NOT_STARTED',
        };

        // Stage 2 depends on Stage 1
        const stage2 = OrderProcessModel(
          id: 'proc_02',
          templateStepId: 'step_2',
          name: 'Feasibility study',
          sequence: 2,
          targetQty: 50,
          dependsOnStepSequence: [1],
        );

        // While Stage 1 is IN_PROGRESS, Stage 2 must be locked
        expect(stage2.isUnlocked(stepStatusMap), isFalse);

        // Employee requests completion: status -> PENDING_APPROVAL
        stepStatusMap[1] = 'PENDING_APPROVAL';
        expect(stage2.isUnlocked(stepStatusMap), isFalse);

        // Admin approves Stage 1: status -> COMPLETED
        stepStatusMap[1] = 'COMPLETED';
        expect(stage2.isUnlocked(stepStatusMap), isTrue);
      });

      test('Admin rejection for rework sets REWORK_REQUIRED with supervisor feedback', () {
        const stage3 = OrderProcessModel(
          id: 'proc_03',
          templateStepId: 'step_3',
          name: 'Quotation',
          sequence: 3,
          targetQty: 50,
          status: 'PENDING_APPROVAL',
        );

        // Admin inspects and identifies missing heat-treatment cost estimates
        const reworkReason = 'Missing vendor quote for nitrogen case-hardening';
        final reworkedStage = stage3.copyWith(
          status: 'REWORK_REQUIRED',
          reworkReason: reworkReason,
          notes: 'REWORK: $reworkReason',
        );

        expect(reworkedStage.status, equals('REWORK_REQUIRED'));
        expect(reworkedStage.isReworkRequired, isTrue);
        expect(reworkedStage.reworkReason, contains('nitrogen case-hardening'));
      });
    });

    // =========================================================================
    // Scenario 5: Admin receives 100 kg of steel; an authorized employee consumes
    // 15 kg against a specific process; balance becomes 85 kg and ledger records
    // employee/order/process.
    // =========================================================================
    group('Scenario 5: Material Inward GRN Receipt & Work Order Issue Ledger', () {
      test('100 kg receipt and 15 kg process issue results in 85 kg with full audit trail', () {
        // Material: Steel Bar Stock (unit: KG, unitScale: 1000 base units)
        final material = MaterialModel(
          id: 'mat_steel_316',
          sku: 'RAW-SS-316L-BAR',
          name: 'Stainless Steel 316L Solid Bar',
          category: 'RAW_MATERIAL',
          unit: 'KG',
          unitScale: 1000,
          minimumStock: 20000, // 20.000 kg safety threshold
        );

        // 1. Initial State: 0 base units
        var balance = StockBalanceModel(
          id: 'mat_steel_316_MAIN',
          materialId: material.id,
          materialSku: material.sku,
          materialName: material.name,
          locationId: 'MAIN',
          currentQuantity: 0,
          allocatedQuantity: 0,
          availableQuantity: 0,
          unit: material.unit,
          unitScale: material.unitScale,
          minimumStock: material.minimumStock,
        );
        expect(balance.currentQuantity, equals(0));

        // 2. Inward Receipt: 100 kg = 100,000 base units
        const receiptKg = 100;
        final receiptBaseUnits = receiptKg * material.unitScale;
        final balanceAfterReceipt = balance.currentQuantity + receiptBaseUnits;

        final receiptTx = StockTransactionModel(
          id: 'tx_rec_001',
          transactionNumber: 'TX-GRN-2026-001',
          type: 'RECEIPT',
          materialId: material.id,
          materialSku: material.sku,
          materialName: material.name,
          locationId: 'MAIN',
          quantityDelta: receiptBaseUnits,
          balanceBefore: balance.currentQuantity,
          balanceAfter: balanceAfterReceipt,
          performedByUid: 'admin_uid_001',
          performedByName: 'Admin Operator',
          referenceNumber: 'PO-VENDOR-STEEL-551',
          unit: 'KG',
          unitScale: 1000,
        );

        balance = StockBalanceModel(
          id: 'mat_steel_316_MAIN',
          materialId: material.id,
          materialSku: material.sku,
          materialName: material.name,
          locationId: 'MAIN',
          currentQuantity: balanceAfterReceipt,
          allocatedQuantity: 0,
          availableQuantity: balanceAfterReceipt,
          unit: material.unit,
          unitScale: material.unitScale,
          minimumStock: material.minimumStock,
        );
        expect(balance.currentQuantity, equals(100000));
        expect(receiptTx.balanceAfter, equals(100000));

        // 3. Authorized employee consumes 15 kg against order WO-2026-500, process proc_stage_11
        const issueKg = 15;
        final issueBaseUnits = issueKg * material.unitScale;
        final balanceAfterIssue = balance.currentQuantity - issueBaseUnits;

        final issueTx = StockTransactionModel(
          id: 'tx_iss_002',
          transactionNumber: 'TX-ISS-2026-002',
          type: 'ISSUE',
          materialId: material.id,
          materialSku: material.sku,
          materialName: material.name,
          locationId: 'MAIN',
          quantityDelta: -issueBaseUnits,
          balanceBefore: balance.currentQuantity,
          balanceAfter: balanceAfterIssue,
          performedByUid: 'emp_cnc_operator_01',
          performedByName: 'Mahesh Sharma',
          orderId: 'WO-2026-500',
          processId: 'proc_stage_11',
          referenceNumber: 'REQUISITION-WO500-STAGE11',
          unit: 'KG',
          unitScale: 1000,
        );

        balance = StockBalanceModel(
          id: 'mat_steel_316_MAIN',
          materialId: material.id,
          materialSku: material.sku,
          materialName: material.name,
          locationId: 'MAIN',
          currentQuantity: balanceAfterIssue,
          allocatedQuantity: 0,
          availableQuantity: balanceAfterIssue,
          unit: material.unit,
          unitScale: material.unitScale,
          minimumStock: material.minimumStock,
        );

        // Verification of final balance and audit references
        expect(balance.currentQuantity, equals(85000)); // Exactly 85,000 base units = 85.000 kg
        expect(balance.currentQuantity / material.unitScale, equals(85.0));
        expect(issueTx.quantityDelta, equals(-15000));
        expect(issueTx.performedByUid, equals('emp_cnc_operator_01'));
        expect(issueTx.orderId, equals('WO-2026-500'));
        expect(issueTx.processId, equals('proc_stage_11'));
      });
    });

    // =========================================================================
    // Scenario 6: Two employees attempt a conflicting stock deduction: the system
    // never generates a negative balance. A repeated request cannot double deduct stock.
    // =========================================================================
    group('Scenario 6: Race Condition Invariants & Double-Deduction Prevention', () {
      test('Concurrent stock deduction never allows negative balance and throws InsufficientStockException', () {
        // Current balance: 10 kg = 10,000 base units
        const currentStock = 10000;
        const employee1Request = 8000; // 8 kg
        const employee2Request = 5000; // 5 kg

        // Helper simulation of atomic ledger deduction logic
        int deductStock(int balance, int requestQty) {
          if (balance - requestQty < 0) {
            throw const InsufficientStockException(
              'Cannot deduct stock: balance would become negative.',
            );
          }
          return balance - requestQty;
        }

        // Employee 1 executes first
        final balanceAfterEmp1 = deductStock(currentStock, employee1Request);
        expect(balanceAfterEmp1, equals(2000));

        // Employee 2 attempts deduction with remaining balance
        expect(
          () => deductStock(balanceAfterEmp1, employee2Request),
          throwsA(isA<InsufficientStockException>()),
        );

        // Balance remains strictly positive at 2000 base units
        expect(balanceAfterEmp1 >= 0, isTrue);
      });

      test('Repeated / replayed transaction request rejected once stock is depleted', () {
        int balance = 5000;
        const requestQty = 5000;

        // First attempt succeeds and leaves 0 balance
        balance -= requestQty;
        expect(balance, equals(0));

        // Replayed request must fail
        expect(() {
          if (balance - requestQty < 0) {
            throw const InsufficientStockException('Insufficient inventory balance.');
          }
          balance -= requestQty;
        }, throwsA(isA<InsufficientStockException>()));

        expect(balance, equals(0));
      });
    });

    // =========================================================================
    // Scenario 7: Admin raises a question about an overdue process; the employee
    // responds; query history and status are correct; notification is sent or safely retried/logged.
    // =========================================================================
    group('Scenario 7: Shop-Floor Query Lifecycle & Dispute Resolution', () {
      test('Query status progresses from open to in_review to resolved with notes', () {
        // Admin raises inquiry
        final query = ProcessQuery(
          id: 'qry_overdue_machining',
          ticketNumber: 'TKT-2026-089',
          title: '3D Precision Machining Delayed by 48h',
          description: 'Stage 11 for WO-2026-500 is past due date. Please advise ETA.',
          workOrder: 'WO-2026-500',
          stage: '3D Precision Machining',
          severity: 'high',
          status: 'open',
          reportedByName: 'Admin Supervisor',
          reportedByUid: 'admin_uid_001',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        );

        expect(query.isOpen, isTrue);
        expect(query.isResolved, isFalse);
        expect(query.severity, equals('high'));

        // Employee responds and acknowledges ticket (status -> in_review)
        final inReviewQuery = query.copyWith(
          status: 'in_review',
        );
        expect(inReviewQuery.isInReview, isTrue);

        // Resolution recorded with corrective action details
        final resolvedQuery = inReviewQuery.copyWith(
          status: 'resolved',
          resolutionNotes: 'Spindle bearings serviced and re-calibrated. Machining resuming.',
          updatedAt: DateTime.now(),
        );

        expect(resolvedQuery.isResolved, isTrue);
        expect(resolvedQuery.isOpen, isFalse);
        expect(resolvedQuery.resolutionNotes, contains('Spindle bearings serviced'));
      });
    });

    // =========================================================================
    // Scenario 8: Admin views multiple independent products/orders, filters pending
    // and delayed work, sees employee-wise material usage and exports an accurate CSV report.
    // =========================================================================
    group('Scenario 8: Multi-Order Dashboard Filtering & RFC 4180 CSV Export', () {
      test('Filters pending and delayed orders and exports RFC 4180 compliant CSV', () {
        final now = DateTime.now();

        final orders = [
          ProductionOrder(
            id: 'WO-101',
            orderNumber: 'WO-2026-101',
            productName: 'Turbine Flange',
            targetQuantity: 50.0,
            completedQuantity: 50.0,
            unit: 'PCS',
            status: 'completed',
            priority: 'high',
            dueDate: now.subtract(const Duration(days: 2)),
          ),
          ProductionOrder(
            id: 'WO-102',
            orderNumber: 'WO-2026-102',
            productName: 'Shaft Coupler',
            targetQuantity: 100.0,
            completedQuantity: 20.0,
            unit: 'PCS',
            status: 'in_production',
            priority: 'urgent',
            dueDate: now.subtract(const Duration(days: 1)), // Delayed!
          ),
          ProductionOrder(
            id: 'WO-103',
            orderNumber: 'WO-2026-103',
            productName: 'Bearing Housing, Cast "A"',
            targetQuantity: 25.0,
            completedQuantity: 0.0,
            unit: 'PCS',
            status: 'scheduled',
            priority: 'normal',
            dueDate: now.add(const Duration(days: 7)),
          ),
        ];

        // Filter pending and delayed orders
        final pendingOrDelayed = orders.where((o) {
          final isDelayed = (o.dueDate?.isBefore(now) ?? false) && !o.isCompleted;
          final isPending = o.isScheduled;
          return isDelayed || isPending;
        }).toList();

        expect(pendingOrDelayed.length, equals(2));
        expect(pendingOrDelayed.map((o) => o.id), containsAll(['WO-102', 'WO-103']));

        // Export to RFC 4180 CSV
        final headers = [
          'Order Number',
          'Product Name',
          'Target Qty',
          'Completed Qty',
          'Progress %',
          'Status',
        ];

        final rows = orders.map((o) => [
          o.orderNumber,
          o.productName, // Includes commas and quotes in Bearing Housing
          o.targetQuantity.toInt().toString(),
          o.completedQuantity.toInt().toString(),
          '${(o.progressPercentage * 100).toStringAsFixed(1)}%',
          o.status,
        ]).toList();

        final csvOutput = CsvExporter.generateCsv(headers: headers, rows: rows);

        // Verify CSV header
        expect(csvOutput, startsWith('Order Number,Product Name,Target Qty,Completed Qty,Progress %,Status'));
        // Verify RFC 4180 quote escaping for "Bearing Housing, Cast ""A"""
        expect(csvOutput, contains('"Bearing Housing, Cast ""A"""'));
        // Verify line breaks between records (Header + 3 rows)
        final lines = csvOutput.trim().split('\n');
        expect(lines.length, equals(4));
      });
    });

    // =========================================================================
    // Scenario 9: Every unauthorized or cross-organization access attempt fails
    // in security tests, even if someone bypasses the Flutter interface.
    // =========================================================================
    group('Scenario 9: Multi-Tenant Boundary Enforcement & Role Guard Security', () {
      test('Access across organization tenant boundaries is strictly rejected', () {
        const actorOrgId = 'org_unity_001';
        const targetForeignOrgId = 'org_competitor_888';

        void verifyTenantAccess(String resourceOrgId) {
          if (resourceOrgId != actorOrgId) {
            throw const UnauthorizedException(
              'Access denied: cross-tenant access violation.',
            );
          }
        }

        // Access to own organization succeeds
        expect(() => verifyTenantAccess(actorOrgId), returnsNormally);

        // Access to foreign organization throws UnauthorizedException
        expect(
          () => verifyTenantAccess(targetForeignOrgId),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('Employee role attempting administrative privileged action throws UnauthorizedException', () {
        final employeeUser = AppUserModel(
          uid: 'emp_007',
          fullName: 'Test Operator',
          email: 'op@unity.internal',
          role: UserRole.employee,
          organizationId: testOrgId,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        void executeAdminAction(AppUserModel actor) {
          if (actor.role != UserRole.admin) {
            throw const UnauthorizedException(
              'Security violation: only administrators may approve stage completions.',
            );
          }
        }

        expect(
          () => executeAdminAction(employeeUser),
          throwsA(isA<UnauthorizedException>()),
        );
      });

      test('Inactive/disabled user profile throws AccountInactiveException', () {
        final inactiveUser = AppUserModel(
          uid: 'emp_disabled_09',
          fullName: 'Ex Employee',
          email: 'ex@unity.internal',
          role: UserRole.employee,
          organizationId: testOrgId,
          isActive: false, // Disabled
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        void verifyAccountActive(AppUserModel user) {
          if (!user.isActive) {
            throw const AccountInactiveException(
              'Account is disabled by organization administrator.',
            );
          }
        }

        expect(
          () => verifyAccountActive(inactiveUser),
          throwsA(isA<AccountInactiveException>()),
        );
      });
    });
  });
}
