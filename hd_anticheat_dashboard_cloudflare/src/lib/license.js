// Shared between the Worker (src/routes/*) and scripts/mint-license.js
// running under plain Node — pure JS/Date, same portability rule
// crypto.js already documents for this codebase.

export const PLANS = {
    monthly: { label: '1 Month', days: 30 },
    quarterly: { label: '3 Months', days: 90 },
    lifetime: { label: 'Lifetime', days: null }, // null days = never expires
};

export function isValidPlan(plan) {
    return Object.prototype.hasOwnProperty.call(PLANS, plan);
}

// Returns an ISO datetime string, or null for 'lifetime' (never expires)
// — callers store this straight into licenses.expires_at, which is
// nullable for exactly this reason.
export function computeExpiresAt(plan, fromDate = new Date()) {
    const def = PLANS[plan];
    if (!def || def.days === null) return null;
    const expires = new Date(fromDate.getTime());
    expires.setUTCDate(expires.getUTCDate() + def.days);
    return expires.toISOString();
}

// A license with expires_at === null never expires. Otherwise expired
// the instant `now` passes it — same check used for both the buyer's
// FXServer and their browser login (middleware/auth.js), so there's
// exactly one place this comparison is written.
export function isExpired(expiresAt, now = new Date()) {
    if (!expiresAt) return false;
    return new Date(expiresAt).getTime() <= now.getTime();
}

export function daysRemaining(expiresAt, now = new Date()) {
    if (!expiresAt) return null; // lifetime
    const ms = new Date(expiresAt).getTime() - now.getTime();
    return Math.max(0, Math.ceil(ms / 86400000));
}

// One shared message string so a buyer sees the exact same wording
// whether they're blocked at login (routes/auth.js), on an already-open
// dashboard tab (middleware/auth.js's requireBrowserAuth), or their
// FXServer console (requireServerAuth, read by
// hd_anticheat/server/dashboard.lua) — never a generic "unauthorized".
export const EXPIRED_MESSAGE = 'This license has expired. Renew it to keep using the dashboard and remote config sync.';

// Server-side only (requireServerAuth binds/checks discord_guild_id;
// there's no equivalent browser-login check — a human logging in
// doesn't carry a Discord guild ID at all).
export const GUILD_MISMATCH_MESSAGE = 'This license is bound to a different Discord server. Contact whoever issued it if this server is a legitimate migration.';
