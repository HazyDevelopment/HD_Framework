# hd_policejob

A hand-written UK police job for this server's real, standalone
`HD_Framework` (`exports['HD_Framework']:GetCoreObject()`). Built to
replace `uk_policejob`, which is genuinely escrow-encrypted and cannot
run here — see the top-level `README.md`'s "Standalone — no qb-core
bridge" section for how that was confirmed.

## What's included

- **Ranks (0–15)**, sourced from `HD_Framework/shared/jobs.lua`'s
  `police` entry: PCSO (0, lowest) → Police Constable → Sergeant →
  Inspector → Chief Inspector → **Armed Response tier (5–8)** →
  Superintendent → … → **Commissioner (15, boss)**.
- **Rank-locked armoury**:
  - PCSO: baton + torch.
  - Police Constable and up (non-ARV): PCSO's kit + taser, handcuffs,
    radio. No firearms.
  - **ARV tier (5–8)** is the only tier issued firearms: pistol,
    carbine rifle, pump shotgun, plus armour plates.
  - Senior command (9–15): back to non-ARV kit.
  - Locked items show greyed out with a padlock and the rank required.
    Every draw/return is validated **server-side** against the
    officer's live job grade.
  - **Every item — weapons included — is a real, placeable/moveable/
    tradeable `hd_inventory` item**, issued through its documented
    `AddItem`/`RemoveItem` server exports (`Config.WeaponAmmo` in
    `config.lua` just says how much ammo to stamp into a firearm's
    item metadata on issue). Drawing a weapon puts it in the
    officer's inventory; it isn't equipped automatically. "Use" it
    from the inventory grid to toggle it into their hand — see the
    "type='weapon' items" changes in `hd_inventory` below. Returning
    or dropping a held weapon force-unequips it so it can't become a
    phantom no longer backed by an inventory slot.
- **Live GPS**, companion to `uk_uhsjob`: this resource only ever
  tracks/pushes its own job (`police`). It deliberately reuses
  `uk_uhsjob`'s existing client-side blip renderer
  (`ukhs:client:gpsUpdate` / `ukhs:client:gpsRemove`) instead of
  building a parallel one — that renderer is a plain `client_script`
  already running on every connected client regardless of job, and
  already colour-codes a unit blue the moment `jobName == 'police'`.
  That's exactly the extension point `uk_uhsjob/config.lua`'s own GPS
  comment describes ("If you're also running the police job resource
  … together the two give full mutual visibility"). No new client
  code was needed for police blips to show up.
- This resource's own armoury-catalog NUI still uses its own hand-drawn
  SVG icon set (`html/images/*.svg`, `Config.IconNames` maps real item
  names like `weapon_nightstick` back to short icon-file names like
  `baton`) — unrelated to `hd_inventory`'s PNG-based icons below, which
  is what actually renders once a drawn item sits in the inventory
  grid.
- **`/detain [server id]`** — the enforcement mechanic `hd_fines`'
  auto-warrant was missing (see the top-level README's "Where to go
  from here"): an on-duty officer within `Config.Detain.Distance` of a
  citizen calls it, and `server/detain.lua` re-checks everything itself
  — on-duty, distance, and whether `hazy_mdt` actually has an active
  warrant for them (`GetActiveWarrants`) — before doing anything. If
  there's a warrant, it's cleared via `hazy_mdt`'s
  `ClearWarrantsForCitizen` export and the citizen is frozen in
  `Config.Detain.Cell` for `Config.Detain.HoldSeconds` (default 5
  minutes), released automatically after, with a live countdown drawn
  client-side (`client/detain.lua`). Soft dependency on `hazy_mdt` —
  without it running, `/detain` just refuses with "MDT is not
  running" instead of erroring, same graceful-degradation pattern as
  everything else cross-resource in this server.

## Install

Already wired into `server.cfg`/`server.cfg.example`: `ensure
hd_policejob` sits right after `ensure uk_uhsjob` in the jobs section.
Give a character the job with the framework's existing admin command:
`/setjob <serverId> police <grade 0-15>`.

## Configuring

Everything lives in `config.lua`:

- `Config.WeaponAmmo` — how much ammo a firearm item is issued with
  (metadata stamped on by `AddItem`). Melee/utility weapon items don't
  need an entry, they default to 0.
- `Config.IconNames` — maps a real item name to this resource's own
  short SVG icon-file name for the armoury NUI only.
- `Config.Ranks` — edit labels, `isArmedResponse`/`isCommand`/`isBoss`
  flags, and each rank's `loadout.items` (real `hd_inventory` item
  names + counts — weapons and ordinary equipment alike).
- `Config.Stations` — add more `{ label, ClockIn, Armoury }` entries.
- `Config.GPS` — `TrackableJobs` should stay `{ 'police' }` here (let
  `uk_uhsjob` track `'ambulance'`); tune `ViewerJobs`/`UpdateInterval`.

## Related fixes made alongside this

While building this, two real, pre-existing gaps in the already-
running `uk_uhsjob` surfaced and were fixed:

- **`uk_uhsjob/server/bridge.lua`'s `Bridge.GiveItem`** was calling
  `Player.Functions.AddItem`, which doesn't exist on `HD_Framework`'s
  real `Player` object (it only has `Money`/`Job`/`MetaData`/
  `Charinfo`/`Save`) — items live in `hd_inventory`, not on the core
  player object. Fixed to call `exports['hd_inventory']:AddItem`
  instead, so paramedics' armoury draws actually give them their kit.
- **`HD_Framework/shared/items.lua` was missing `trauma_kit`**, which
  `uk_uhsjob`'s grade 6–9 loadouts reference — drawing it would have
  silently failed. Added.

Also added directly to `hd_inventory` (used by every job/resource, not
just this one):

- **PNG icons with SVG fallback** — `hd_inventory/html/js/app.js` now
  renders `<img src="images/{item.image}">` first (the `image` field
  already existed per-item in `shared/items.lua`, defaulting to
  `"<name>.png"`, but nothing ever read it before this). If a PNG
  doesn't exist at `hd_inventory/html/images/` yet, it falls back to
  the existing hand-drawn SVG in `icons.js` automatically — nothing
  breaks before PNGs are dropped in.
- **`type='weapon'` items toggle-equip instead of being consumed** —
  `hd_inventory/server/inventory.lua`'s `useItem`/`useHotbar` handlers
  special-case `def.type == 'weapon'`: instead of removing the item,
  they fire `hd_inventory:client:toggleWeapon` (give/remove the native
  weapon on the ped, using the item name as the weapon hash lowercased
  — the same convention QBCore-ecosystem weapon items use). A new
  `hd_inventory:client:forceUnequipWeapon` event backs the "don't leave
  a phantom weapon in hand after the item's gone" case this job's
  armoury uses on return.
