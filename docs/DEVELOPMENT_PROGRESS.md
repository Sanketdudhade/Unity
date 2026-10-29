# Manufacturing Production Tracking & Inventory System — Development Progress

## Project Context
- **Organization**: One manufacturing organization (initial target: `org_unity_001`), 21–50 employees, architected for future multi-organization scaling.
- **Client**: Single Flutter Android app with role-based Admin and Employee experiences.
- **Backend**: Firebase Authentication (Email/Password), Cloud Firestore, Cloud Storage, Firebase Cloud Messaging, and Cloud Functions (Node.js LTS / TypeScript).
- **Timezone**: `Asia/Kolkata` display and factory schedules; stored in UTC server timestamps.
- **Priorities**: Data correctness and security > reliable functionality > good user experience > low Firebase costs > development speed.

---

## Phase 0: Architecture, Firestore Schema, and Project Setup

### 1. Requirements Checklist & Business Assumptions
- [x] **Single Android App**: Admin & Employee interfaces unified in one Flutter codebase, strictly governed by `go_router` role guards and Firebase Security Rules.
- [x] **No Public Self-Registration**: Employee accounts are provisioned exclusively by authenticated Administrators. Initial admin is provisioned via secure bootstrap CLI/script with Admin SDK.
- [x] **Canonical Collection Hierarchy**: Strictly scoped to `/organizations/{organizationId}/...` with `/users/{uid}` as the sole non-sensitive global profile pointer.
- [x] **17-Stage Factory Workflow**: Default editable template with sequential dependencies:
  1. RFQ received
  2. Feasibility study
  3. Quotation
  4. Customer purchase order
  5. Concept drawing/design
  6. 3D design/modeling
  7. BOM release
  8. Material procurement
  9. Detailed drawing release
  10. Optional Custom Stage
  11. 3D precision machining
  12. Heat treatment
  13. 2D precision machining
  14. Assembly
  15. Trial
  16. Inspection
  17. Dispatch
- [x] **Template Versioning**: Snapshot step definitions into `productionOrders/{orderId}/processes/{processId}` upon order creation so editing templates never corrupts running orders.
- [x] **Integer Base Unit Inventory**: Material quantity stored strictly in integer base units (e.g. KG with scale 1000: 1.500 kg = 1500 units; PCS scale 1).
- [x] **Immutable Ledger**: `inventoryBalances` (read-only for clients) updated atomically with an immutable transaction ledger entry in `inventoryTransactions`.

---

### 2. Role Permission Matrix

| Collection / Path | ADMIN | EMPLOYEE | Unauthenticated |
| :--- | :---: | :---: | :---: |
| `/users/{uid}` | Read own + org members | Read own | Deny |
| `/organizations/{orgId}` | Read | Read | Deny |
| `.../employees/{uid}` | Read / Create / Update / Disable | Read directory (names/codes) | Deny |
| `.../products/{productId}` | Read / Create / Update | Read | Deny |
| `.../processTemplates/{templateId}` | Read / Create / Update / Version | Read | Deny |
| `.../productionOrders/{orderId}` | Read / Create / Update / Cancel | Read assigned orders | Deny |
| `.../processes/{processId}` | Read / Assign / Approve / Rework | Read assigned / Update stage | Deny |
| `.../updates/{updateId}` | Read audit | Read / Create on assigned task | Deny |
| `.../materials/{materialId}` | Read / Create / Update | Read | Deny |
| `.../inventoryBalances/{locId}` | Read only (Server writes) | Read only (Server writes) | Deny |
| `.../inventoryTransactions/{txId}` | Read ledger | Read own transactions | Deny |
| `.../processQueries/{queryId}` | Read / Raise / Resolve | Read / Respond to assigned | Deny |
| `.../notifications/{notifId}` | Read / Write own | Read / Write own | Deny |
| `.../auditLogs/{auditId}` | Read (Admin only) | Deny | Deny |

