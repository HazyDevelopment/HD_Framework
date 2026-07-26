# HD Framework — United Kingdom Roleplay Server

A standalone FiveM RP framework, QBCore-shaped (`Functions`/`PlayerData`
API) but genuinely independent — no `qb-core` resource runs here.
Everything below (jobs, dispatch, phone, inventory, housing, clothing,
vehicles, economy, admin tools) talks to `HD_Framework` directly.

## Install

1. **Get the two resources not included in this repo:**
   [oxmysql](https://github.com/overextended/oxmysql) into `resources/[hd]/`,
   [pma-voice](https://github.com/AvarianKnight/pma-voice) into `resources/[voice]/`.
   Optional: [screenshot-basic](https://github.com/citizenfx/screenshot-basic)
   if you want the phone's Camera app to work.
2. **Create a database** and import the files in `sql/` in this order:
   `hd_framework_install.sql` → `hd_inventory_install.sql` →
   `hd_phone_install.sql` → `hd_vehiclekeys_install.sql` →
   `hd_society_install.sql` → `hd_fines_install.sql` →
   `hd_admin_install.sql` → `hd_mechanic_install.sql` →
   `hd_housing_install.sql` → `hd_clothing_install.sql`.
   Then also `resources/[mdt]/hazy_mdt/sql/install_qbcore.sql` and
   `resources/[jobs]/uk_uhsjob/install_qbcore.sql`.
   Every statement is `IF NOT EXISTS` — safe to re-run if you're updating.
3. **Copy `server.cfg.example` to `server.cfg`** (the real one is
   gitignored — never commit it). Fill in `sv_licenseKey`
   ([Keymaster](https://keymaster.fivem.net), free), `mysql_connection_string`,
   and your own license under `add_principal`. Resource order in that
   file is the source of truth for what starts and in what sequence —
   don't reshuffle it.
4. **Optional extras**, only needed if you want the feature:
   - Admin panel Discord-role gating: bot token/server ID/role ID in
     `resources/[hd]/hd_admin/config.lua` ("DISCORD ROLE ADMIN" section).
   - Phone Camera app: a Discord webhook URL in `hd_phone/config.lua`
     (`Config.Camera.WebhookUrl`).
5. **Start the server.** Console should print `Database verified. Ready.`
   from `HD_Framework`, `hd_inventory`, `hd_phone`, `hd_admin`,
   `hd_mechanic`, `hd_housing`, and `hd_clothing`.

## What's in this folder

```
resources/
  [hd]/
    HD_Framework/   ← core: player data, money, jobs, saving, multicharacter
    hd_spawn/       ← spawn point picker shown after character select
    hd_admin/       ← staff panel, /admin, Discord-role gated
    hd_clothing/    ← wardrobe (/outfits) + clothing stores
    HD_vehiclekeys/ ← vehicle locking + shared keys
    hd_society/     ← business funds (police/ambulance/cardealer wages)
    hd_fines/       ← fines/invoices — feeds hd_society
    hd_inventory/   ← grid inventory: player, hotbar, stashes, glovebox/trunk, drops
    hd_shops/       ← 24/7-style convenience stores
  [jobs]/
    hd_policejob/   ← UK Police, hand-written against HD_Framework
    hd_ems/         ← death/revive — replaces vanilla death entirely
    uk_uhsjob/      ← UK Health Service job (armoury, garage, GPS, revive)
  [housing]/
    hd_housing/     ← starter flats + the real estate job
  [mdt]/
    hazy_mdt/       ← MDT
  [dispatch]/
    hd_dispatch/    ← 999 calls + recovery calls
  [phone]/
    hd_phone/       ← Contacts, Messages, Calls, social apps, Bank, Mail, Marketplace, Crypto, and more
  [civjobs]/
    hd_civjobs/     ← shift/contract loop for taxi/HGV/postal/waste/bus/reporter/estate agent
    hd_cardealer/   ← vehicle showroom
  [mechanic]/
    hd_mechanic/    ← shop damage diagnostics, MOT/insurance, limp mode
  [voice]/
    hd_radio/       ← pma-voice radio channels, UK-style PTT tone
  [hud]/
    hd_hud/         ← player + vehicle HUD, seatbelt system
sql/                ← install scripts, see Install above for order
server.cfg.example   ← copy to server.cfg and fill in
```

## Resources at a glance

Full detail for each system used to live here; most of it has moved
into per-resource README files where one exists, or is documented in
that resource's own `config.lua`. This is the short version.

**Jobs** (`shared/jobs.lua`) — police, ambulance, mechanic, seven
civilian jobs (taxi/cardealer/realestate/bus/HGV/binman/postal/
reporter/solicitor/judiciary), and `unemployed` (default, pays
Universal Credit). Any job with `type = 'mechanic'` gets recovery
dispatch calls and shop access for free.

**Multicharacter** — up to `Config.MaxCharacterSlots` (5) per license.
Character select → spawn point picker → world. See `HD_Framework/config.lua`.

**Housing** (`hd_housing`) — real game-shipped apartment interiors, a
free starter flat at creation, `/realestate` commands for the rest.
See `hd_housing/README.md`.

**Clothing** (`hd_clothing`) — `/outfits` wardrobe anywhere, plus real
clothing stores. Reads variations straight off the ped model.

**Admin** — `/setjob`, `/addmoney`, `/removemoney`, `/givevehicle`,
`/myjob` (all `hd.admin`-gated), `/duty` (self-service). Full NUI panel
at `/admin`, gated on a Discord role — see Install step 4.

**Dispatch** (`hd_dispatch`) — `/999` for police/UHS emergencies,
`/recovery` for vehicle breakdowns, **F5** opens the board for whoever's
on duty and eligible.

**Death & Revive** (`hd_ems`) — replaces vanilla instant respawn.
Downed players wait for an on-duty ambulance or `/revive`. See
`hd_ems/README.md`.

**Phone** — **M** to open. Contacts, Phone/FaceTime (real audio/video via
pma-voice/WebRTC), Messages, social apps (Birdy/Instapics/Clipz), Bank,
Mail, Marketplace, Crypto, Gallery, Maps, Music, Camera, and more — see
the app list inside the phone itself or `hd_phone/config.lua`.

**Inventory** (`hd_inventory`) — **TAB** for your grid, **1-5** for the
hotbar (hold **Z** to show it). `/glovebox`, `/trunk`, ground drops,
stashes. Server-authoritative weight/slots/proximity.

**Shops** (`hd_shops`) — 24/7-style stores across the map, walk up and
press **E** to buy. Stock list and prices in `hd_shops/config.lua`.

**Voice & Radio** (`hd_radio`) — proximity voice via pma-voice.
`/radio <channel>` (needs a `radio` item); channels 1-3 are reserved for
on-duty police/ambulance/mechanic, everything else is open. Hard-depends
on pma-voice.

**HUD** (`hd_hud`) — health/armour/hunger/thirst, cash, job, speedometer,
fuel gauge, seatbelt (**B** to toggle, real consequences for a high-speed
crash unbuckled).

**Vehicle Keys** (`HD_vehiclekeys`) — `/lock`, `/givekeys`,
`/revokekeys`, `/breakin` (timing minigame, not guaranteed).

**Society Funds** (`hd_society`) — shared job funds, `/boss` panel,
`/addfunds`, `/societyhistory`. Feeds on-duty salaries for
police/ambulance/cardealer/mechanic.

**Fines** (`hd_fines`) — `/fine`, `/paydebt`, `/debts`, `/checkdebt`.
Crossing `Config.Debt.WarrantThreshold` issues a real warrant, enforced
by `hd_policejob`'s `/detain`.

**Civilian jobs** (`hd_civjobs`, `hd_cardealer`) — `/duty`,
`/startshift`, **G** to interact with a stop, `/endshift`. Dealership at
`/dealership`.

**Mechanic** (`hd_mechanic`) — `/diagnose` (on-duty mechanics),
`/vehiclestatus` (anyone). Shop-gated Full Repair/MOT/Insurance, field
repairs from raw materials, limp mode after a hard crash.

## Contributing / extending

Add a job with `type = 'mechanic'` to `shared/jobs.lua` and it
automatically gets recovery calls, radio channel 3, and shop access —
no other file needs touching. Most cross-resource hooks follow the same
shape: check `GetResourceState('other_resource')` before calling its
exports, so nothing hard-fails if a piece isn't installed.
