# HD AntiCheat Dashboard — Cloudflare Workers build

Same dashboard as `hd_anticheat_dashboard/` (license-gated Server
Config / Discord Webhook / Ban Log pages for HD AntiCheat buyers), built
for Cloudflare's platform instead of a VPS:

| | Node/VPS build (`hd_anticheat_dashboard/`) | This build |
|---|---|---|
| Runtime | Node.js + Express | Cloudflare Workers (Hono) |
| Database | SQLite file (`better-sqlite3`) | Cloudflare D1 |
| Screenshot storage | Local disk | Cloudflare R2 |
| Password hashing | bcrypt | PBKDF2 via Web Crypto |
| Where it runs | A server you manage (VPS) | Cloudflare's edge |
| TLS / custom domain | You configure it (see that build's `DEPLOY_WINDOWS.md`) | Cloudflare Workers custom domains — automatic |

These are two independent codebases with two independent databases —
licenses minted in one don't exist in the other. Pick one deployment
target; they're not meant to run side by side against the same
domain.

**Full setup**: see [DEPLOY_CLOUDFLARE.md](DEPLOY_CLOUDFLARE.md).

## Why the internals differ from the Node build

Cloudflare Workers isn't Node.js — it's a V8 isolate runtime with no
filesystem and no native binary modules, so anything that assumed a
local disk or a native addon needed a real replacement, not a shim:

- **`better-sqlite3` → Cloudflare D1.** D1 is SQLite under the hood, so
  `schema.sql` is reused unchanged; only the query API differs
  (`db.prepare(...).bind(...).first()/.all()/.run()` instead of
  `better-sqlite3`'s synchronous calls).
- **Local disk uploads (`multer`) → Cloudflare R2.** Screenshot bursts
  from `screenshot-basic` now land in an R2 bucket; `GET /uploads/*`
  in `src/index.js` streams them back out, replacing the Node build's
  `express.static('/uploads', ...)`.
- **`bcryptjs` → PBKDF2 via `crypto.subtle`.** Not just a swap for
  compatibility — bcryptjs is a pure-JS loop costing 60-300ms of CPU
  per hash, well over the Workers Free plan's 10ms-per-request budget.
  PBKDF2 through Web Crypto is implemented natively, so it's both
  correct here and fast. See `src/lib/crypto.js`.
- **`jsonwebtoken` → a ~60-line hand-rolled HS256 implementation.**
  `jsonwebtoken` reaches into Node's `crypto` module internally, which
  doesn't exist in Workers. See `src/lib/jwt.js`.
- **Express → Hono.** Workers doesn't run Node's `http` module Express
  is built on; Hono is a Workers-native router with deliberately
  Express-like syntax, so the route logic itself ported over almost
  unchanged.

The API surface (every `/api/...` path) and the entire `public/`
frontend are identical to the Node build — `hd_anticheat`'s Lua side
and the dashboard's own JS don't know or care which backend they're
talking to.
