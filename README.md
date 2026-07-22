# HD Framework — United Kingdom Roleplay Server

Custom QBCore-derived framework, fully UK-rebranded. The framework
core, job/rank data, dispatch, the phone, the custom inventory,
dedicated civilian job gameplay, real voice/radio via pma-voice,
vehicle locking, and a full society-funds/fines economy are all built
and wired together. See "Where to go from here" at the bottom for
genuinely open extension points — this isn't "finished forever," but
every system that was planned is in and working.

## What's in this folder

```
resources/
  [hd]/
    HD_Framework/   ← the real core: player data, money, jobs, saving
    qb-core/        ← compatibility bridge (see below) — do not delete
    hd_admin/       ← staff admin panel, /admin, gated on hd.admin
    HD_vehiclekeys/ ← vehicle locking + shared keys, reads player_vehicles directly
    hd_society/     ← business funds — police/ambulance/cardealer wages draw from these
    hd_fines/       ← police fines / UHS treatment invoices — feeds hd_society
  [jobs]/
    uk_policejob/   ← United Kingdom Police job script (armoury, garage, evidence, GPS)
    uk_uhsjob/      ← United Kingdom Health Service job script (armoury, garage, GPS, revive)
  [mdt]/
    hazy_mdt/       ← the MDT you already had, plus one small addition (see Fines below)
  [dispatch]/
    hd_dispatch/    ← 999 calls (police/UHS) + recovery calls (any type='mechanic' job)
  [inventory]/
    hd_inventory/   ← grid inventory: player, hotbar, stashes, glovebox/trunk, ground drops
  [phone]/
    hd_phone/       ← Contacts, Messages, Calls, Wire/Picta/Loopz, Garages
  [civjobs]/
    hd_civjobs/     ← shift/contract loop for taxi/HGV/postal/waste/bus/reporter/estate agent
    hd_cardealer/   ← vehicle showroom — buy with bank funds, drive off
  [mechanic]/
    hd_mechanic/    ← shops, damage diagnostics, MOT/insurance, limp mode
  [voice]/
    hd_radio/       ← pma-voice radio channels gated on the radio item, UK-style PTT tone
sql/
  hd_framework_install.sql
  hd_phone_install.sql
  hd_inventory_install.sql
  hd_vehiclekeys_install.sql
  hd_society_install.sql
  hd_fines_install.sql
  hd_admin_install.sql
  hd_mechanic_install.sql
server.cfg           ← example, fill in license key + MySQL string
```

## Why there's a `qb-core` resource if this isn't QBCore

`HD_Framework` is the real core — all player data, money and jobs live
there. But `uk_policejob`, `uk_uhsjob` and `hazy_mdt` (and any
off-the-shelf QBCore resource you add later — shops, garages, whatever)
all talk to the framework via `exports['qb-core']:GetCoreObject()`,
because that's the universal QBCore convention. Renaming that call in
every resource you'll ever install isn't realistic, so instead
`resources/[hd]/qb-core` is a **thin bridge**, not a second framework —
every function call forwards straight through to `HD_Framework`. It
holds no data of its own. This is the same pattern projects like QBox
use for `qbx_core` → `qb-core` compatibility.

One consequence: `uk_policejob` and `uk_uhsjob` are **compiled/escrowed**
resources (bought, not hand-written), and both hard-require
`@qb-core/shared/locale.lua` as a file include. `qb-core/shared/locale.lua`
is a minimal, never-throws translation shim so they start — untranslated
strings just show their raw key rather than crashing the resource. Drop
a fuller `Locales['en']` table in there if you want prettier strings.

## Install

