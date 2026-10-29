/**
 * Secure User Provisioning Script using Firebase Admin SDK.
 *
 * This script runs in a trusted server environment to:
 * 1. Create or retrieve a Firebase Authentication user.
 * 2. Assign trusted custom claims: { role: 'ADMIN' | 'EMPLOYEE', organizationId: string }.
 * 3. Synchronize the corresponding Firestore document in `users/{uid}`.
 *
 * Usage:
 *   node provision_user.js --email="admin@example.com" --password="Secr3tPassword!" --role="ADMIN" --name="System Administrator" --org="org_unity_001"
 *
 * Environment Options:
 *   GOOGLE_APPLICATION_CREDENTIALS: Path to serviceAccountKey.json (for live Firebase project)
 *   FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099" (for local emulator)
 *   FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" (for local emulator)
 */

const admin = require('firebase-admin');

// Parse CLI flags (--key=value)
function parseArgs() {
  const args = {};
  process.argv.slice(2).forEach((arg) => {
    if (arg.startsWith('--')) {
      const [key, value] = arg.slice(2).split('=');
      args[key] = value ? value.replace(/^"(.*)"$/, '$1') : true;
    }
  });
  return args;
}

async function main() {
  const args = parseArgs();

  const email = args.email || process.env.USER_EMAIL;
  const password = args.password || process.env.USER_PASSWORD;
  const role = (args.role || process.env.USER_ROLE || '').toUpperCase();
  const fullName = args.name || process.env.USER_FULL_NAME || 'System User';
  const organizationId = args.org || process.env.USER_ORG_ID || 'org_unity_001';

  if (!email || !password || !role) {
    console.error('Error: Missing required arguments.');
    console.log('\nUsage:');
    console.log('  node provision_user.js --email="user@org.com" --password="Password123!" --role="ADMIN|EMPLOYEE" --name="Full Name" --org="org_001"\n');
    process.exit(1);
  }

  if (role !== 'ADMIN' && role !== 'EMPLOYEE') {
    console.error(`Error: Invalid role "${role}". Supported roles are ADMIN or EMPLOYEE.`);
    process.exit(1);
  }

  // Initialize Firebase Admin SDK
  if (!admin.apps.length) {
    const fs = require('fs');
    const path = require('path');

    if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
      console.log('Connecting to Firebase Local Emulator...');
      admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'unity-c5e69' });
    } else {
      // Find service account key
      let keyPath = args.key || process.env.GOOGLE_APPLICATION_CREDENTIALS;
      
      const candidatePaths = [
        keyPath,
        path.join(__dirname, 'serviceAccountKey.json'),
        path.join(__dirname, '..', 'serviceAccountKey.json'),
      ];

      // Also search for any *serviceAccount*.json file in scripts/
      try {
        const files = fs.readdirSync(__dirname);
        const autoKey = files.find(f => f.toLowerCase().includes('serviceaccount') && f.endsWith('.json'));
        if (autoKey) candidatePaths.push(path.join(__dirname, autoKey));
      } catch (_) {}

      const resolvedPath = candidatePaths.find(p => p && fs.existsSync(p));

      if (resolvedPath) {
        console.log(`Using Service Account credentials from: ${resolvedPath}`);
        const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: serviceAccount.project_id || 'unity-c5e69'
        });
      } else {
        console.error('\n[AUTHENTICATION REQUIRED]');
        console.error('Firebase Admin SDK needs a Service Account Key to set custom claims (role: ADMIN/EMPLOYEE).\n');
        console.error('Quick 3-step setup:');
        console.error('1. Open Firebase Console Service Accounts:');
        console.error('   https://console.firebase.google.com/project/unity-c5e69/settings/serviceaccounts/adminsdk');
        console.error('2. Click "Generate new private key" and download the JSON file.');
        console.error('3. Move or save the file as:');
        console.error('   D:\\unity\\scripts\\serviceAccountKey.json');
        console.error('\nThen re-run your command:');
        console.error(`   node provision_user.js --email="${email}" --password="${password}" --role="${role}" --name="${fullName}" --org="${organizationId}"\n`);
        process.exit(1);
      }
    }
  }

  const auth = admin.auth();
  const db = admin.firestore();

  console.log(`\nProvisioning account: ${email}`);
  console.log(`Role: ${role} | Organization: ${organizationId}`);

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`Found existing user with UID: ${userRecord.uid}`);
    if (password) {
      await auth.updateUser(userRecord.uid, { password, displayName: fullName });
      console.log('Updated existing password and display name.');
    }
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        email,
        password,
        displayName: fullName,
        emailVerified: true,
      });
      console.log(`Created new Firebase user with UID: ${userRecord.uid}`);
    } else {
      throw error;
    }
  }

  // Set trusted custom claims (Role and Organization)
  const customClaims = {
    role: role,
    organizationId: organizationId,
  };
  await auth.setCustomUserClaims(userRecord.uid, customClaims);
  console.log('Successfully set custom claims on security token:', customClaims);

  // Synchronize Firestore user document (`users/{uid}`)
  const userDocRef = db.collection('users').doc(userRecord.uid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  await userDocRef.set(
    {
      uid: userRecord.uid,
      fullName: fullName,
      email: email.toLowerCase(),
      role: role,
      organizationId: organizationId,
      isActive: true,
      updatedAt: now,
      createdAt: now,
    },
    { merge: true }
  );

  console.log(`Successfully synced user profile to Firestore: users/${userRecord.uid}`);

  // Synchronize Employee directory document (`organizations/{orgId}/employees/{uid}`)
  const empDocRef = db.collection(`organizations/${organizationId}/employees`).doc(userRecord.uid);
  await empDocRef.set(
    {
      uid: userRecord.uid,
      employeeCode: args.code || `EMP-${userRecord.uid.substring(0, 5).toUpperCase()}`,
      fullName: fullName,
      email: email.toLowerCase(),
      phone: args.phone || '',
      department: args.dept || (role === 'ADMIN' ? 'Management' : 'Shop-Floor Operations'),
      role: role,
      organizationId: organizationId,
      isActive: true,
      updatedAt: now,
      createdAt: now,
    },
    { merge: true }
  );
  console.log(`Successfully synced employee profile: organizations/${organizationId}/employees/${userRecord.uid}`);
  console.log('\n[SUCCESS] Account provisioned and ready for sign in.\n');
}

main().catch((err) => {
  if (err.message && err.message.includes('configuration corresponding to the provided identifier')) {
    console.error('\n[FIREBASE AUTHENTICATION NOT ACTIVATED YET]');
    console.error('Firebase Authentication needs to be turned on in your project console:\n');
    console.error('1. Open: https://console.firebase.google.com/project/unity-c5e69/authentication');
    console.error('2. Click "Get started".');
    console.error('3. Select "Email/Password" under Sign-in providers, toggle "Enable", and click "Save".');
    console.error('\nOnce enabled, re-run this provisioning command.\n');
  } else {
    console.error('\n[FAILED] Provisioning error:', err.message);
  }
  process.exit(1);
});

