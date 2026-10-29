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

async function seedQueries() {
  const queries = [
    {
      ticketNumber: 'TK-2026-101',
      title: 'Hydraulic Coolant Pressure Fluctuation on CNC Lathe 2',
      description: 'Coolant flow dropped below 3.5 bar during rough turning cycle. Potential particulate filter clogging.',
      workOrder: 'WO-2026-082',
      stage: 'CNC Machining',
      severity: 'high',
      status: 'in_review',
      reportedByName: 'sanket',
      reportedByUid: '4iDG734sS9XMVWzPLMrONUPwM542',
      resolutionNotes: '',
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      ticketNumber: 'TK-2026-098',
      title: 'Dimensional Tolerance Check on Stainless Steel Sheet 316L',
      description: 'Batch sheet thickness measured 1.94mm instead of nominal 2.00mm. Need QA sign-off before laser cut.',
      workOrder: 'WO-2026-081',
      stage: 'Cutting & Forming',
      severity: 'medium',
      status: 'resolved',
      reportedByName: 'sanket',
      reportedByUid: '4iDG734sS9XMVWzPLMrONUPwM542',
      resolutionNotes: 'Tolerance within ISO 2768-m (+/- 0.08mm). Cleared for laser cutting.',
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 24 * 3600 * 1000)),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ];

  console.log('Seeding initial shop-floor queries for organization:', orgId);
  const collectionRef = db.collection(`organizations/${orgId}/process_queries`);

  for (const q of queries) {
    const docRef = collectionRef.doc();
    await docRef.set(q);
    console.log(`Added ticket: [${q.ticketNumber}] ${q.title} (${q.status})`);
  }

  console.log('\nShop-floor queries successfully seeded in Cloud Firestore!');
}

seedQueries().catch(console.error);
