// Usage: npm run mint-license -- "Buyer name or server label"
// Prints a license key + secret. The secret is shown exactly once here
// — only its bcrypt hash is stored, so if it's lost the only fix is
// minting a new license.

require('dotenv').config();
const db = require('../src/db');
const { generateLicenseKey, generateSecret, hashSecret } = require('../src/lib/crypto');

const ownerLabel = process.argv.slice(2).join(' ').slice(0, 200);

let licenseKey;
do {
    licenseKey = generateLicenseKey();
} while (db.prepare('SELECT 1 FROM licenses WHERE license_key = ?').get(licenseKey));

const secret = generateSecret();
db.prepare('INSERT INTO licenses (license_key, secret_hash, owner_label) VALUES (?, ?, ?)')
    .run(licenseKey, hashSecret(secret), ownerLabel);

console.log('');
console.log('New HD AntiCheat license minted.');
if (ownerLabel) console.log(`  Owner label: ${ownerLabel}`);
console.log(`  License key: ${licenseKey}`);
console.log(`  Secret:      ${secret}`);
console.log('');
console.log('Send both values to the buyer. Put them in their resources/[hd]/hd_anticheat/config.lua');
console.log('under Config.License.Key / Config.License.Secret. The secret cannot be shown again.');
console.log('');
