# hd_anticheat

Server-authoritative exploit detection with a full `/anticheat` staff
panel — no client-side "anticheat" logic anywhere (a check running on
the client is one a cheat can just patch out), every real decision
happens server-side against ground truth the server already owns
(`GetEntityCoords`, `GetEntityHealth`), never anything the client
claims. What started as a detections-and-overview panel has grown into
the server's general staff console: a player roster, world tools, a
live monitoring grid with genuine spectate video, an admin-only chat
channel, and a player report queue, plus an optional licensed web
dashboard integration.

## How it works

### Detection (`server/detection.lua`, `server/main.lua`)

- **Three independent checks**, all skipping `IsExemptAdmin` and
  anyone still inside a movement grace window:
  - **Injection/mod-menu tripwire.** `Config.InjectionTripwireEvents`
    is a curated list of exact net-event names (ESX/QBCore-style
    events — HD_Framework is deliberately standalone and registers
    none of them, so a real player here should *never* fire one).
    FiveM's event system has no wildcard/prefix listener, so this can
    only ever be an exact-name list, grown from specific known
    evidence, never a true pattern catch-all. Any hit is instant and
    *permanent* — not run through the suspicion-score system at all.
  - **Movement** (`Config.CheckIntervalMs` sampling): a single-interval
    jump over `Config.TeleportDistance` flags `teleportHack` regardless
    of vehicle state; on-foot horizontal speed over
    `Config.MaxOnFootSpeed` flags `speedHack` (vehicles are never
    speed-checked — tuned handling, ziptires, ramps make a flat cap
    unsafe). Sampling only starts once
    `hd_anticheat:server:playerLoaded` has fired for that player at
    least once, so the very first sample after connect never reads the
    pre-spawn-ped → real-saved-position jump as a teleport hack.
  - **Invincibility.** On `CEventNetworkEntityDamage`, records health
    immediately, compares again after `Config.DamageCheckDelayMs` —
    unchanged-or-higher health after a real hit flags `invincibility`.
    Documented as *not* directly detecting noclip (FiveM has no
    server-side "is collision off" native) — it catches noclip's
    consequence instead: a position/damage state no legitimate
    movement could produce.
- **`hd_anticheat:server:playerLoaded` is replay-guarded**
  (`LastPlayerLoadedAt` in `server/main.lua`): this event is fired by
  the player's own client, which means an injected script on that same
  client could fire it directly too, with no admin permission gate at
  all. Without a cap, spamming it would keep `MovementGrace` refreshed
  forever, making the movement checks permanently blind for that
  player — capped to once per `Config.SpawnGraceMs`, which costs a
  legitimate client nothing.
- **Suspicion scoring, not instant-ban-on-first-hit**: every
  non-injection flag adds `Config.Points[kind]` to a per-player score
  that decays at `Config.ScoreDecayPerMinute`; crossing
  `Config.BanThreshold` triggers an automatic ban. Lets a one-off false
  positive (a legitimate teleport landing right as a check fires) decay
  away instead of ending someone's session.
- **One ban list for the whole framework.** `BanPlayer` inserts into
  `hd_admin`'s own `hd_admin_bans` table (not a second, competing list)
  and drops the player with `Config.BanMessage` plus whatever
  Discord/Cfx.re identity was captured at that exact moment.
- **`exports['hd_anticheat']:GrantMovementGrace(src, ms?)`** lets any
  resource that legitimately teleports a player (hd_housing's
  enter/exit, hd_admin's/this resource's own teleport tools) suppress
  movement checks around that jump.

### Admin bypass