1. Get [oxmysql](https://github.com/overextended/oxmysql) and [pma-voice](https://github.com/AvarianKnight/pma-voice)
   into `resources/[hd]/` and `resources/[voice]/` respectively (neither is included here).
2. Create a database and import, **in this order**: `sql/hd_framework_install.sql`, then
   `sql/hd_inventory_install.sql` (it `ALTER TABLE`s the `players` row `hd_framework_install.sql`
   just created), then `sql/hd_phone_install.sql`, then `sql/hd_vehiclekeys_install.sql`, then
   `sql/hd_society_install.sql`, then `sql/hd_fines_install.sql`, then `sql/hd_admin_install.sql`,
   then `sql/hd_mechanic_install.sql`.
   If you installed
   `hd_inventory_install.sql` before v1.1.0 (it now also creates `hd_inventory_drops`, for
   ground-drop persistence), just re-import it — every statement in every one of these files is
   `IF NOT EXISTS`, safe to run again.
3. Also import `resources/[mdt]/hazy_mdt/sql/install_qbcore.sql` (MDT's own tables) and
   `resources/[jobs]/uk_policejob/install_qbcore.sql` + `resources/[jobs]/uk_uhsjob/install_qbcore.sql`
   (fingerprint table is already included in `hd_framework_install.sql`, but check each job's own SQL file for anything extra).
4. Copy `server.cfg` next to your `resources` folder (or merge it into your existing one), fill in
   `sv_licenseKey`, `mysql_connection_string`, and your admin license under `add_principal`.
5. Start the server. Console should print `Database verified. Ready.` from `HD_Framework`, `hd_inventory` and `hd_phone`.

## Jobs & ranks (`resources/[hd]/HD_Framework/shared/jobs.lua`)

| Job key | Label | Grades | Boss |
|---|---|---|---|
| `police` | United Kingdom Police | 0 PCSO → 15 Commissioner (16 ranks incl. Armed Response tier) | Commissioner |
| `ambulance` | United Kingdom Health Service | 0 Student Paramedic → 9 Operations Manager | Operations Manager |
| `mechanic` | Vehicle Technician | 0–4, top = Garage Manager | Garage Manager |
| `unemployed` | Unemployed | Universal Credit Claimant (default job for every new character) | — |
| `taxi`, `cardealer`, `realestate`, `busdriver`, `hgv`, `binman`, `postal`, `reporter`, `solicitor`, `judiciary` | UK-flavoured replacements for QBCore's stock taxi/cardealer/realestate/bus/trucker/garbage/postop/reporter/lawyer/judge jobs | 3–4 grades each | top grade each |

`job.type` is the important extension point: **any** job with
`type = 'mechanic'` automatically qualifies for recovery calls in
`hd_dispatch` (see below) — not just the stock `mechanic` job. Add a
second garage's job to `shared/jobs.lua` with `type = 'mechanic'` and
it picks up recovery access for free, no dispatch-side changes needed.

New characters start on `unemployed` and get a small "Universal Credit"
payment to their bank every 45 minutes (`server/benefits.lua`) so no one
starts at zero — this isn't a fake starter-cash hack, unemployed is a
real, valid default UK job.

## Admin commands

`/setjob [id] [jobkey] [grade]`, `/addmoney [id] cash|bank [amount]`,
`/removemoney [id] cash|bank [amount]`, `/givevehicle [id] [model] [plate] [garageKey]`,
`/myjob`. Gated behind the `hd.admin` ACE permission — grant it in
`server.cfg` (already stubbed in the example). `/duty` is self-service
(no permission needed) — it's how anyone without a dedicated duty UI
(mechanic, taxi, etc.) clocks on so they start receiving dispatch calls
and, for the jobs below, shift contracts. `/givevehicle` is now just
the admin shortcut for spawning a specific vehicle straight into
someone's ownership — `hd_cardealer` (below) is the real, player-facing
way a vehicle gets bought.

## Admin Panel (`resources/[hd]/hd_admin`)

**`/admin`** opens a full NUI staff panel — gated on the same `hd.admin`
ACE permission as everything else above, not a separate staff system.
The command silently does nothing for anyone without it, but that's
just UX: every action the panel can trigger re-checks `hd.admin`
server-side on its own, independent of whether the NUI ever should
have opened in the first place.

- **Players tab** — every online player, with a per-player action
  drawer: Teleport To / Bring Here, Heal, Freeze/Unfreeze, Kick (with a
  reason), Ban (reason + duration, including Permanent), Give Money
  (cash or bank), Set Job (grade dropdown populated from
  `shared/jobs.lua` live, not hardcoded), and Give Item (same, from
  `shared/items.lua`).
- **World tab** — weather (the real `SetWeatherTypeNow` types, not a
  guessed list), time of day, and a server-wide announcement broadcast.
- **Bans tab** — every active ban with who issued it, why, and when it
  expires (or "Permanent"), with one-click unban.
- **Self tab** — noclip, god mode, teleport to your current waypoint,
  and spawn any vehicle by model name. These four are the only actions
  that don't round-trip to the server, since they only ever affect the
  admin's own client.
- **Bans are enforced on connect**, independently of `HD_Framework`'s
  own license check — `hd_admin` runs its own `playerConnecting`
  deferral, keyed off the `license` identifier (not citizenid, so a
  ban survives a character rename or a new character on the same
  Rockstar account) rather than citizenid. FiveM supports multiple
  resources each independently deferring/resolving a connecting
  player, so this coexists cleanly with the framework's own check
  rather than needing to be folded into it.
- Money, job, and item changes all go through `HD_Framework`'s own
  `Player.Functions.*`, exactly the same calls `/addmoney`/`/setjob`
  use — the panel isn't a second, parallel way of mutating player
  state, just a friendlier front end for the same one.

## Dispatch (`resources/[dispatch]/hd_dispatch`)

- `/999` — any player reports a police or medical emergency: pick
  Police or UHS, type a description, it's logged with their current
  location.
- `/recovery` — any player whose vehicle is broken down requests
  recovery. Must be in/near the vehicle so its plate can be read.
- **F5** — opens the dispatch board for whoever's eligible: on-duty
  `police` → sees police calls, on-duty `ambulance` → sees UHS calls,
  on-duty **any job with `type = 'mechanic'`** → sees recovery calls.
  That's the whole point of the `job.type` extension point in
  `shared/jobs.lua` — add a second garage job with `type = 'mechanic'`
  later and it gets recovery access with zero dispatch-side changes.
- Calls show priority (UK police grading: Grade 1 Immediate / Grade 2
  Priority / Grade 3 Scheduled), assigned units, and Accept / On Scene
  / Close actions — all re-validated server-side, never trusted from
  the client. A map blip drops for every call a responder is eligible
  to see; "Waypoint" sets nav straight to it.
- **Automatic calls**: shots fired (nearby reports merge into one call
  instead of spamming the board) and player-downed (currently hooked
  to the vanilla `baseevents:onPlayerDied` event — if/when a proper
  medical system replaces vanilla death, point its "player is now
  down" moment at `TriggerServerEvent('hd_dispatch:server:playerDowned')`
  instead, it'll be more accurate).
- Calls aren't persisted to a database yet — closed calls just drop off
  the live board. Fine for v1; flag it if you want call history later.

## Phone (`resources/[phone]/hd_phone`)

**M** opens/closes it. Every app (Wire/Picta/Loopz below) is
original-named with its own UI, not a reproduction of Twitter/
Instagram/TikTok's branding — that's what keeps this clear of any
trademark issue under FiveM's ToS.

- **Contacts** — save a name against a number, call or message straight
  from the list.
- **Phone** — dialer + call log flow: ring, answer, decline, hang up,
  a live call timer once connected, with **real two-way audio** via
  pma-voice (`exports['pma-voice']:setPlayerCall`, each call's own id
  doubles as its pma-voice call channel). Degrades to a silent-but-
  functional call UI if pma-voice isn't running.
- **Messages** — SMS between phone numbers (`charinfo.phone`, generated
  once per character by `HD_Framework`), threaded, unread counts,
  delivered instantly if the recipient's online.
- **Wire** (Twitter-equivalent) — short text posts, public feed, likes.
- **Picta** (Instagram-equivalent) — caption + image-link posts.
- **Loopz** (TikTok-equivalent) — same mechanics as Picta, reframed as
  short "moments" rather than real embedded video — see limitation below.
- **Garages** — lists vehicles owned via `player_vehicles`; store while
  inside your current vehicle at a garage, retrieve while standing at
  one. Ownership/state/proximity are all re-checked server-side.

**Known limitations, by design for this phase:**
- **Loopz isn't real video.** Embedding arbitrary video in an NUI
  reliably and safely is a bigger job than this phase — it's simplified
  to the same text+image mechanism as Picta, just presented separately.
- Image posts are restricted to `Config.ImageHostWhitelist` (same hosts
  hazy_mdt already trusts for mugshots) to avoid arbitrary URLs.

`Config.RequireItem` is now **true** — `hd_inventory` exists and seeds
every new citizen with a `phone` item (`Config.StarterItems` in
`hd_inventory/config.lua`), so the check has something real behind it.

## Inventory (`resources/[inventory]/hd_inventory`)

**TAB** opens your own grid. UX modelled on modern drag-and-drop
store-style inventories (Quasar Store and similar) — built from
scratch, no third-party code or assets.

- **Player grid** — 30 slots, 30kg capacity (`Config.MaxSlots` /
  `Config.MaxWeight`), drag to move/stack, **Shift+drag** to split a
  stack, **right-click** for Use / Split / Drop, drag off either panel
  to drop an item on the ground.
- **Hotbar** — slots 1-5 double as the hotbar, always visible on-screen
  (not just while the grid's open) and usable with keys **1-5** any time.
- **Dual-panel containers** — your inventory (always the left panel)
  opens alongside a secondary container on the right: **glovebox**/
  **trunk** (`/glovebox`, `/trunk` — glovebox requires being in the
  vehicle, trunk just requires standing near it, and both now require
  keys via `HD_vehiclekeys` — see below), **ground drops** (walk up
  and press **E**), or a **stash** — any other resource can open one on
  a player with `exports['hd_inventory']:OpenStash(id, label, slots, weight)`
  (client) or the server export of the same name for permission-checked
  cases (e.g. a future evidence locker).
- **Glovebox/trunk capacity is per vehicle class** now
  (`Config.VehicleClassCapacity`, keyed by the real `GetVehicleClass()`
  0-21) — a van holds far more than a Super car. Resolved live from
  the actual vehicle entity every time a glovebox/trunk is opened or
  moved into, not cached. A few classes have **no** glovebox at all
  (motorcycles) or no storage whatsoever (cycles) — trying to open one
  is denied outright with a clear reason, not shown as an empty panel.
- Every container shares one abstraction (`server/containers.lua`), so
  dragging an item from any one of them into any other — player,
  stash, glovebox, trunk, drop — just works with no special-casing.
- **Server-authoritative**: weight/slot capacity, stacking, and
  proximity to glovebox/trunk/drops are all re-checked on every single
  move, not just when the container was opened — walking away from a
  car mid-loot (or it driving off) cuts you off live.
- **`AddItem` / `RemoveItem` / `HasItem` server exports** — for other
  resources to give/take/check items with no NUI involved (this is
  what a future car-dealer or evidence system would call).

Ground drops now render as a real world prop, not just a marker —
`Config.DropProp` (default `prop_med_bag_01b`, the same battle-tested
default [ox_inventory](https://github.com/overextended/ox_inventory)
itself ships) rather than one accurate model per item, which isn't a
realistic ask across 20+ items. Each prop is spawned **local and
non-networked** (`CreateObject(..., false, true, true)`) — purely
decorative, proximity-culled per client — exactly the pattern
ox_inventory's own source uses for this, not something invented here.
Interaction still goes through the `[E]` prompt, not native prop
physics. They're persisted too: `hd_inventory_drops` survives a
restart, reloaded into memory the moment the server comes back up
(`server/drops.lua`).

Item icons are real hand-drawn SVGs now (`html/js/icons.js`), one per
`shared/items.lua` entry — not the generated-monogram placeholder
earlier phases used. Anything without a matching icon falls back to a
generic box icon rather than breaking the grid.

## Voice & Radio (`resources/[voice]/hd_radio`)

Real proximity voice and radio audio via [pma-voice](https://github.com/AvarianKnight/pma-voice)
(not included — grab it separately, it's not our resource to redistribute).
`hd_radio` is a thin layer on top of it, not a reimplementation:

- **`/radio <channel>`** (1-999) tunes in — requires carrying the
  `radio` item (already issued by `uk_policejob`/`uk_uhsjob`'s armoury
  loadouts). `/radio 0` switches off, `/radio` alone reports your
  current channel.
- **Reserved channels** (`Config.ReservedChannels`) — channel 1 is
  on-duty `police` only, channel 2 is on-duty `ambulance` only, channel
  3 is any on-duty `type = 'mechanic'` job (the same recovery-call
  extension point `hd_dispatch` uses). Everything else (4-999) is open
  civilian chatter to anyone with a radio. Enforced **twice**: once in
  `hd_radio`'s own `setChannel` handler (so a rejected player gets a
  clear reason), and again via pma-voice's real
  `exports['pma-voice']:addChannelCheck` — the second one is what
  actually stops someone bypassing `hd_radio` and hitting pma-voice's
  exports directly.
- **Transmitting is pma-voice's own job** — its default PTT is **Left
  Alt** (`voice_defaultRadio`, already set in `server.cfg`). `hd_radio`
  never registers its own PTT key; it would just fight pma-voice's.
- **UK-style confirmation tone** — a short two-tone pip plays for *you*
  when you key up/down (`pma-voice:radioActive`), replacing pma-voice's
  stock click (muted via `setMicClickOnVolume`/`setMicClickOffVolume`).
  Shipped as **real bundled `.wav` audio files**
  (`html/audio/ptt_on.wav`, `ptt_off.wav`), generated by
  `tools/generate_tones.py` (pure Python stdlib, no numpy, no external
  encoder — run it again any time to regenerate or retune them). That
  script does real signal processing on top of the tone, not just a
  beep: band-limits it to roughly 300Hz-3000Hz (the same narrow
  bandwidth a real analogue/PMR voice channel is constrained to — this
  alone is most of why radio audio sounds "radio"), soft-clip
  saturates it for a bit of speaker crunch, and appends a short
  decaying burst of band-limited static standing in for a squelch
  tail on key-up. It's a *lot* closer to a real radio speaker than a
  plain oscillator beep, but I'll say plainly: it is still **not** a
  recording of real Airwave/TETRA equipment — I have no way to obtain
  or license that, and no amount of DSP on a synthesised tone changes
  that fact. If an actual field recording matters to you, sourcing one
  (a sound library, or your own recording) and dropping it in as
  `ptt_on.wav`/`ptt_off.wav` is the only honest path there; nothing
  else in `hd_radio` needs to change either way. You can also drop
  equivalent files into pma-voice's own `ui/mic_click_on.ogg` /
  `mic_click_off.ogg` to change its native click too (set
  `Config.Tone.MuteStockClick = false` in `hd_radio/config.lua` if you
  want both playing).
- Phone calls (`hd_phone`) now use the same pma-voice connection —
  `exports['pma-voice']:setPlayerCall(src, callId)` on answer, `(src,
  0)` on hang-up — real two-way audio, no separate radio-vs-phone
  voice plumbing to maintain.
- `hd_radio` **hard-depends** on pma-voice (`fxmanifest.lua`
  `dependencies`) — unlike everywhere else in this build, a radio
  resource with no voice plugin genuinely has nothing to do, so it
  won't start without it rather than silently doing nothing.
- One thing I can't verify: whether `uk_policejob`/`uk_uhsjob`'s
  compiled armoury actually calls `hd_inventory`'s `AddItem` export (or
  some other inventory interface) when issuing the `radio` item — their
  own README only promises "the standard AddItem-style function." If
  officers aren't spawning with a `radio` item in practice, `/givevehicle`-
  style admin backstop: `exports['hd_inventory']:AddItem(source, 'radio', 1)`
  from an admin command, or just `/setjob` them and let them re-equip.

## Vehicle Keys (`resources/[hd]/HD_vehiclekeys`)

Lock state is server-authoritative and **identical for everyone**
looking at a given plate — including the owner. Nobody gets a special
bypass; you unlock your own car with `/lock` same as using a real key
fob, exactly the same as any non-owner would have to.

- **`/lock`** toggles the vehicle you're in (or the nearest one within
  `Config.LockRadius` you hold keys to). Requires being the owner or
  holding shared keys — checked server-side every time, not just once.
- **`/givekeys [id]`** (while in the vehicle, owner only, recipient
  must be close by) shares a key; **`/revokekeys [id]`** takes it back.
  `hd_vehicle_keys` (new table) tracks who else has a copy — ownership
  itself is never duplicated, it's read live from
  `player_vehicles.citizenid` every time, so buying a car from
  `hd_cardealer` or getting one via `/givevehicle` is automatically
  keyed to the owner with zero extra wiring.
- New vehicles default **unlocked** (`Config.DefaultLocked = false`) —
  you drive off the dealership forecourt with keys already in hand
  instead of finding your brand new car locked.
- Locking uses the plain networked `SetVehicleDoorsLocked` native (not
  a per-player override) — every client applies the same
  server-confirmed state to the same plate, so nobody's view
  disagrees. A background loop clears the pointless "tugging the door
  handle" animation and tells you why if you try a locked vehicle
  that isn't yours.
- **`HasKeys(src, plate)`** server export — `hd_inventory` now calls
  this before letting anyone into a glovebox or trunk, closing the gap
  flagged in earlier phases. Unowned/NPC vehicles always report `true`
  (no lock concept applies to them at all).
- **`/breakin`** attempts to force a locked vehicle you have no keys
  to — now a real timing minigame, not a flat wait: a marker sweeps a
  bar (native `DrawRect`, no NUI) and you press **E** to catch it
  inside the highlighted zone, across `Config.BreakIn.Minigame.Attempts`
  rounds (default 5, need 3 catches to "win"). Cancel any time by
  moving away, getting in a vehicle, or pressing Backspace.
  **Winning doesn't guarantee success** — it's an input to the
  server's roll, not the roll itself: `Config.BreakIn.SuccessChance`
  (85%) if you won the minigame, `Config.BreakIn.FailedMinigameChance`
  (20%, still real odds) if you lost or bailed. That split exists
  because the server can't verify your reaction timing, only the
  consequence of it — the same trust boundary every skill-check
  minigame in the FiveM ecosystem accepts, and it means a spoofed
  "I won" from a modified client still only gets the worse odds, never
  a guarantee. An **independent** `Config.BreakIn.AlarmChance` (40%)
  is rolled regardless of the outcome — smashing a window risks the
  alarm whether or not you get in. If the alarm goes off and
  `hd_dispatch` is installed, it logs a real police call
  (`exports['hd_dispatch']:CreateCall('police', ...)`, a new export
  added specifically for this) at Grade 2 Priority, titled "Vehicle
  Break-in" — this is what actually calls it in, not a guaranteed
  response.

## Society Funds (`resources/[hd]/hd_society`)

A shared business fund per job, in `hd_society_funds`. **`/boss`**
opens a small deposit/withdraw panel for whoever currently holds the
top (`isboss`) grade of a listed job (`Config.Societies` — `police`,
`ambulance`, `cardealer` out of the box).

- `HD_Framework`'s on-duty salary loop (`server/salary.lua`) now draws
  `police`/`ambulance`/`cardealer` wages **from this fund**, not out of
  thin air — an empty fund really does mean nobody gets paid that tick,
  not free money. `solicitor`/`judiciary` are unaffected, still a flat
  personal wage; the seven `hd_civjobs` jobs still earn per contract.
  If `hd_society` isn't installed: `cardealer` falls back to its old
  flat personal wage, `police`/`ambulance` simply get nothing (neither
  was ever paid a flat wage — a police force isn't self-funded).
- `hd_cardealer` deposits a cut of every sale (`Config.SocietyCut`,
  default 20%) into the `cardealer` fund automatically — the rest is a
  sink, representing stock/overhead.
- **`police`/`ambulance` now have a real in-world revenue mechanic** —
  see Fines below. `/addfunds [society] [amount]` (`hd.admin`-gated)
  still exists as a manual top-up (or a boss depositing personal money
  via `/boss`), but it's no longer the *only* way funds grow.
- **`AddFunds`/`RemoveFunds`/`GetBalance`** server exports for any
  other resource to hook in — `hd_fines` (below) is exactly this
  pattern in practice, not just a theoretical extension point anymore.
- **`RemoveFunds` is now atomic** — `UPDATE hd_society_funds SET
  balance = balance - ? WHERE society = ? AND balance >= ?`, checked
  via the affected-row count, instead of a separate balance read
  followed by an unconditional update. That closes the earlier
  documented race where two bosses withdrawing in the same instant
  could both pass a balance check that only actually covered one of
  them — the WHERE clause itself is now the check, evaluated
  atomically against each row as MySQL locks it for the write.

## Fines (`resources/[hd]/hd_fines`)

The revenue mechanic `police`/`ambulance` society funds were missing.
**`/fine [id] [amount] [reason]`** — job-gated (`Config.Jobs`: `police`
issues a **Fine**, `ambulance` issues a **Treatment Invoice**, the
fictional-UHS equivalent of billing for a callout — this is a game, UHS
isn't the real NHS), on-duty required, target must be within
`Config.TargetRadius`. Deducts the amount from the target's bank and
deposits it straight into the issuer's job's `hd_society` fund via
`AddFunds` — if `hd_society` isn't installed, `/fine` refuses outright
rather than taking money that goes nowhere. Per-job `minAmount`/
`maxAmount` bounds are enforced server-side, not just suggested by the
command syntax.

- **Cooldowns** (`Config.Cooldown`) — an officer can't fine the same
  person again within `PerTargetSeconds` (5 min default), or issue
  *any* fine again within `GlobalSeconds` (5s default). In-memory per
  issuer, resets on restart — that's fine for an abuse guard, no need
  to persist it.
- **Debt, not just a failed command, when a target can't pay in full.**
  `/fine` reads their actual bank balance (`Player.Functions.GetMoney`)
  and collects whatever they genuinely have right now, depositing that
  portion into the society fund immediately; the shortfall becomes a
  row in `hd_fines_debts` against their `citizenid` — not silently
  forgiven, not a hard failure either.
- **`/paydebt [amount]`** — anyone can pay down their own debt from
  their bank. Pays oldest debts first and splits correctly across
  whichever society each one is owed to (a citizen can owe more than
  one job at once); any overpayment past what's actually owed is
  refunded rather than vanishing.
- **`/debts`** — check your own total unpaid debt.
- **`/checkdebt [id]`** — police/ambulance/`hd.admin` only. Reports the
  target's total and flags it once it crosses
  `Config.Debt.WarrantThreshold` (£2000 default).
- **Automatic warrant on crossing the threshold** (`Config.Debt.AutoWarrant`)
  — the instant a fine pushes someone's total debt from under
  `WarrantThreshold` to at-or-over it, `hd_fines` writes it to **two
  independent places**, either of which can be missing without
  breaking the other:
  - **`hd_dispatch`** — a live call right now:
    `exports['hd_dispatch']:CreateCall('police', ...)` at Grade 1
    Immediate, titled "Warrant Issued", pinned to the target's current
    position (they're guaranteed online at this point — `/fine`
    already required them within `Config.TargetRadius` of the issuing
    officer). Drops off the board once closed, same as any call.
  - **`hazy_mdt`** — a real, persistent row in its own
    `mdtpolice_warrants` table via a new `IssueSystemWarrant` export I
    added to `hazy_mdt` specifically for this (`server/main.lua`,
    factored out of the same `Handlers.setWarrant` code path a real
    officer's MDT session uses, so the DB insert, live-feed broadcast,
    and Discord webhook all fire exactly the same way regardless of
    which one triggered it). Correction to something I said in an
    earlier round: I'd described `hazy_mdt` as escrowed like
    `uk_policejob`/`uk_uhsjob` — that was wrong, `hazy_mdt` is plain,
    editable Lua (only those two job resources are actually compiled),
    which is exactly what made this addition possible. It shows up in
    `/mdt`'s civilian search immediately, and survives independently
    of whether any officer ever saw the live `hd_dispatch` call.

  Fires exactly once per crossing either way, not on every fine after
  — paying it back down and crossing the threshold again later fires
  it again, which is correct, not a bug.

## Civilian jobs (`resources/[civjobs]/`)

### hd_civjobs — shift/contract loop
One config-driven engine (`server/main.lua` + `config.lua`) instead of
seven near-duplicate resources. A "contract" is an ordered list of
stops, each stop a set of points that must **all** be visited (any
order) before the next stop unlocks — that single shape covers every
job below:

| Job | Vehicle | Route shape |
|---|---|---|
| `taxi` | Taxi | 1 pickup → 1 dropoff, both randomised |
| `hgv` | Box truck | Load at depot → 1 randomised delivery point |
| `postal` | Panel van | Load at depot → 3 randomised addresses (all required) |
| `binman` | Bin lorry | 3 randomised bin points (all required) → tip at depot |
| `busdriver` | Bus | A **fixed** 5-stop circuit, driven in order every shift |
| `reporter` | On foot | 1 randomised story location |
| `realestate` | On foot | 1 randomised property to appraise |

- `/duty` to clock on, `/startshift` to generate a contract (spawns the
  job vehicle at the depot if the job needs one), **G** to interact
  with the current stop once close enough, `/endshift` to bail out.
- GPS blips + route line follow the current stop automatically; a
  `[G] <stop label>` prompt shows once you're within
  `Config.InteractRadius`.
- Every check — which stop you're on, whether you're actually close
  enough, the payout — is server-side (`ActiveContracts[src]`); the
  client only renders what the server confirms.
- `solicitor` and `judiciary` are **deliberately not here** — every UK
  RP server treats those as pure roleplay professions (consultations,
  courtroom scenes), not grindy routes. They stay real, payable,
  duty-toggleable jobs with no forced minigame; `mechanic` isn't here
  either since its loop is already `hd_dispatch`'s recovery calls plus
  `hd_mechanic`'s shop work (see below).

### hd_cardealer — vehicle showroom
`/dealership` while standing at the showroom opens a catalog NUI (six
stock GTA vehicles, editable in `config.lua`). Buying deducts real bank
funds, inserts a `player_vehicles` row, and spawns the car with you in
the driver's seat — this is now the actual way players own a vehicle;
`/givevehicle` is the admin-only fallback. Open to anyone, not
job-gated — `cardealer` is the staff role for whoever works the
showroom, paid via `HD_Framework`'s on-duty salary loop out of the
`cardealer` `hd_society` fund this resource feeds on every sale (see
Society Funds above), not a purchase restriction.

### Civilian salary (`HD_Framework/server/salary.lua`)
Every job grade in `shared/jobs.lua` has always had a `payment` value;
until now nothing paid it out. On-duty players in a job with no
contract system of its own get it automatically every 20 minutes
(`Config.Salary`): `police`/`ambulance`/`cardealer`/`mechanic` draw it
from their `hd_society` fund, `solicitor`/`judiciary` get a flat
personal wage. The seven `hd_civjobs` jobs are excluded from this
entirely — they earn per completed contract instead, so a passive
salary on top would double-pay them. `unemployed` is excluded too (it
has Universal Credit instead — see the Jobs & ranks section above).

## Mechanic Jobs, MOT & Insurance (`resources/[mechanic]/hd_mechanic`)

Builds out the existing `mechanic` job (`shared/jobs.lua` — Apprentice
Technician → Vehicle Technician → Senior Technician → Recovery
Operator → Garage Manager) into an actual shop, and gives every
vehicle a UK-style MOT/insurance lifecycle. Uses the same
`job.type == 'mechanic'` extension point `hd_dispatch` and `hd_radio`
already key off, so a second garage job added later with
`type = 'mechanic'` in `shared/jobs.lua` picks up shop access for free
too — no `hd_mechanic` code needs touching.

- **Temporary compliance on purchase** — `hd_cardealer` now calls
  `exports['hd_mechanic']:InitTempCompliance(plate)` the moment a sale
  completes: a brand new car starts with **24 hours** of temporary
  MOT + insurance (`Config.TempCompliance`), just long enough to
  legally reach a shop before it lapses. No-op if `hd_mechanic` isn't
  installed — `hd_cardealer` doesn't require it.
- **`/diagnose`** (on-duty mechanics only) opens the Mechanic Terminal
  on your current/nearest vehicle — the read `IsVehicleTyreBurst` /
  `GetVehicleBodyHealth` / `GetVehicleEngineHealth` / `GetVehiclePetrolTankHealth`
  / `GetVehicleDirtLevel` snapshot is pulled **server-side** from the
  networked vehicle entity, not self-reported by whoever's driving —
  the whole point is a mechanic being able to see curbing, burst
  tyres, or a battered engine on a car whose driver might rather they
  didn't. MOT/insurance status and limp-mode state show here too.
- Bring the vehicle within a shop's radius (`Config.Shops` —
  placeholder at the existing LS Customs building, move it to your own
  garage) and the terminal unlocks three paid actions: **Full Repair**,
  **Issue MOT**, **Issue Insurance**. All three bill whichever *online*
  player's `citizenid` matches `player_vehicles.citizenid` for that
  plate **and** is physically standing at the shop — never an offline
  balance mutation, never trusting the client on who owns what. Fees
  deposit into the `mechanic` `hd_society` fund (same shape as
  `hd_fines` feeding police/ambulance), which is what actually funds
  on-duty mechanic wages now (see Civilian salary above).
- **MOT** charges the test fee (`Config.MOT.Price`) whether it passes
  or fails, same as a real UK test centre — pass requires body/engine
  both at or above `Config.MOT.MinBodyPercent`/`MinEnginePercent` and
  no more than `Config.MOT.MaxBurstTyres` burst tyres, computed from
  the same live server-side read as diagnostics. A pass certifies for
  `Config.MOT.DurationDays` (30 default); a fail explains exactly what
  needs fixing and charges nothing extra to retry once it's fixed.
- **Insurance** is a straight paid cover period
  (`Config.Insurance.DurationDays`, 30 default) — no pass/fail check,
  administered at the shop rather than self-service, matching what was
  asked for even though a real UK insurer isn't a garage.
- **`/vehiclestatus`** — anyone, no mechanic needed, no NUI: a quick
  text readout of your current vehicle's MOT/insurance validity and
  whether it's in limp mode, so a player can tell their cover is about
  to lapse without needing a mechanic online.
- **Limp mode** — a hard impact (`Config.LimpMode.SpeedThresholdMph`,
  80 default) that sheds at least `DeltaMph` in one check is inherently
  a client-reported signal (there's no way to independently re-derive
  real-time vehicle physics server-side, the same trust boundary
  `HD_vehiclekeys`' break-in minigame already accepts for its "passed"
  flag) — the server rate-limits and sanity-clamps the claim, then
  slams engine health down and applies a power/torque/top-speed cap
  via an entity **state bag** (`hd_limpMode`), which replicates to
  every client that has the vehicle loaded, not just the driver, so
  passengers and bystanders see the same struggling engine.
- **`repairkit_advanced`** (new item, `shared/items.lua`) is a roadside
  field fix — used while in the driver's seat of a limping vehicle, it
  floors the engine at `Config.Repair.AdvancedKitFloor` (60% — never
  lowers it) and lifts the power/torque/speed cap so the vehicle drives
  normally again, but doesn't touch body damage or clear the MOT/
  insurance state. It hooks `hd_inventory`'s existing
  `hd_inventory:server:onItemUsed` extension point (the same one
  called out as a "natural extension point" in that file's own
  comments) rather than requiring any change to `hd_inventory` itself.
  A **Full Repair** at a shop is the only way back to 100% engine/body,
  clearing limp mode for good and — new this round — actually
  persisting to `player_vehicles.engine`/`body`.
- **Fixed a pre-existing gap in `hd_phone`'s garages**: storing a
  vehicle never wrote its live engine/body health back to
  `player_vehicles`, only the original purchase-time value (1000) ever
  sat in those columns — meaning any damage, repaired or not, was
  invisible again the moment you stored the car. `client/garages.lua`
  now reports current health on store, `server/garages.lua` persists
  it (clamped to the native's real 0-1000 range). Without this,
  `hd_mechanic`'s full repairs wouldn't actually stick across a
  store/retrieve cycle.
- **`hazy_mdt`'s vehicle search** (police-only, MDT plate lookup) now
  shows MOT/insurance/limp status alongside the existing owner/marker
  info, via `exports['hd_mechanic']:GetCompliance(plate)` — no-op if
  `hd_mechanic` isn't installed, same graceful-degradation shape as
  every other cross-resource export in this build.
- **No automatic enforcement.** An expired MOT/insurance is visible —
  to the owner via `/vehiclestatus`, to a mechanic via `/diagnose`, to
  police via the MDT — but nothing fines or flags it automatically.
  `uk_policejob` is compiled/escrowed (see "Why there's a qb-core
  resource" above), so there's no way to hook an ANPR-style automatic
  check into its scanner from here; a live plate check still has to go
  through the MDT search by hand.

## Where to go from here

Every system originally scoped is built and talking to every other
one — MDT ↔ jobs ↔ dispatch ↔ phone ↔ inventory ↔ vehicle keys ↔
society funds ↔ fines ↔ civilian jobs ↔ salary ↔ radio all share the
same framework core with no duplicated state. Genuinely open threads,
none of them blocking anything above:

- **An actual field recording for the radio PTT tone.** Being direct
  about this one: `hd_radio`'s `.wav` files went through real signal
  processing this round (band-limiting, saturation, a squelch-tail
  burst — see the Voice & Radio section) and sound a lot more like a
  radio speaker than a plain beep now, but the source is still a
  synthesised tone, not a recording of real Airwave/TETRA equipment. I
  have no way to obtain or license that audio. If a genuine field
  recording matters to you, sourcing one yourself and dropping it in
  as `ptt_on.wav`/`ptt_off.wav` is the only honest path there.
- **The auto-warrant still isn't an enforcement mechanic, just a
  notification (now two of them).** Crossing `Config.Debt.WarrantThreshold`
  raises a live `hd_dispatch` call **and** writes a persistent row into
  `hazy_mdt`'s own `mdtpolice_warrants` table (see Fines above) — so it
  no longer disappears the moment the dispatch call is closed. But
  nothing *acts* on it automatically either way: no auto-arrest, and
  nothing stops the target going about their day until an officer
  actually looks it up or responds to the call themselves.
- **Debt never expires or gets written off** — once recorded in
  `hd_fines_debts` it sits there until `/paydebt` clears it, with no
  admin "waive this debt" command and no time-based decay.
- **Per-item ground-drop props** — every drop uses one generic
  `prop_med_bag_01b` model regardless of contents (matching
  ox_inventory's own default trade-off), rather than a real prop per
  item.
- **A transaction log for `hd_society`** — deposits/withdrawals/fines
  all move real money now, but none of it is logged anywhere a boss
  could review later (no Discord webhook, no in-game history).

Say the word and I'll pick any of these up, or anything else you want
added.
