/**
 * Synchronizes Firebase Auth custom claims (role and organizationId)
 * with user documents stored in Firestore (`users/{uid}`).
 *
 * Usage:
 *   node scripts/sync_claims.js
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function initAdmin() {
  const rootDir = path.resolve(__dirname, '..');
  const candidateFiles = fs.readdirSync(rootDir).filter(f => f.endsWith('.json') && f.includes('firebase-adminsdk'));
  let serviceAccountPath = candidateFiles.length > 0 ? path.join(rootDir, candidateFiles[0]) : null;

  if (!serviceAccountPath && fs.existsSync(path.join(__dirname, 'serviceAccountKey.json'))) {
    serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
  }

  if (!serviceAccountPath) {
    console.error('Error: Could not find firebase-adminsdk / serviceAccountKey.json');
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'unity-c5e69',
    });
  }
}

initAdmin();
const auth = admin.auth();
const db = admin.firestore();

async function syncAllClaims() {
  console.log('=== Synchronizing Firebase Auth Custom Claims with Firestore Profiles ===\n');

  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} user profiles in Firestore users collection.`);

  let updatedCount = 0;
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const uid = doc.id;
    const role = (data.role || '').toString().trim().toUpperCase();
    const organizationId = (data.organizationId || '').toString().trim();

    if (!role || !organizationId) {
      console.warn(`[SKIP] User ${uid} (${data.email}) missing role or organizationId.`);
      continue;
    }

    try {
      await auth.setCustomUserClaims(uid, {
        role: role,
        organizationId: organizationId,
      });

      console.log(`[OK] Updated claims for ${data.email || uid} -> { role: '${role}', organizationId: '${organizationId}' }`);
      updatedCount++;
    } catch (err) {
      console.error(`[ERROR] Failed to set claims for ${uid}:`, err.message);
    }
  }

  console.log(`\nSuccessfully synchronized claims for ${updatedCount} users.`);
}

syncAllClaims()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal sync error:', err);
    process.exit(1);
  });
