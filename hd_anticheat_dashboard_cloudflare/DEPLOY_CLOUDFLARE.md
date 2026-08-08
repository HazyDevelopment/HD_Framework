# Deploying to Cloudflare Workers (fivem-panel.co.uk)

This is the Cloudflare-native build of the HD AntiCheat dashboard — no
VPS, no Node process to keep alive yourself. Cloudflare runs the code,
stores the data (D1), stores screenshots (R2), and terminates TLS for
your custom domain, all as part of the same platform.

This is a **different codebase** from `hd_anticheat_dashboard/` (the
Node/Express version meant for a VPS) — different runtime, different
database, different storage. Use this folder for Cloudflare; that one
if you ever go back to a VPS. They don't share a database, so licenses
minted in one don't exist in the other.

## 0. Prerequisites

- A Cloudflare account with `fivem-panel.co.uk` added as a zone.
- Node.js on whatever machine you run these setup commands from (your
  own PC is fine — nothing here needs to run on a server you manage,
  that's the whole point).

```bash
cd hd_anticheat_dashboard_cloudflare
npm install
npx wrangler login
```

The last command opens a browser to authorize Wrangler (Cloudflare's
CLI) against your account.

## 1. Create the database and bucket

```bash
npx wrangler d1 create hd-anticheat-dashboard
```

This prints a `database_id` — copy it into `wrangler.toml`, replacing
`REPLACE_WITH_YOUR_D1_DATABASE_ID`.

```bash
npx wrangler r2 bucket create hd-anticheat-screenshots
```

## 2. Apply the schema

```bash
npm run d1:apply
```

Runs `schema.sql` against the real (remote) database. (`npm run
d1:apply:local` targets Wrangler's local dev database instead, if
you want to test with `wrangler dev` first — see step 6.)

## 3. Set secrets

Never put these in `wrangler.toml` — they go straight to Cloudflare:

```bash
npx wrangler secret put SESSION_JWT_SECRET
npx wrangler secret put UPLOAD_JWT_SECRET
```

Paste a long random value at each prompt, e.g. generate one with:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

`ADMIN_SECRET` is optional — only set it if you want
`POST /api/admin/licenses` reachable over HTTP:

```bash
npx wrangler secret put ADMIN_SECRET
```

## 4. Confirm `PUBLIC_URL`

`wrangler.toml`'s `[vars]` block already has
`PUBLIC_URL = "https://fivem-panel.co.uk"` — leave it as-is if that's
the domain you're adding in step 7, otherwise edit it to match.

## 5. Deploy

```bash
npm run deploy
```

This publishes to a `*.workers.dev` URL first (printed in the output)
— worth opening that URL and confirming the login page loads before
touching DNS at all.

## 6. (Optional) Test locally first

```bash
cp .dev.vars.example .dev.vars
# edit .dev.vars with the same two secrets from step 3
npm run d1:apply:local
npm run dev
```

`wrangler dev` runs the whole thing on your own machine against a local
D1/R2 emulation, so you can click through the login flow before it's
live anywhere.

## 7. Point your domain at it — no VPS-style DNS/cert work needed

This is the part that's genuinely simpler than the VPS path: Cloudflare
Workers custom domains handle DNS and the TLS certificate for you
automatically.

1. Cloudflare dashboard → **Workers & Pages** → click your
   `hd-anticheat-dashboard` worker → **Settings** → **Domains & Routes**
   → **Add** → **Custom Domain**.
2. Enter `fivem-panel.co.uk`, confirm.

Cloudflare creates the DNS record and issues the certificate itself —
there's no A record to hand-edit and no origin certificate to download
and install, unlike the VPS guide. Give it a minute or two to propagate,
then load `https://fivem-panel.co.uk` directly.

**If that domain currently resolves to something else** (see the note
from earlier — it was already serving a page identical to this
dashboard before you'd deployed anything), adding it as a custom domain
here will only succeed once nothing else on your account already claims
it. Sort out what that existing thing is first (Workers & Pages →
check every worker/Pages project for an existing route on this
hostname; DNS tab → check the current record) or this step will either
fail outright or silently take over a route you didn't mean to touch.

## 8. Mint a license

```bash
npm run mint-license -- "Your test server"
```

Prints a license key + secret. Log into `https://fivem-panel.co.uk`
with them to confirm the Server Config / Discord Webhook / Ban Log
pages all load and save correctly.

## 9. Point your FXServer at it

Same as the VPS version — in
`resources/[hd]/hd_anticheat/config.lua` on the actual game server:

```lua
Config.License = {
    Key = 'HDAC-XXXX-XXXX-XXXX-XXXX',
    Secret = 'the-secret-from-mint-license',
    DashboardUrl = 'https://fivem-panel.co.uk',
}
```

Restart the resource and check its console for
`[hd_anticheat] Dashboard config synced.`

## Redeploying after changes

```bash
npm run deploy
```

No service to restart, no server to reboot — Cloudflare swaps traffic
to the new version.

## Logs

```bash
npm run tail
```

Streams live requests/console output from the deployed Worker — the
Cloudflare equivalent of watching `logs/service-out.log` on the VPS
build.