`IsExemptAdmin(src)` calls `exports['hd_admin']:IsAdmin(src)` (the same
Discord-role check hd_admin's own panel gates on), cached 15s
per-player. A verified admin is simply outside every check this
resource runs — covers noclip, spectate, godmode, and anything else
hd_admin's panel does, without hd_anticheat needing to know which tool
is active.

### The `/anticheat` panel — seven tabs, one Discord-role gate

Every NUI action re-checks `IsExemptAdmin(src)` server-side
independently (and, where relevant, `IsOnDuty`) — the panel only
opening for admins client-side is a UX nicety.

- **Overview** — live, score-sorted roster of connected players with
  suspicion score, clear-score and manual-ban actions (same as the
  original build). Also shows a small license status line sourced from
  `LicenseStatus` (`server/dashboard.lua`) when a dashboard license is
  configured — purely informational, nothing in detection/ban logic
  reads it.
- **Detections** — the last `Config.LogLimit` flags, newest first.
- **Players** (`server/players.lua`) — a general staff roster distinct
  from Overview's suspicion-scored list: every connected player with
  their actual Cfx.re account name (`GetPlayerName`) alongside their
  in-character name, for any reason, not just an anticheat flag. Kick,
  teleport-to (moves the *admin* to the target, never the reverse —
  the admin's already exempt, so there's nothing for detection to
  misread), and ban all reuse `server/main.lua`'s same `BanPlayer` —
  one ban path, not two.
- **World** (`server/world.lua`) — deliberately scoped narrower than
  hd_admin's own World tab (weather/time live there instead): a
  **World Reset** broadcasts `ClearAreaOfObjects` to every connected
  client around their own position (`Config.WorldResetRadius`) — FiveM
  has no native that resets "the whole map" at once, so each client
  tidies up wherever it actually is, clearing stray/broken dynamic
  props. And a server-wide **announcement** banner
  (`Config.AnnouncementBannerMs`) that also always lands in every
  player's chat, so it isn't lost even with the panel closed.
- **Monitor** (`server/monitor.lua`) — be precise about what this
  actually is: the grid of small "screens" is live position/heading
  telemetry pulled from `GetEntityCoords` every `Config.MonitorIntervalMs`
  while at least one admin has the tab open (nothing is sent while
  unwatched), **not** a video feed — FiveM has no native that streams
  one client's rendered frame to another's NUI, and rendering dozens of
  simultaneous in-game cameras isn't something the engine supports. The
  one genuinely live-video feature is the **big screen**: it reuses
  hd_admin's own tested spectate camera wholesale
  (`hd_admin:server:startSpectate`/`stopSpectate`) and renders it
  through a transparent cutout in the panel — real game-world rendering
  passing through, not a simulation of one.
- **Reports** (`server/reports.lua`) — `/acreport <message>`, open to
  *any* player, not just admins: the direct line a player has after
  watching someone do something impossible. Rate-limited per player by
  `Config.ReportCooldownMs` (doesn't limit different players reporting
  the same incident). Captures the reporter's exact coordinates at
  submit time (they may have disconnected by the time an admin gets to
  it) and their citizenid/name. Persisted to `hd_anticheat_reports`
  (loaded back into memory on resource start) and pushed live to any
  admin with the panel open, plus toast-notified to every on-duty admin
  even with the panel closed. Admins can mark a report resolved.
- **Admin Chat** (`server/duty.lua`) — gated on a separate **on-duty**
  flag (`/acduty` or the sidebar toggle in the NUI), not just being an
  admin: `IsOnDuty` decides who the chat channel is shown to and
  broadcast to, so a verified admin who's never gone on duty is simply
  not part of it, same as an ordinary player. `/a <message>` (or the
  NUI input) only sends while on duty. Ephemeral — a live coordination
  channel (last 100 messages, in memory only), not an audit log; the
  flags/reports tables already cover what's worth keeping forever.

### Optional licensed web dashboard (`server/dashboard.lua`)

Entirely inert while `Config.License.Key` is blank — every function in
that file becomes a no-op and the resource behaves exactly as if it
didn't exist, reading only local `config.lua` values. When a license
key/secret/dashboard URL are configured: pulls remote config overrides
every 10 minutes (movement/damage/scoring/ban-message settings; a field
never touched on the dashboard is left alone locally, never silently
reset), warns in console once a licensed plan is within 7 days of
expiring (`WarnIfExpiringSoon`) and again distinctly once it actually
has (a `401` with `expired: true` is treated differently from a plain
bad key/secret — core detection/banning keeps working either way, only
remote config sync and the Discord ban webhook pause), reports every
ban's identity to the license's configured Discord webhook, and — only
for `injection`-kind bans, only with screenshot evidence enabled on
that license, and only if the community `screenshot-basic` resource is
running — requests a burst of `Config.ScreenshotBurstCount` still
frames from the banned client and posts them as a Discord embed
gallery before dropping them. None of this is real client video
capture (FiveM doesn't allow that) and none of it is a hosted
cross-server ban list — `Config.GlobalBanWebhookUrl` is a separate,
optional, self-hosted-only POST hook for permanent injection bans.

## Install

Import `sql/hd_anticheat_install.sql` before first start (creates
`hd_anticheat_flags` and `hd_anticheat_reports`) —
`server/main.lua` checks for `hd_anticheat_flags` on boot and prints a
warning (without erroring the resource) if it's missing. Requires
`HD_Framework`, `hd_admin`, and `oxmysql` (declared in
`fxmanifest.lua`) started first — it calls `exports['hd_admin']:IsAdmin()`,
`ResolveDiscordUsername()`, and (for the Monitor big screen)
`startSpectate`/`stopSpectate` directly, and bans through hd_admin's
own `hd_admin_bans` table. Note: `hd_anticheat` is not currently
`ensure`d in `server.cfg.example` — add `ensure hd_anticheat` after
`ensure hd_admin` to enable it. `config.lua` is `escrow_ignore`d so
license/config values survive an escrowed build; every other file in
this resource is meant to go through Keymaster escrow as part of
packaging for sale (see the config's own "ON SELLING THIS AS A
LICENSED ASSET" header — Lua source protection is a Cfx.re
escrow/Keymaster concern, not something this resource can enforce from
inside its own code). `screenshot-basic` is an optional soft dependency
(not in `fxmanifest.lua`'s `dependencies`, deliberately) — only needed
for injection-ban screenshot evidence.

## Configuring

Everything lives in `config.lua`:

- `Config.Command` — the slash command that opens the NUI panel.
- `Config.CheckIntervalMs` / `Config.SpawnGraceMs` /
  `Config.MaxOnFootSpeed` / `Config.TeleportDistance` — movement check
  tuning.
- `Config.DamageCheckDelayMs` — invincibility check delay.
- `Config.BanThreshold` / `Config.ScoreDecayPerMinute` / `Config.Points`
  (`speedHack`/`teleportHack`/`invincibility`) — suspicion scoring.
- `Config.BanMessage` — kick-screen template (`%s` = reason).
- `Config.LogLimit` — how many recent flags the Detections tab keeps.
- `Config.DutyCommand` / `Config.ChatCommand` — `/acduty` and `/a`.
- `Config.ReportCommand` / `Config.ReportCooldownMs` — `/acreport` and
  its per-player rate limit.
- `Config.MonitorIntervalMs` — Monitor tab telemetry refresh rate.
- `Config.WorldResetRadius` — `ClearAreaOfObjects` radius per client on
  a World Reset.
- `Config.AnnouncementBannerMs` — on-screen banner duration for
  announcements.
- `Config.InjectionTripwireEvents` — the curated exact-name event list;
  grow only from specific known evidence, never guesswork.
- `Config.License` (`Key` / `Secret` / `DashboardUrl`) — leave `Key`
  blank to disable the web dashboard entirely.
- `Config.ScreenshotBurstCount` / `Config.ScreenshotBurstDelayMs` —
  only relevant with a license configured and screenshot evidence
  enabled on it.
- `Config.GlobalBanWebhookUrl` — optional self-hosted POST hook for
  permanent injection bans; blank does nothing.

## Known limitations, by design for this phase

- Cannot detect noclip (or any client-side modification) directly —
  only its network-visible consequences. A cheat that never produces an
  impossible position or damage outcome is invisible to this resource,
  by the nature of what a FiveM server can actually observe.
- The injection tripwire list is a finite, curated set of exact event
  names — it cannot catch a mod menu that avoids every listed name.
- The Monitor tab's grid view is telemetry (position/heading), not
  video, for every player at once — only the single big-screen slot
  gets genuine live video, and only one target at a time (it's
  literally hd_admin's own one-camera spectate feature reused).
- Live state (suspicion scores, recent-flags/chat ring buffers,
  movement grace, on-duty flags, open-panel/monitor-viewer sets) is all
  in-memory and reset on a resource restart — only banned-and-logged
  detections and submitted reports survive, since those are the only
  two tables this resource persists to.
- Admin chat is intentionally ephemeral (last 100 messages, in memory
  only) — there's no searchable chat history across restarts.
