/**
 * Phase 5 Seeding Script: Process Queries / Shop-floor Tickets.
 *
 * Runs via Node.js with Firebase Admin SDK against project `unity-c5e69`.
 *
 * Usage:
 *   node scripts/seed_phase5.js
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

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
const orgId = 'org_unity_001';

async function seedPhase5() {
  console.log(`\n=== Seeding Phase 5 Shop-floor Process Queries for ${orgId} ===`);

  const queries = [
    {
      id: 'query_2026_01',
      ticketNumber: 'TK-2026-101',
      title: 'Laser cutting head temperature spike',
      description: 'Chiller coolant flow rate dropped to 1.8 L/min causing optical head thermal alarm during continuous cut.',
      workOrder: 'WO-2026-101',
      stage: 'Laser Cutting',
      severity: 'high',
      status: 'in_review',
      reportedByName: 'Suresh Patel',
      reportedByUid: 'emp_suresh',
      resolutionNotes: 'Maintenance team flushed filtration cartridge; conducting trial cycle.',
    },
    {
      id: 'query_2026_02',
      ticketNumber: 'TK-2026-102',
      title: 'Drawing chamfer note dimension clarification',
      description: 'Customer print shows 45° chamfer on inner flange seam without tolerance callout.',
      workOrder: 'WO-2026-101',
      stage: 'Concept drawing/design',
      severity: 'low',
      status: 'resolved',
      reportedByName: 'Main Admin',
      reportedByUid: 'admin_bankar',
      resolutionNotes: 'Customer design office approved 45° x 1mm ±0.1mm standard break edge.',
    },
    {
      id: 'query_2026_03',
      ticketNumber: 'TK-2026-103',
      title: 'Axis Y calibration drift on CNC Lathe #2',
      description: 'Micrometer check indicates +0.06mm runout on spindle taper after tool change.',
      workOrder: 'WO-2026-101',
      stage: '3D precision machining',
      severity: 'critical',
      status: 'open',
      reportedByName: 'Ramesh Sharma',
      reportedByUid: 'emp_ramesh',
      resolutionNotes: '',
    },
  ];

  const batch = db.batch();

  for (const q of queries) {
    const docRef = db.collection(`organizations/${orgId}/processQueries`).doc(q.id);
    batch.set(docRef, {
      ticketNumber: q.ticketNumber,
      title: q.title,
      description: q.description,
      workOrder: q.workOrder,
      stage: q.stage,
      severity: q.severity,
      status: q.status,
      reportedByName: q.reportedByName,
      reportedByUid: q.reportedByUid,
      resolutionNotes: q.resolutionNotes,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`Prepared Ticket: [${q.ticketNumber}] ${q.title} (${q.severity.toUpperCase()} - ${q.status.toUpperCase()})`);
  }

  await batch.commit();
  console.log('\n>>> Successfully committed Phase 5 Process Queries in Firestore!');
}

seedPhase5().then(() => {
  console.log('Phase 5 seeding completed successfully.');
  process.exit(0);
}).catch(err => {
  console.error('Seeding error:', err);
  process.exit(1);
});