---

### 3. Canonical Firestore Schema

```text
/users/{uid}
  uid: string
  email: string
  fullName: string
  role: 'ADMIN' | 'EMPLOYEE'
  organizationId: string
  isActive: boolean
  createdAt: timestamp

/organizations/{organizationId}
  id: string
  name: string
  code: string
  timezone: 'Asia/Kolkata'
  createdAt: timestamp

/organizations/{organizationId}/employees/{uid}
  uid: string
  employeeCode: string
  fullName: string
  email: string
  phone: string
  department: string
  role: 'ADMIN' | 'EMPLOYEE'
  isActive: boolean
  assignedTasksCount: number
  createdAt: timestamp
  updatedAt: timestamp

/organizations/{organizationId}/products/{productId}
  id: string
  partCode: string
  name: string
  description: string
  drawingNumber: string
  revision: string
  unit: string
  customerReference: string
  isActive: boolean
  createdAt: timestamp
  updatedAt: timestamp

/organizations/{organizationId}/processTemplates/{templateId}
  id: string
  name: string
  version: number
  isActive: boolean
  stagesCount: number
  createdAt: timestamp
  updatedAt: timestamp

/organizations/{organizationId}/processTemplates/{templateId}/steps/{stepId}
  id: string
  sequence: number
  name: string
  defaultDurationHours: number
  isOptional: boolean
  dependsOnStepSequence: number[]
  allowedRoles: string[]

/organizations/{organizationId}/productionOrders/{orderId}
  id: string
  orderNumber: string
  productId: string
  productName: string
  productRevision: string
  customerName: string
  targetQty: number
  completedQty: number
  dueAt: timestamp
  status: 'CREATED' | 'IN_PROGRESS' | 'BLOCKED' | 'COMPLETED' | 'CANCELLED'
  processTemplateId: string
  templateVersion: number
  totalProcesses: number
  completedProcesses: number
  createdByUid: string
  createdAt: timestamp
  updatedAt: timestamp

/organizations/{organizationId}/productionOrders/{orderId}/processes/{processId}
  id: string
  templateStepId: string
  name: string
  sequence: number
  dependsOnProcessIds: string[]
  assignedEmployeeUid: string
  assignedEmployeeName: string
  targetQty: number
  completedQty: number
  status: 'NOT_STARTED' | 'ASSIGNED' | 'IN_PROGRESS' | 'BLOCKED' | 'PENDING_APPROVAL' | 'COMPLETED' | 'REWORK_REQUIRED' | 'CANCELLED'
  dueAt: timestamp
  startedAt: timestamp?
  completedAt: timestamp?
  approvedByUid: string?
  reworkReason: string?
  notes: string
  createdAt: timestamp
  updatedAt: timestamp

/organizations/{organizationId}/productionOrders/{orderId}/processes/{processId}/updates/{updateId}
  id: string
  actorUid: string
  actorName: string
  deltaCompletedQty: number
  notes: string
  hoursSpent: number?
  blockerReason: string?
  attachmentRefs: string[]
  createdAt: timestamp

/organizations/{organizationId}/materials/{materialId}
  id: string
  code: string
  name: string
  category: string
  unit: string
  unitScale: number # e.g. 1000 for KG (1g base unit), 1 for PCS
  reorderThresholdBaseUnits: number
  location: string
  isActive: boolean
  createdAt: timestamp
  updatedAt: timestamp

/organizations/{organizationId}/inventoryBalances/{materialLocationId}
  id: string # ${materialId}_${locationId}
  materialId: string
  locationId: string # 'MAIN'
  onHandBaseUnits: number
  updatedAt: timestamp

/organizations/{organizationId}/inventoryTransactions/{transactionId}
  id: string
  transactionType: 'RECEIPT' | 'CONSUMPTION' | 'RETURN' | 'ADJUSTMENT'
  materialId: string
  locationId: string
  quantityBaseUnits: number # Always positive integer
  operationId: string # Idempotency key
  employeeUid: string
  orderId: string?
  processId: string?
  reason: string
  createdByUid: string
  createdAt: timestamp

/organizations/{organizationId}/processQueries/{queryId}
  id: string
  ticketNumber: string
  title: string
  description: string
  orderId: string?
  processId: string?
  stage: string
  severity: 'low' | 'medium' | 'high' | 'critical'
  status: 'open' | 'in_review' | 'resolved'
  reportedByName: string
  reportedByUid: string
  assignedEmployeeUid: string?
  resolutionNotes: string?
  createdAt: timestamp
  updatedAt: timestamp

/organizations/{organizationId}/notifications/{notificationId}
  id: string
  recipientUid: string
  type: string
  title: string
  message: string
  entityType: string
  entityId: string
  readAt: timestamp?
  createdAt: timestamp

/organizations/{organizationId}/auditLogs/{auditId}
  id: string
  actorUid: string
  actorName: string
  action: string
  entityType: string
  entityId: string
  details: map
  timestamp: timestamp
```

