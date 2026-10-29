const fs = require('fs');
const path = require('path');
const { GoogleAuth } = require('google-auth-library');

async function deployRules() {
  const rulesPath = path.join(__dirname, '..', 'firestore.rules');
  const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

  if (!fs.existsSync(serviceAccountPath)) {
    console.error('serviceAccountKey.json not found in scripts directory.');
    process.exit(1);
  }

  const rulesContent = fs.readFileSync(rulesPath, 'utf8');
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const projectId = serviceAccount.project_id || 'unity-c5e69';

  const auth = new GoogleAuth({
    keyFile: serviceAccountPath,
    scopes: ['https://www.googleapis.com/auth/firebase'],
  });

  const client = await auth.getClient();
  console.log(`Publishing firestore.rules to project ${projectId}...`);

  // 1. Create Ruleset
  const createUrl = `https://firebaserules.googleapis.com/v1/projects/${projectId}/rulesets`;
  const createRes = await client.request({
    url: createUrl,
    method: 'POST',
    data: {
      source: {
        files: [
          {
            name: 'firestore.rules',
            content: rulesContent,
          },
        ],
      },
    },
  });

  const rulesetName = createRes.data.name;
  console.log(`Created ruleset: ${rulesetName}`);

  // 2. Release Ruleset to cloud.firestore
  const releaseUrl = `https://firebaserules.googleapis.com/v1/projects/${projectId}/releases/cloud.firestore`;
  await client.request({
    url: releaseUrl,
    method: 'PATCH',
    data: {
      release: {
        name: `projects/${projectId}/releases/cloud.firestore`,
        rulesetName: rulesetName,
      },
    },
  });

  console.log('Successfully deployed and activated firestore.rules!');
}

deployRules().catch((err) => {
  console.error('Failed to deploy rules:', err.response?.data || err.message);
  process.exit(1);
});
