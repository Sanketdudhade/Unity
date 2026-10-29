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

async function seedProductionOrders() {
  const orders = [
    {
      orderNumber: 'WO-2026-081',
      productName: 'Stainless Steel Mounting Brackets 316L',
      targetQuantity: 500,
      completedQuantity: 180,
      unit: 'pcs',
      status: 'in_production',
      priority: 'high',
      startDate: admin.firestore.Timestamp.now(),
      dueDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 5 * 24 * 3600 * 1000)),
      customerName: 'AeroTech Systems',
      notes: 'Cutting & Forming stage currently active on Shop-Floor Terminal 1.',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      orderNumber: 'WO-2026-082',
      productName: 'Valve Core Shaft 25mm Precision Turned',
      targetQuantity: 250,
      completedQuantity: 40,
      unit: 'pcs',
      status: 'in_production',
      priority: 'urgent',
      startDate: admin.firestore.Timestamp.now(),
      dueDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3 * 24 * 3600 * 1000)),
      customerName: 'HydraFlow Global',
      notes: 'Milling on CNC Lathe 2. Coolant tank verified.',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      orderNumber: 'WO-2026-079',
      productName: 'Flanged Pressure Pipe Assembly DN50',
      targetQuantity: 80,
      completedQuantity: 0,
      unit: 'pcs',
      status: 'scheduled',
      priority: 'normal',
      startDate: admin.firestore.Timestamp.now(),
      dueDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 24 * 3600 * 1000)),
      customerName: 'EnergyWorks Ltd',
      notes: 'Scheduled for TIG welding following pre-inspection sign-off.',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  console.log('Seeding initial production work orders for organization:', orgId);
  const collectionRef = db.collection(`organizations/${orgId}/production_orders`);

  for (const o of orders) {
    const docRef = collectionRef.doc();
    await docRef.set(o);
    console.log(`Added work order: [${o.orderNumber}] ${o.productName} (${o.status})`);
  }

  console.log('\nProduction orders successfully seeded in Cloud Firestore!');
}

seedProductionOrders().catch(console.error);