---

## Phase Roadmap & Status

| Phase | Description | Status | Verification Gate |
| :--- | :--- | :---: | :--- |
| **Phase 0** | Architecture, Canonical Schema, Permissions, Setup | **COMPLETED** | Schema validated, rules mapped & deployed |
| **Phase 1** | Firebase Auth, Secure Admin Bootstrap, Role Shell, Employee Directory | **COMPLETED** | 40/40 tests passing, live Admin SDK |
| **Phase 2** | Products Master, Versioned Templates, Orders, Task Sequences | **COMPLETED** | 48/48 tests passing, 17 stages snapshotted, locked dependencies |
| **Phase 3** | Employee Daily Updates, Progress Calculation, Admin Approvals | **COMPLETED** | 58/58 tests passing, audit log, approval/rework workflow |
| **Phase 4** | Material Master, Balances, Atomic Integer Ledger Transactions | **COMPLETED** | 68/68 tests passing, atomic ledger, zero floating point |
| **Phase 5** | Queries, Resolution Flows, Live Dashboards, CSV Export | **COMPLETED** | 75/75 tests passing, RFC 4180 CSV, live KPI dashboard |
| **Phase 6** | End-to-End Acceptance Tests, Performance, Release Readiness | **COMPLETED** | All 9 master scenarios passing (90/90 tests) |

---

## Phase 2 Implementation Summary (COMPLETED)
- **Products Master**:
  - `ProductModel` with `partCode`, `name`, `description`, `drawingNumber`, `revision`, `unit`, `customerReference`, `isActive`.
  - `ProductRepository` and `activeProductsProvider` real-time streams.
  - `ProductListScreen` with quick create/toggle dialog, drawing number badges, search, and validation.
  - Added Route `/admin/products` and quick-access module tile on `AdminDashboardScreen`.
- **17-Stage Versioned Process Templates**:
  - `ProcessStepModel` with continuous sequences (1..17), allowed roles, and dependency tracking (`dependsOnStepSequence`).
  - `ProcessTemplateModel` with versioning and full reference flowchart default definition.
  - `ProcessTemplateRepository` with atomic subcollection writing.
- **Production Work Orders with Process Snapshotting**:
  - `OrderProcessModel` with invariant lock check `isUnlocked(stepStatusMap)`.
  - Sequential dependency enforcement: Subsequent stages cannot start or be marked in-progress until all prerequisite stages are `COMPLETED`.
  - Atomic batch snapshotting in `createOrderWithSnapshottedTemplate`.
  - `ProductionDetailsScreen`: Step-by-step 17-stage workflow timeline, lock badges, assigned operator chips, and progress percentage.
  - Enhanced `_showCreateOrderDialog` in `ProductionListScreen` allowing selection from the active products catalog and template flows.
