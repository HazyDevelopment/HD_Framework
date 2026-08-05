# HD AntiCheat Dashboard

A small, self-contained web service for HD AntiCheat license holders: a
browser dashboard to tune detection settings and configure a Discord ban
webhook, plus the API `resources/[hd]/hd_anticheat` itself talks to.

This is **not** a FiveM resource — it's a plain Node.js app, meant to run
on a normal web host (a VPS, Railway, Render, whatever you already use),
separate from any FXServer. Nothing in `resources/` depends on it being
present; a buyer who never fills in `Config.License` in their
`config.lua` never has it in their setup at all.

## What it does

- Buyers log in with a **license key + secret** you issue them (not a
  self-serve signup — see "Minting a license" below).
- They can tune the same values as `hd_anticheat/config.lua`'s Movement/
  Damage/Scoring/Ban Message sections from a form instead of editing the
  file — their FXServer polls this service every ~10 minutes and applies
  whatever they've changed.
- They can point a Discord webhook at ban notifications, choosing which
  identity fields to include (Cfx.re account, Steam ID, Discord
  ID/username) and whether to attach a screenshot-burst gallery captured
  the instant the injection/mod-menu tripwire fires.
- A read-only ban log of everything their server has reported.

## What it deliberately doesn't do

No real video capture — FiveM gives scripts no API for that. "Screenshot
burst" is exactly what it sounds like: a few stills a fraction of a
second apart via the community `screenshot-basic` resource, uploaded
straight from the flagged player's own client to this service, then
posted to Discord as a multi-image embed. See `hd_anticheat/config.lua`'s
`Config.ScreenshotBurstCount` header for the full explanation — it's
worded the same way the rest of that file is honest about what it can
and can't detect.

## Requirements

- Node.js 18+
- A public HTTPS URL in production. Both Discord's servers (to fetch
  embed images) and buyers' game clients (to upload screenshots) need to
  reach this service — `localhost` only works for local testing.

## Setup

```bash
cd hd_anticheat_dashboard
npm install
cp .env.example .env
```

Edit `.env`:

- `PUBLIC_URL` — the real URL this service is reachable at once deployed
  (used to build screenshot upload URLs and the image URLs embedded in
  Discord posts).
- `SESSION_JWT_SECRET` / `UPLOAD_JWT_SECRET` — generate each with:
  ```bash
  node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
  ```
- `ADMIN_SECRET` — only needed if you want `POST /api/admin/licenses`
  available for scripting license creation (e.g. from a storefront
  webhook). Leave blank to disable that route and only ever mint
  licenses with the CLI script below.

Then:

```bash
npm start
```

Data lives in `data/dashboard.sqlite` (created automatically) and
uploaded screenshots in `uploads/` — both are gitignored. Put this
service behind a real process manager (pm2, systemd, Docker, etc.) and a
reverse proxy that terminates HTTPS for production use; `npm start` on
its own is fine for local testing only.

## Minting a license

```bash
npm run mint-license -- "Buyer name or server label"
```

Prints a license key (`HDAC-XXXX-XXXX-XXXX-XXXX`) and a secret. **The
secret is shown exactly once** — only its bcrypt hash is stored, so if
it's lost the only fix is minting a new license. Send both to the buyer;
they go in their `resources/[hd]/hd_anticheat/config.lua`:

```lua
Config.License = {
    Key = 'HDAC-XXXX-XXXX-XXXX-XXXX',
    Secret = 'the-secret-you-were-given',
    DashboardUrl = 'https://your-deployed-dashboard.example.com',
}
```

They then log into `https://your-deployed-dashboard.example.com` with
the same key + secret to configure their server.

## Optional: screenshot evidence

For the Discord embed's screenshot-burst gallery to work, a buyer also
needs the community `screenshot-basic` resource
(https://github.com/citizenfx/screenshot-basic) started on their
FXServer, above `hd_anticheat` in `server.cfg`:

```
ensure screenshot-basic
ensure hd_anticheat
```

It's intentionally not a hard `dependencies` entry in `hd_anticheat`'s
`fxmanifest.lua` — that would force every buyer to install it even if
they never touch the dashboard's webhook feature at all. Without it
(or with the "Attach screenshot burst" toggle off on the dashboard),
injection bans still work exactly the same, they just post without the
image gallery.

## API surface (for reference / future maintenance)

| Route | Auth | Used by |
|---|---|---|
| `POST /api/auth/login` | license key + secret in body | dashboard login |
| `GET/PUT /api/config` | browser session (JWT) | dashboard Server Config page |
| `GET /api/server/config` | `X-License-Key`/`X-License-Secret` headers | FXServer boot/refresh |
| `GET/PUT /api/webhook`, `POST /api/webhook/test` | browser session | dashboard Discord Webhook page |
| `GET /api/server/webhook-flags` | license headers | FXServer (screenshot toggle only — the webhook URL itself never leaves this service) |
| `GET /api/bans` | browser session | dashboard Ban Log page |
| `POST /api/server/bans` | license headers | FXServer, after every ban — triggers the Discord post |
| `POST /api/server/uploads/session` | license headers | FXServer, before an injection ban — mints a short-lived upload token |
| `POST /api/uploads/:licenseKey/:banToken?token=...` | scoped upload token (not the license secret) | the flagged player's own game client, via `screenshot-basic` |
| `POST /api/admin/licenses` | `X-Admin-Secret` header | you, optionally, if `ADMIN_SECRET` is set |
