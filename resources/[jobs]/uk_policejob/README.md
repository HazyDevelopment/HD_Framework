# ukp_job — United Kingdom Police (QBCore / ESX)

A full police job resource — ranks, armoury, job-locked garage,
evidence locker, fingerprint scanner, and a GPS unit tracker (with
optional wasabi_gps integration) — for either QBCore or ESX, switched
with one config line. Structurally based on the Metropolitan Police's
real-world rank progression, renamed United Kingdom Police, with an
original setup (not a reproduction of any real crest/branding).

## Ranks (grade 0-15)
| Grade | Rank | Tier |
|---|---|---|
| 0 | PCSO | Basic — unarmed |
| 1 | Police Constable | Standard |
| 2 | Sergeant | Standard |
| 3 | Inspector | Standard |
| 4 | Chief Inspector | Standard command |
| 5 | Armed Response Officer | Armed Response Unit |
| 6 | ARV Sergeant | Armed Response Unit |
| 7 | ARV Inspector | Armed Response Unit |
| 8 | ARV Commander | Armed Response Unit |
| 9 | Superintendent | Senior command |
| 10 | Chief Superintendent | Senior command |
| 11 | Commander | Senior command |
| 12 | Deputy Assistant Commissioner | Senior command |
| 13 | Assistant Commissioner | Senior command |
| 14 | Deputy Commissioner | Senior command |
| 15 | Commissioner | Top of the job (isBoss) |

Every rank's armoury loadout, command flag, and armed-response flag
are set in `Config.Ranks` — edit freely, this is just a sensible
starting point matching your spec (0 = PCSO with basic command,
5-8 = Armed Response tier, 9+ = senior command up to Commissioner).

## Features
- **QBCore or ESX** — `Config.Framework` in `config.lua`. Only
  `client/bridge.lua` and `server/bridge.lua` talk to the framework
  directly; everything else is framework-agnostic.
- **Armoury** — walks up to the armoury point, opens a menu showing
  their rank's exact weapon/equipment loadout, "Draw full loadout"
  gives it all in one click. Fully re-checked server-side against
  `Config.Ranks[grade]` — a client can't request more than their rank.
- **Job-locked garage** — vehicle pull is gated both client-side (menu
  only shows what a rank can pull) and server-side (`requestVehicle`
  callback re-validates job + rank before anything spawns), so it's
  locked to whichever job name `Config.PoliceJob[Config.Framework]`
  points at. `Config.GarageVehicles` sets a `minGrade` per vehicle —
  e.g. the ARV van only shows for grade 5+.
- **Movable vectors** — every interaction point (clock-in, armoury,
  garage trigger + spawn points, evidence locker, fingerprint scanner)
  is a plain `vector4`/`vector3` in `Config.Stations` — move a station
  by editing coordinates, nothing else needs touching. Add more
  stations by adding more entries to that table.
- **Evidence locker** — log an item against a case number with a
  description, and search logged evidence by case number. This is
  intentionally a case-log, not tied to any specific inventory
  resource's item-storage system (those vary a lot between servers) —
  if you want physical evidence bags moved through your inventory
  (ox_inventory/qb-inventory/etc), that's a natural extension point in
  `server/main.lua`'s evidence callbacks.
- **Fingerprint scanner** — scans the nearest player and returns their
  name plus a persistent, randomly generated fingerprint ID (stored
  once per identifier in `ukp_fingerprints`) — useful for identifying
  someone unconscious or refusing to give ID.
- **GPS tracker** — on-duty members of `Config.GPS.TrackableJobs`
  (police + ambulance by default) periodically push their position;
  on-duty members of `Config.GPS.ViewerJobs` see live blips and a unit
  list (`/gps` or F7) with a "Waypoint" button. If `wasabi_gps` is
  running and `Config.GPS.UseWasabiGPS` is true, position updates are
  handed to it instead of drawing this resource's own blips — see the
  note below on that integration.

## Requirements
- Either qb-core **or** es_extended (not both)
- oxmysql
- Optional: wasabi_gps, if you want to use it instead of the built-in
  blip fallback for GPS tracking