- **Verification & Test Coverage**:
  - Automated tests: `test/production/phase2_workflow_test.dart` (8 comprehensive unit tests for product models, template flow, and dependency locking).
  - Total test suite: **48/48 tests passing**.
  - Static analysis: **0 issues found** across entire codebase.
  - Live database seed: `scripts/seed_phase2.js` populated standard products, 17-stage template, and sample order `WO-2026-101` in Firestore `unity-c5e69`.

---

## Phase 3 Implementation Summary (COMPLETED)
- **Process Daily Updates & Audit Trail**:
  - Created `ProcessUpdateModel` scoped under `.../processes/{processId}/updates/{updateId}` with actor attribution (`actorUid`, `actorName`), `deltaCompletedQty`, `hoursSpent`, `blockerReason`, `notes`, `attachmentRefs`, and `createdAt`.
  - Added `ProductionRepository.logProcessUpdate`: Atomic Firestore transaction that creates immutable audit record, increments `completedQty`, and transitions stage status to `IN_PROGRESS` or `BLOCKED`.
  - Real-time `processUpdatesStreamProvider` streaming chronological update logs per stage.
- **Progress Calculation & Stage Dependency Verification**:
  - Cumulative progress calculation with clamp guards: `progressPercentage = (completedQty / targetQty).clamp(0.0, 1.0)`.
  - Production order-level progress tracking with total and completed stage ratios.
- **Supervisor Review & Approval Workflow**:
  - Added `ProductionRepository.approveProcessStage`: Sets stage status to `COMPLETED`, records `approvedBy` and `completedAt`, and automatically increments parent order's `completedProcesses`.
  - Added `ProductionRepository.rejectProcessStageForRework`: Sets stage status to `REWORK_REQUIRED` with mandatory rework rationale for operator visibility and remediation.
  - Station Operator reassignment via `ProductionRepository.assignEmployeeToProcess`.
- **Shop-Floor Operator & Admin Dialog UI**:
  - `ProcessStageActionsDialog`: Comprehensive station actions sheet with:
    - Live target vs completed quantity indicator & progress bar.
    - Blocker alert banner & rework notice banner with supervisor feedback.
    - Log daily progress form (+Qty, hours spent, blocker toggle, shift notes).
    - Request supervisor review button (`PENDING_APPROVAL`).
    - Admin/Supervisor approval & rework rejection action buttons with confirmation prompts.
    - Historical update audit trail timeline.
    - Station operator assignment dropdown.
  - Integrated with `ProductionDetailsScreen` (tap any stage card in the 17-stage timeline to open actions).
  - Integrated with `EmployeeDashboardScreen` (`_AssignedManufacturingStagesSection` streams assigned stages across active orders for immediate one-tap logging).
- **Verification & Test Coverage**:
  - Automated tests: `test/production/phase3_updates_approval_test.dart` (10 unit tests covering model serialization, delta calculations, blocker status, supervisor approval audit trails, and rework rejections).
  - Total test suite: **58/58 tests passing**.
  - Static analysis: **0 issues found** (`dart analyze lib`).

---

## Phase 4 Implementation Summary (COMPLETED)
- **Material Master Catalog (`MaterialModel`)**:
  - Scoped to `/organizations/{orgId}/materials/{materialId}`.
  - Zero floating-point error architecture: Quantities stored strictly in integer base units (e.g. `unitScale = 1000` for continuous measurements such as KG, METER, LITER to preserve 3 decimal places; `unitScale = 1` for discrete counts like PCS, SHEET, BAR).
  - Fields: `sku`, `name`, `category` (`RAW_MATERIAL`, `SHEET_METAL`, `HARDWARE`, `FASTENER`, `CONSUMABLE`, `PACKAGING`), `unit`, `unitScale`, `minimumStock`, `reorderQuantity`, `defaultLocation`, `unitCost`, `notes`, `isActive`.
