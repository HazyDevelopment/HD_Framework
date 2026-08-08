// Usage: npm run mint-license -- --plan=monthly "Buyer name or server label"
//   --plan=monthly    1 month  (30 days)
//   --plan=quarterly  3 months (90 days)
//   --plan=lifetime   never expires — this is also the default if
//                     --plan is omitted, matching every license minted
//                     before plans existed
//
// Runs locally under plain Node (not in the Worker) — computes a
// license key + secret using the exact same PBKDF2 hashing
// src/lib/crypto.js uses inside the Worker (that file only touches Web
// Crypto APIs, so it runs unmodified here too), then inserts the row
// into the REMOTE D1 database via `wrangler d1 execute`. The secret is
// shown exactly once — only its hash is stored, so if it's lost the
// only fix is minting a new license.
//
// Requires: `wrangler login` already done once, and the database_id in
// ../wrangler.toml filled in (see DEPLOY_CLOUDFLARE.md).

import { execSync } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { generateLicenseKey, generateSecret, hashSecret } from '../src/lib/crypto.js';
import { PLANS, isValidPlan, computeExpiresAt } from '../src/lib/license.js';

// Node < 19 doesn't expose Web Crypto as a global by default.
if (!globalThis.crypto) {
    globalThis.crypto = (await import('node:crypto')).webcrypto;
}

const DATABASE_NAME = process.env.D1_DATABASE_NAME || 'hd-anticheat-dashboard';

const rawArgs = process.argv.slice(2);
const planArg = rawArgs.find((a) => a.startsWith('--plan='));
const plan = planArg ? planArg.slice('--plan='.length).trim() : 'lifetime';
if (!isValidPlan(plan)) {
    console.error(`Unknown --plan "${plan}". Valid values: ${Object.keys(PLANS).join(', ')}`);
    process.exit(1);
}
const ownerLabel = rawArgs.filter((a) => a !== planArg).join(' ').slice(0, 200);

function sqlEscape(str) {
    return String(str).replace(/'/g, "''");
}

const licenseKey = generateLicenseKey();
const secret = generateSecret();
const secretHash = await hashSecret(secret);
const expiresAt = computeExpiresAt(plan);

const sql = `INSERT INTO licenses (license_key, secret_hash, owner_label, plan, expires_at) VALUES ('${sqlEscape(licenseKey)}', '${sqlEscape(secretHash)}', '${sqlEscape(ownerLabel)}', '${sqlEscape(plan)}', ${expiresAt ? `'${sqlEscape(expiresAt)}'` : 'NULL'});\n`;

// Written to a temp file rather than passed inline so this doesn't
// depend on cmd.exe/PowerShell/bash all quoting shell arguments the
// same way — a plain `wrangler d1 execute --file=...` sidesteps that
// entirely.
const tmpFile = join(tmpdir(), `hdac-mint-${Date.now()}.sql`);
writeFileSync(tmpFile, sql, 'utf8');

try {
    execSync(`npx wrangler d1 execute ${DATABASE_NAME} --remote --file="${tmpFile}"`, { stdio: 'inherit' });
} finally {
    unlinkSync(tmpFile);
}

console.log('');
console.log('New HD AntiCheat license minted.');
if (ownerLabel) console.log(`  Owner label: ${ownerLabel}`);
console.log(`  Plan:        ${PLANS[plan].label}`);
console.log(`  Expires:     ${expiresAt || 'never'}`);
console.log(`  License key: ${licenseKey}`);
console.log(`  Secret:      ${secret}`);
console.log('');
console.log('Send both values to the buyer. Put them in their resources/[hd]/hd_anticheat/config.lua');
console.log('under Config.License.Key / Config.License.Secret. The secret cannot be shown again.');
console.log('(If this failed with a UNIQUE constraint error, that\'s a 1-in-astronomical key collision — just rerun.)');
console.log('');
