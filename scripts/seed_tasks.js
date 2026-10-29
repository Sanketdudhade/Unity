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

async function seedTasks() {
  const tasks = [
    {
      title: 'Laser Cutting: Stainless Steel Brackets',
      stage: 'Cutting & Forming',
      workOrder: 'WO-2026-081',
      assignedToUid: '4iDG734sS9XMVWzPLMrONUPwM542', // sanket
      assignedToName: 'sanket',
      status: 'in_progress',
      priority: 'high',
      scheduledDate: admin.firestore.Timestamp.now(),
      notes: 'Cutting 80x brackets from RM-STEEL-316L sheet',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      title: 'CNC Lathe Milling: Valve Core Shaft',
      stage: 'Machining',
      workOrder: 'WO-2026-082',
      assignedToUid: '4iDG734sS9XMVWzPLMrONUPwM542', // sanket
      assignedToName: 'sanket',
      status: 'pending',
      priority: 'urgent',
      scheduledDate: admin.firestore.Timestamp.now(),
      notes: 'Tolerance: +/- 0.02mm. Use coolant tank 2.',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      title: 'TIG Welding: Flanged Pressure Pipe Assembly',
      stage: 'Welding',
      workOrder: 'WO-2026-079',
      assignedToUid: '',
      assignedToName: 'Shop-Floor Team',
      status: 'paused',
      priority: 'normal',
      scheduledDate: admin.firestore.Timestamp.now(),
      notes: 'Paused waiting for pre-weld inspection sign-off.',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  console.log('Seeding initial manufacturing tasks for organization:', orgId);
  const collectionRef = db.collection(`organizations/${orgId}/process_tasks`);

  for (const t of tasks) {
    const docRef = collectionRef.doc();
    await docRef.set(t);
    console.log(`Added task: [${t.workOrder}] ${t.title} (${t.status})`);
  }

  console.log('\nTasks successfully seeded in Cloud Firestore!');
}

seedTasks().catch(console.error);