- **Real-Time Stock Balances (`StockBalanceModel`)**:
  - Scoped to `/organizations/{orgId}/inventoryBalances/{materialId}_MAIN` (read-only for clients, modified via transactions).
  - Invariant tracking: `currentQuantity`, `allocatedQuantity` (reserved for active work orders), and `availableQuantity = max(0, current - allocated)`.
  - Safety stock monitoring: `isLowStock = currentQuantity <= minimumStock`.
  - High-precision display formatting using `FactoryFormatters.formatBaseUnitsToDisplay`.
- **Authoritative Immutable Transaction Ledger (`StockTransactionModel`)**:
  - Scoped to `/organizations/{orgId}/inventoryTransactions/{transactionId}`.
  - Supported operations: `RECEIPT` (GRN incoming), `ISSUE` (shop-floor consumption), `ALLOCATION` (work order reservation), `DEALLOCATION` (order release), `SCRAP` (wastage write-off), `ADJUSTMENT` (cycle count audit), `RETURN` (excess returned to stock).
  - Audit trail fields: `transactionNumber`, `type`, `materialId`, `materialSku`, `materialName`, `locationId`, `quantityDelta` (signed), `balanceBefore`, `balanceAfter`, `orderId`, `processId`, `performedByUid`, `performedByName`, `referenceNumber`, `notes`, `unit`, `unitScale`, `createdAt`.
- **Atomic Integrity & Non-Negative Invariant Protection**:
  - `InventoryRepository.recordTransaction`: Runs inside a Cloud Firestore transaction (`firestore.runTransaction`).
  - Strict guard throws `InsufficientStockException` if an issue or scrap would cause `currentQuantity < 0`, or if an allocation exceeds available unallocated stock.
  - Denormalized synchronization on `materials/{materialId}` for backward compatibility.
- **Shop-Floor & Warehouse Inventory UI**:
  - `InventoryScreen`: Tabbed view supporting Materials & Stock, Transaction Ledger, and Low Stock Reorder.
  - `StockHistoryScreen`: Full-screen searchable and type-filterable ledger audit trail.
  - `LowStockScreen`: Targeted view of items breaching safety thresholds with one-tap Restock GRN receipt.
  - `AddMaterialScreen`: Full creation form with automatic unit scale configuration.
  - `ConsumeMaterialScreen`: Dedicated issue and work order consumption portal.
- **Verification & Test Coverage**:
  - Automated tests: `test/inventory/phase4_materials_ledger_test.dart` (10 unit tests verifying scaling, invariant checks, formatting, and exception handling).
  - Total test suite: **68/68 tests passing**.
  - Static analysis: **0 issues found** (`dart analyze lib`).
  - Live database seed: `scripts/seed_phase4.js` seeded 5 industrial materials, stock balances, and ledger transactions in Firestore `unity-c5e69`.

---

## Phase 5 Implementation Summary (COMPLETED)
- **Process Queries & Shop-Floor Ticket Resolution (`ProcessQuery`)**:
  - Scoped to `/organizations/{orgId}/processQueries/{queryId}`.
  - Fields: `ticketNumber`, `title`, `description`, `workOrder`, `stage`, `severity` (`low`, `medium`, `high`, `critical`), `status` (`open`, `in_review`, `resolved`), `reportedByName`, `reportedByUid`, `resolutionNotes`, timestamps.
  - `QueryRepository`: Real-time query streams, ticket creation, status progression (`in_review`), and resolution recording with corrective action notes.
  - `RaiseQueryScreen`: 1-tap ticket submission from shop-floor with work order linking and severity flags.
  - `QueryDetailsScreen`: Full ticket lifecycle management with supervisor investigation controls and resolution notes logging.
  - `QueryListScreen`: Search, status filter chips (`All`, `Open`, `In Review`, `Resolved`, `Critical`), and direct ticket creation.
  - `EmployeeDashboardScreen`: Added dedicated 1-tap "Raise Ticket" floor shortcut for shop-floor operators.
