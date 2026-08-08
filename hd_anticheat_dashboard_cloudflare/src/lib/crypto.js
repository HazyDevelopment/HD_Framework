// Web Crypto only — no bcryptjs, no Node's `crypto` module. Neither
// runs the way you'd expect in Workers: bcryptjs is a pure-JS loop that
// typically costs 60-300ms of CPU per hash, well over the Workers Free
// plan's 10ms-per-request CPU budget, and Node's native `crypto` module
// isn't the runtime here at all. PBKDF2 via `crypto.subtle` is
// implemented natively (not interpreted JS), so even a high iteration
// count costs low-single-digit milliseconds — genuinely a better fit
// for this runtime, not just a workaround.
//
// This file is imported both by the Worker (src/index.js's route tree)
// and by scripts/mint-license.js running under plain Node — it only
// touches Web Crypto APIs (`crypto.subtle`, `crypto.getRandomValues`,
// `TextEncoder`, `btoa`/`atob`) so it runs unmodified in both.

// HDAC-XXXX-XXXX-XXXX-XXXX — unambiguous charset (no 0/O/1/I) so a
// mistyped key fails fast instead of silently landing on someone else's
// license.
const KEY_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
// Cloudflare Workers' PBKDF2 implementation caps out at 100,000
// iterations — crypto.subtle.deriveBits throws above that here, unlike
// Node/browsers which allow much higher counts. This is the max this
// runtime actually supports, not an arbitrary choice.
const PBKDF2_ITERATIONS = 100000;

function randomSegment(len) {
    const bytes = crypto.getRandomValues(new Uint8Array(len));
    let out = '';
    for (let i = 0; i < len; i++) out += KEY_CHARSET[bytes[i] % KEY_CHARSET.length];
    return out;
}

export function generateLicenseKey() {
    return `HDAC-${randomSegment(4)}-${randomSegment(4)}-${randomSegment(4)}-${randomSegment(4)}`;
}

// The secret is shown to the buyer exactly once at mint time — only its
// PBKDF2 hash is ever persisted, same trust model as a password.
export function generateSecret() {
    return base64UrlEncode(crypto.getRandomValues(new Uint8Array(24)));
}

function base64UrlEncode(bytes) {
    let bin = '';
    for (const b of bytes) bin += String.fromCharCode(b);
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    const bin = atob(str);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
}

async function pbkdf2(secret, salt, iterations) {
    const keyMaterial = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), 'PBKDF2', false, ['deriveBits']);
    const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations, hash: 'SHA-256' }, keyMaterial, 256);
    return new Uint8Array(bits);
}

// Self-describing stored format (algorithm$iterations$salt$hash) so the
// iteration count can be raised later without invalidating hashes
// minted under the old count.
export async function hashSecret(secret) {
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const hash = await pbkdf2(secret, salt, PBKDF2_ITERATIONS);
    return `pbkdf2$${PBKDF2_ITERATIONS}$${base64UrlEncode(salt)}$${base64UrlEncode(hash)}`;
}

export async function verifySecret(secret, stored) {
    const parts = (stored || '').split('$');
    if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
    const iterations = parseInt(parts[1], 10);
    const salt = base64UrlDecode(parts[2]);
    const expected = base64UrlDecode(parts[3]);
    const actual = await pbkdf2(secret, salt, iterations);

    if (actual.length !== expected.length) return false;
    let diff = 0; // constant-time compare — don't leak how many leading bytes matched
    for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ expected[i];
    return diff === 0;
}
