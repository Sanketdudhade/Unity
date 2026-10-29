/**
 * Phase 2 Seeding Script: Products, 17-Stage Process Template, and Sample Work Order.
 *
 * Runs via Node.js with Firebase Admin SDK against project `unity-c5e69`.
 *
 * Usage:
 *   node scripts/seed_phase2.js
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// 1. Locate Service Account Credentials
function initAdmin() {
  const rootDir = path.resolve(__dirname, '..');
  const candidateFiles = fs.readdirSync(rootDir).filter(f => f.endsWith('.json') && f.includes('firebase-adminsdk'));
  let serviceAccountPath = candidateFiles.length > 0 ? path.join(rootDir, candidateFiles[0]) : null;

  if (!serviceAccountPath && fs.existsSync(path.join(rootDir, 'serviceAccountKey.json'))) {
    serviceAccountPath = path.join(rootDir, 'serviceAccountKey.json');
  }

  if (!serviceAccountPath) {
    console.error('Error: Could not find firebase-adminsdk json file in ' + rootDir);
    process.exit(1);
  }

  console.log(`Loading credentials from: ${serviceAccountPath}`);
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id || 'unity-c5e69'
  });
}

initAdmin();
const db = admin.firestore();

const ORG_ID = 'org_unity_001';

const PRODUCTS = [
  {
    id: 'prod_fb_001',
    partCode: 'PRD-FB-001',
    name: 'Flange Bushing 25mm',
    description: 'Precision brass flange bushing for motor mounting and vibration isolation',
    drawingNumber: 'DWG-FB-2026-A',
    revision: 'R2',
    unit: 'PCS',
    customerReference: 'Tata Motors - PO#8892',
    isActive: true,
  },
  {
    id: 'prod_ds_002',
    partCode: 'PRD-DS-002',
    name: 'Drive Shaft Precision 150mm',
    description: 'Case-hardened alloy steel drive shaft for linear actuator assemblies',
    drawingNumber: 'DWG-DS-2026-B',
    revision: 'R1',
    unit: 'PCS',
    customerReference: 'Mahindra Auto - PO#4401',
    isActive: true,
  },
  {
    id: 'prod_mb_003',
    partCode: 'PRD-MB-003',
    name: 'Stainless Steel Mounting Bracket',
    description: 'Laser cut & press braked SS304 mounting bracket with countersunk holes',
    drawingNumber: 'DWG-MB-2026-C',
    revision: 'R3',
    unit: 'PCS',
    customerReference: 'Bharat Heavy Electricals - PO#7819',
    isActive: true,
  },
];

const STAGES_17 = [
  { sequence: 1, name: 'RFQ received', defaultDurationHours: 4, dependsOnStepSequence: [], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 2, name: 'Feasibility study', defaultDurationHours: 8, dependsOnStepSequence: [1], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 3, name: 'Quotation', defaultDurationHours: 4, dependsOnStepSequence: [2], allowedRoles: ['ADMIN'] },
  { sequence: 4, name: 'Customer purchase order', defaultDurationHours: 4, dependsOnStepSequence: [3], allowedRoles: ['ADMIN'] },
  { sequence: 5, name: 'Concept drawing/design', defaultDurationHours: 16, dependsOnStepSequence: [4], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 6, name: '3D design/modeling', defaultDurationHours: 24, dependsOnStepSequence: [5], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 7, name: 'BOM release', defaultDurationHours: 8, dependsOnStepSequence: [6], allowedRoles: ['ADMIN'] },
  { sequence: 8, name: 'Material procurement', defaultDurationHours: 48, dependsOnStepSequence: [7], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 9, name: 'Detailed drawing release', defaultDurationHours: 16, dependsOnStepSequence: [8], allowedRoles: ['ADMIN'] },
  { sequence: 10, name: 'Optional Stage (Pre-machining QA)', defaultDurationHours: 8, isOptional: true, dependsOnStepSequence: [9], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 11, name: '3D precision machining', defaultDurationHours: 32, dependsOnStepSequence: [9], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 12, name: 'Heat treatment', defaultDurationHours: 24, dependsOnStepSequence: [11], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 13, name: '2D precision machining', defaultDurationHours: 16, dependsOnStepSequence: [12], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 14, name: 'Assembly', defaultDurationHours: 16, dependsOnStepSequence: [13], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 15, name: 'Trial', defaultDurationHours: 8, dependsOnStepSequence: [14], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 16, name: 'Inspection', defaultDurationHours: 8, dependsOnStepSequence: [15], allowedRoles: ['ADMIN', 'EMPLOYEE'] },
  { sequence: 17, name: 'Dispatch', defaultDurationHours: 4, dependsOnStepSequence: [16], allowedRoles: ['ADMIN'] },
];

async function seed() {
  console.log(`\n=== Seeding Phase 2 Canonical Data into Organization: ${ORG_ID} ===\n`);

  // 1. Seed Products
  console.log('1. Seeding Products Master...');
  for (const prod of PRODUCTS) {
    const prodRef = db.collection('organizations').doc(ORG_ID).collection('products').doc(prod.id);
    await prodRef.set({
      ...prod,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`   [✓] Product seeded: [${prod.partCode}] ${prod.name}`);
  }

  // 2. Seed 17-Stage Process Template
  console.log('\n2. Seeding 17-Stage Process Template & Subcollection Steps...');
  const templateId = 'tmpl_std_17';
  const templateRef = db.collection('organizations').doc(ORG_ID).collection('processTemplates').doc(templateId);

  await templateRef.set({
    name: 'Standard 17-Stage Manufacturing Flow',
    version: 1,
    stagesCount: 17,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const batch = db.batch();
  for (const step of STAGES_17) {
    const stepRef = templateRef.collection('steps').doc(`step_${step.sequence}`);
    batch.set(stepRef, {
      ...step,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await batch.commit();
  console.log(`   [✓] Template seeded: Standard 17-Stage Manufacturing Flow (17 steps written)`);

  // 3. Seed Sample Production Work Order with Snapshotted Stages
  console.log('\n3. Seeding Sample Work Order with Snapshotted Stages...');
  const orderId = 'order_wo_2026_101';
  const orderRef = db.collection('organizations').doc(ORG_ID).collection('productionOrders').doc(orderId);

  const orderData = {
    orderNumber: 'WO-2026-101',
    productName: 'Flange Bushing 25mm',
    targetQuantity: 250,
    completedQuantity: 0,
    unit: 'PCS',
    status: 'in_production',
    priority: 'high',
    totalProcesses: 17,
    completedProcesses: 2, // First 2 completed for realistic demonstration
    startDate: admin.firestore.Timestamp.now(),
    dueDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 24 * 60 * 60 * 1000)),
    notes: 'Urgent delivery for Tata Motors assembly line. Heat treatment batch cert required.',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await orderRef.set(orderData, { merge: true });

  // Snapshot processes subcollection for this order
  const orderProcessesBatch = db.batch();
  for (let i = 0; i < STAGES_17.length; i++) {
    const s = STAGES_17[i];
    const procRef = orderRef.collection('processes').doc(`proc_${s.sequence}`);

    // Set first 2 as COMPLETED, 3rd as IN_PROGRESS, rest NOT_STARTED
    let status = 'NOT_STARTED';
    let assignedName = 'Unassigned';
    let assignedUid = '';

    if (s.sequence === 1) {
      status = 'COMPLETED';
      assignedName = 'Production Lead';
    } else if (s.sequence === 2) {
      status = 'COMPLETED';
      assignedName = 'Chief Engineer';
    } else if (s.sequence === 3) {
      status = 'IN_PROGRESS';
      assignedName = 'Estimator / Admin';
    }

    orderProcessesBatch.set(procRef, {
      templateStepId: `step_${s.sequence}`,
      name: s.name,
      sequence: s.sequence,
      dependsOnStepSequence: s.dependsOnStepSequence,
      assignedEmployeeUid: assignedUid,
      assignedEmployeeName: assignedName,
      targetQty: 250,
      completedQty: status === 'COMPLETED' ? 250 : 0,
      status: status,
      dueAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 5 * 24 * 60 * 60 * 1000)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  await orderProcessesBatch.commit();
  console.log(`   [✓] Work Order WO-2026-101 created with 17 snapshotted stages (Steps 1 & 2 completed, Step 3 in progress).`);

  console.log('\n=== Phase 2 Seeding Completed Successfully! ===\n');
}

seed().catch(err => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