- **Executive Operations Dashboard & Real-Time KPIs**:
  - `ExecutiveKpiSummary` and `executiveKpiProvider` in `report_provider.dart`: Aggregates active workforce, total SKUs, low stock safety alerts, active production orders, and open tickets.
  - `AdminDashboardScreen`: Live operational overview with real-time KPI tiles and direct module links.
  - `ReportsScreen`: Facility Executive Summary gradient banner with operational KPIs, process task efficiency distribution, orders throughput, stock replenishment status, and live shop-floor audit trail.
- **Reports & RFC 4180 Standard CSV Export**:
  - Created `CsvExporter` utility: Compliant with RFC 4180 standard escaping for internal commas, double quotes (`""`), newlines, and nulls.
  - Created `CsvExportModal`: Reusable modal displaying file name, record count, monospace preview, and 1-tap "Copy to Clipboard" for Excel/Google Sheets.
  - `ProductionReportScreen`: Production orders report with order numbers, target vs completed, progress %, and CSV download.
  - `InventoryReportScreen`: Stock balance audit report with SKU, category, available vs total base units, safety thresholds, and CSV download.
  - `EmployeeReportScreen`: Workforce directory audit report with roles, active statuses, and CSV download.
  - Added "Detailed Audit Reports & CSV Export" navigation cards to `ReportsScreen`.
- **Verification & Test Coverage**:
  - Automated tests: `test/reports/phase5_queries_reports_test.dart` (7 unit tests covering `ProcessQuery` serialization, status helpers, `ExecutiveKpiSummary`, and `CsvExporter` RFC 4180 compliance).
  - Total test suite: **75/75 tests passing**.
  - Static analysis: **0 issues found** (`dart analyze lib`).
  - Seeding script prepared: `scripts/seed_phase5.js` for shop-floor process queries in Firestore `unity-c5e69`.

---

## Phase 6 Implementation Summary (COMPLETED)
- **Master End-to-End Acceptance Test Suite (`test/e2e/master_acceptance_scenarios_test.dart`)**:
  - Automated tests covering all 9 canonical Master Prompt scenarios:
    1. *Admin Employee Provisioning & RBAC*: Role restriction, task assignment filtering.
    2. *Product Master & 17-Stage Work Order*: Drawing numbers, revisions, template step snapshotting for 50 pieces.
    3. *Process Updates & Progress*: 10-piece daily output, hours, actor auditing, progress percentage (20.0%).
    4. *Sequential Lock & Rework*: Dependent step unlocking upon approval, `REWORK_REQUIRED` status with supervisor reason.
    5. *Material GRN & Issue Ledger*: 100 kg receipt, 15 kg work order issue, 85 kg remaining, full audit ledger.
    6. *Race Condition Protection & Invariant Preservation*: Negative balance prevention (`InsufficientStockException`), double-deduction prevention.
    7. *Shop-Floor Query Lifecycle*: Inquiry & ticket progression (`open` -> `in_review` -> `resolved`), corrective action notes.
    8. *Multi-Order Dashboard & RFC 4180 CSV*: Pending/delayed work order filtering, double-quote escaping, multiline CSV.
    9. *Multi-Tenant Boundary & Security Rules*: Cross-organization rejection, admin privilege protection, disabled account rejection.
- **Android Release Readiness Configuration**:
  - `AndroidManifest.xml`: Declared `<uses-permission android:name="android.permission.INTERNET"/>` and `<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>` for release networking.
  - `build.gradle.kts`: Java 17, JVM 17 target, Google Services plugin configured.
- **Verification & Test Coverage**:
  - Total automated test suite: **90 / 90 tests passing** (`flutter test`).
  - Static analysis: **0 issues found** across `lib` and `test` (`dart analyze lib test`).
  - Generated comprehensive documentation: [docs/RELEASE_READINESS.md](file:///d:/unity/docs/RELEASE_READINESS.md).
