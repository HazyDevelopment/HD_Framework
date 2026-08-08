// Hand-rolled minimal HS256 JWT — `jsonwebtoken` (the Node-version's
// choice) reaches into Node's `crypto` module internally, which doesn't
// exist in the Workers runtime. This only needs sign+verify with a
// fixed algorithm and an expiry claim, so a ~60-line implementation on
// top of `crypto.subtle` (Workers' native, spec-standard Web Crypto)
// covers it without pulling in a dependency.
//
// Unlike the Node version, secrets aren't read from `process.env` once
// at module load — Workers passes bindings/vars per-request via `env`,
// so every function here takes the secret as an explicit argument.

function base64UrlEncodeBytes(bytes) {
    let bin = '';
    for (const b of bytes) bin += String.fromCharCode(b);
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function base64UrlDecodeToBytes(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    const bin = atob(str);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
}
function base64UrlEncodeString(str) {
    return base64UrlEncodeBytes(new TextEncoder().encode(str));
}
function base64UrlDecodeToString(str) {
    return new TextDecoder().decode(base64UrlDecodeToBytes(str));
}

async function hmacKey(secret) {
    return crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

async function sign(payload, secret, expiresInSeconds) {
    const header = { alg: 'HS256', typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const body = { ...payload, iat: now, exp: now + expiresInSeconds };
    const signingInput = `${base64UrlEncodeString(JSON.stringify(header))}.${base64UrlEncodeString(JSON.stringify(body))}`;
    const key = await hmacKey(secret);
    const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signingInput));
    return `${signingInput}.${base64UrlEncodeBytes(new Uint8Array(sig))}`;
}

async function verify(token, secret) {
    const parts = (token || '').split('.');
    if (parts.length !== 3) return null;
    const [h, p, s] = parts;

    const key = await hmacKey(secret);
    const valid = await crypto.subtle.verify('HMAC', key, base64UrlDecodeToBytes(s), new TextEncoder().encode(`${h}.${p}`));
    if (!valid) return null;

    let payload;
    try {
        payload = JSON.parse(base64UrlDecodeToString(p));
    } catch {
        return null;
    }
    if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) return null;
    return payload;
}

export async function signSession(licenseKey, secret) {
    return sign({ lk: licenseKey }, secret, 12 * 3600);
}

export async function verifySession(token, secret) {
    const payload = await verify(token, secret);
    return payload ? payload.lk : null;
}

// Scoped to exactly one license + one ban-capture event, short-lived —
// handed to a game CLIENT (via the FXServer resource), never the
// buyer's real license secret. See hd_anticheat_dashboard's README for
// the full reasoning; identical design here, just ported.
export async function signUploadToken(licenseKey, banToken, secret) {
    return sign({ lk: licenseKey, bt: banToken }, secret, 90);
}

export async function verifyUploadToken(token, licenseKey, banToken, secret) {
    const payload = await verify(token, secret);
    return !!payload && payload.lk === licenseKey && payload.bt === banToken;
}
