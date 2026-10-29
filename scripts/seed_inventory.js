const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(sa),
    projectId: sa.project_id || 'unity-c5e69',
  });
}

const db = admin.firestore();
const orgId = 'org_unity_001';

async function seed() {
  const materials = [
    {
      sku: 'RM-STEEL-316L',
      name: 'Stainless Steel Sheet 316L (2mm)',
      category: 'Raw Material',
      quantity: 120,
      minStockLevel: 50,
      unit: 'sheets',
      location: 'Warehouse A - Bay 04',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      sku: 'RM-ALUM-6061',
      name: 'Aluminum Alloy Bar 6061-T6',
      category: 'Raw Material',
      quantity: 18,
      minStockLevel: 25, // Below threshold -> triggers Low Stock Alert!
      unit: 'bars',
      location: 'Warehouse A - Rack 12',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      sku: 'FG-VALVE-DN50',
      name: 'Flanged Ball Valve DN50 PN16',
      category: 'Finished Good',
      quantity: 45,
      minStockLevel: 10,
      unit: 'pcs',
      location: 'Warehouse B - Shelf 02',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  console.log('Seeding initial materials for organization:', orgId);
  const collectionRef = db.collection(`organizations/${orgId}/materials`);

  for (const item of materials) {
    const docRef = collectionRef.doc();
    await docRef.set(item);
    console.log(`Added: [${item.sku}] ${item.name} (Qty: ${item.quantity} ${item.unit})`);
  }

  console.log('\nInventory successfully seeded in Cloud Firestore!');
}

seed().catch(console.error);