## Install
1. Drop the `ukp_job` folder into your resources directory.
2. Run the matching SQL file — **not both**:
   - QBCore → `install_qbcore.sql`
   - ESX → `install_esx.sql` (this one also inserts the `police` job +
     grades into `esx_jobs`/`esx_job_grades` — skip that block if you
     already have a police job and just re-grade it to match instead)
3. **QBCore only**: open `qbcore_job_snippet.lua` in this folder and
   paste the `["police"]` entry into your `qb-core/shared/jobs.lua`,
   replacing your existing police job entry (or merging the grades in
   if you want to keep other fields you've customized there).
4. Open `config.lua`:
   - Set `Config.Framework = "qbcore"` or `"esx"`.
   - Check `Config.PoliceJob` matches your actual job name for that
     framework.
   - Move `Config.Stations` coordinates to wherever you want your
     station(s) to be.
   - Adjust `Config.Ranks` loadouts, `Config.GarageVehicles`, and
     `Config.GPS` to taste — all fully commented.
   - Every item referenced in a rank's `loadout.items` (e.g.
     `"handcuffs"`, `"radio"`, `"armorplate"`) must already exist as a
     real item in your inventory system — this resource just calls
     the standard AddItem-style function, it doesn't create item
     definitions.
5. Open `fxmanifest.lua` and make sure the dependency block / locale
   shared_script matches your framework (QBCore active by default,
   ESX commented directly below it).
6. Add `ensure ukp_job` to `server.cfg`, after your framework resource,
   oxmysql, and (if used) wasabi_gps.

## GPS / wasabi_gps integration
`Config.GPS.UseWasabiGPS` is the single true/false switch:

- **`true`** (default) — on start (and again if wasabi_gps starts
  later than this resource), `server/gps.lua` calls wasabi_gps's real,
  documented exports for every job in `Config.GPS.TrackableJobs`:
  ```lua
  exports.wasabi_gps:registerJob({
      job = "police", -- or "ambulance"
      tracked = true,
      subscribers = Config.GPS.ViewerJobs,
      blipSettings = Config.GPS.BlipSettings.police,
      item = Config.GPS.Item, -- optional item-gated toggle
  })
  ```
  (Source: [docs.wasabiscripts.com — wasabi_gps Exports](https://docs.wasabiscripts.com/wasabi-scripts/free-releases/wasabi_gps/exports).)
  Once registered, wasabi_gps fully owns tracking, subscriptions, and
  blips for that job — this resource's own ping/blip code goes quiet
  for any job wasabi_gps is handling, so nothing double-tracks. On
  stop, this resource calls `exports.wasabi_gps:unregisterJob(job)` to
  clean up. `Config.GPS.Item` and `Config.GPS.BlipSettings` map
  directly to wasabi_gps's `item`/`blipSettings` options if you want
  an item-gated toggle or custom blip colors/scale per job.
- **`false`**, or wasabi_gps isn't actually installed/running — this
  resource automatically uses its own built-in ping + blip system
  instead (`client/gps.lua` / the fallback branch of
  `server/gps.lua`), with the same `TrackableJobs`/`ViewerJobs` rules.
  Zero external dependencies either way, so it's safe to leave
  `UseWasabiGPS = true` even on a server that doesn't have wasabi_gps
  — it just won't find the resource and will use the fallback.

If wasabi_gps updates their export signature in a future version,
that call is isolated to `tryRegisterWithWasabi()` near the top of
`server/gps.lua` — wrapped in `pcall`, so a breaking change there
degrades to the built-in fallback rather than erroring the resource.

## Notes on ESX schema assumptions
Same as the caveats you'd expect from any ESX-compatible script: ESX
forks vary. `server/bridge.lua` assumes identity fields
(firstname/lastname/dateofbirth) live directly on the `users` table
(esx_legacy's default schema) for the fingerprint scanner's name
lookup, and that ESX has no built-in on-duty flag (handled here with
this resource's own `ukp_duty` table instead). Both are clearly
commented in `server/bridge.lua` if your fork differs.

## Extending
- Add a third GPS viewer job (e.g. fire/rescue) by adding it to
  `Config.GPS.ViewerJobs` — no code changes needed.
- Add more stations by adding entries to `Config.Stations` — garage
  spawning automatically picks whichever station's trigger point the
  player is nearest to.
- Hook evidence into your inventory resource by extending the
  `ukp:server:addEvidence` callback in `server/main.lua`.
