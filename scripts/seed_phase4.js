/**
 * Phase 4 Seeding Script: Material Master, Balances, and Atomic Ledger Transactions.
 *
 * Runs via Node.js with Firebase Admin SDK against project `unity-c5e69`.
 *
 * Usage:
 *   node scripts/seed_phase4.js
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
const orgId = 'org_unity_001';

async function seedPhase4() {
  console.log(`\n=== Seeding Phase 4 Material Master & Ledger for ${orgId} ===`);

  const materials = [
    {
      id: 'mat_ss_316l',
      sku: 'MAT-SS-316L',
      name: 'Stainless Steel Sheet 316L (2mm)',
      category: 'SHEET_METAL',
      unit: 'KG',
      unitScale: 1000,
      minimumStock: 25000, // 25.000 KG
      reorderQuantity: 50000, // 50.000 KG
      currentQuantity: 120000, // 120.000 KG
      allocatedQuantity: 20000, // 20.000 KG allocated for WO-2026-101
      defaultLocation: 'Warehouse A - Bay 04',
      unitCost: 38000, // ₹380.00 / kg in paise
      notes: 'Marine-grade austenitic steel with 2% molybdenum',
      isActive: true,
    },
    {
      id: 'mat_al_6061',
      sku: 'MAT-AL-6061',
      name: 'Aluminum Alloy Bar 6061-T6 (Ø50mm)',
      category: 'RAW_MATERIAL',
      unit: 'KG',
      unitScale: 1000,
      minimumStock: 30000, // 30.000 KG
      reorderQuantity: 40000, // 40.000 KG
      currentQuantity: 18500, // 18.500 KG -> Below minimum! Triggers Low Stock Alert
      allocatedQuantity: 5000,
      defaultLocation: 'Warehouse A - Rack 12',
      unitCost: 26000, // ₹260.00 / kg in paise
      notes: 'Precipitation-hardened aluminum extrusion rod',
      isActive: true,
    },
    {
      id: 'mat_bolt_m8',
      sku: 'MAT-BOLT-M8',
      name: 'Hex Socket Head Cap Screw M8x30 Grade 12.9',
      category: 'FASTENER',
      unit: 'PCS',
      unitScale: 1,
      minimumStock: 200,
      reorderQuantity: 1000,
      currentQuantity: 1500,
      allocatedQuantity: 250,
      defaultLocation: 'Warehouse B - Bin 08',
      unitCost: 450, // ₹4.50 in paise
      notes: 'Black oxide high tensile industrial fasteners',
      isActive: true,
    },
    {
      id: 'mat_powder_ral',
      sku: 'MAT-POWDER-RAL7035',
      name: 'Pure Epoxy Polyester Powder RAL 7035 Light Grey',
      category: 'CONSUMABLE',
      unit: 'KG',
      unitScale: 1000,
      minimumStock: 15000,
      reorderQuantity: 25000,
      currentQuantity: 45000,
      allocatedQuantity: 0,
      defaultLocation: 'Chemical Storage - Vault 2',
      unitCost: 32000, // ₹320.00 / kg in paise
      notes: 'Outdoor UV resistant electrostatic powder coating',
      isActive: true,
    },
    {
      id: 'mat_seal_nbr',
      sku: 'MAT-SEAL-NBR70',
      name: 'NBR 70 Shore High Temperature O-Ring Kit',
      category: 'HARDWARE',
      unit: 'PCS',
      unitScale: 1,
      minimumStock: 50,
      reorderQuantity: 100,
      currentQuantity: 20, // 20 PCS -> Below minimum! Triggers Low Stock Alert
      allocatedQuantity: 15,
      defaultLocation: 'Warehouse B - Shelf 02',
      unitCost: 2500, // ₹25.00 in paise
      notes: 'Nitrile butadiene rubber seal rings for industrial valves',
      isActive: true,
    },
  ];

  const batch = db.batch();

  for (const mat of materials) {
    const matRef = db.doc(`organizations/${orgId}/materials/${mat.id}`);
    const balanceRef = db.doc(`organizations/${orgId}/inventoryBalances/${mat.id}_MAIN`);

    // 1. Material Master Doc
    batch.set(matRef, {
      sku: mat.sku,
      name: mat.name,
      category: mat.category,
      unit: mat.unit,
      unitScale: mat.unitScale,
      minimumStock: mat.minimumStock,
      reorderQuantity: mat.reorderQuantity,
      defaultLocation: mat.defaultLocation,
      unitCost: mat.unitCost,
      notes: mat.notes,
      quantity: mat.unitScale > 1 ? (mat.currentQuantity / mat.unitScale) : mat.currentQuantity,
      isActive: mat.isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // 2. Stock Balance Doc
    const available = Math.max(0, mat.currentQuantity - mat.allocatedQuantity);
    batch.set(balanceRef, {
      materialId: mat.id,
      materialSku: mat.sku,
      materialName: mat.name,
      locationId: 'MAIN',
      locationName: mat.defaultLocation,
      currentQuantity: mat.currentQuantity,
      allocatedQuantity: mat.allocatedQuantity,
      availableQuantity: available,
      unit: mat.unit,
      unitScale: mat.unitScale,
      minimumStock: mat.minimumStock,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // 3. Initial Receipt Ledger Transaction
    const txRef = db.collection(`organizations/${orgId}/inventoryTransactions`).doc(`tx_init_${mat.id}`);
    batch.set(txRef, {
      transactionNumber: `TX-GRN-2026-${mat.id.substring(4).toUpperCase()}`,
      type: 'RECEIPT',
      materialId: mat.id,
      materialSku: mat.sku,
      materialName: mat.name,
      locationId: 'MAIN',
      quantityDelta: mat.currentQuantity,
      balanceBefore: 0,
      balanceAfter: mat.currentQuantity,
      performedByUid: 'admin_bankar',
      performedByName: 'Main Admin',
      referenceNumber: 'GRN-2026-INITIAL',
      notes: 'Opening stock audit record',
      unit: mat.unit,
      unitScale: mat.unitScale,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`Prepared: [${mat.sku}] ${mat.name}`);
    console.log(`   Balance: ${mat.currentQuantity} base units | Available: ${available} | Min: ${mat.minimumStock}`);
  }

  // 4. Add a sample issue transaction against sample order WO-2026-101
  const sampleIssueTxRef = db.collection(`organizations/${orgId}/inventoryTransactions`).doc('tx_sample_issue_01');
  batch.set(sampleIssueTxRef, {
    transactionNumber: 'TX-ISSUE-2026-0042',
    type: 'ISSUE',
    materialId: 'mat_ss_316l',
    materialSku: 'MAT-SS-316L',
    materialName: 'Stainless Steel Sheet 316L (2mm)',
    locationId: 'MAIN',
    quantityDelta: -10000, // -10.000 KG
    balanceBefore: 130000,
    balanceAfter: 120000,
    orderId: 'WO-2026-101',
    processId: 'proc_01',
    performedByUid: 'emp_suresh',
    performedByName: 'Suresh Patel',
    referenceNumber: 'WO-2026-101',
    notes: 'Issued 10.000 KG to Laser Cutting stage',
    unit: 'KG',
    unitScale: 1000,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await batch.commit();
  console.log('\n>>> Successfully committed Phase 4 Materials, Balances, and Ledger Transactions in Firestore!');
}

seedPhase4().then(() => {
  console.log('Seeding finished successfully.');
  process.exit(0);
}).catch(err => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
