# ukhs_job — United Kingdom Health Service (QBCore / ESX)

A companion resource to `uk_policejob` — ranks, an armoury (medical
equipment, no weapons), a job-locked garage, and a GPS unit tracker
(with optional wasabi_gps integration) — for either QBCore or ESX,
switched with one config line. Structurally based on the NHS's
real-world clinical/EMS rank progression, renamed United Kingdom
Health Service, with an original setup (not a reproduction of any
real NHS branding).

## Ranks (grade 0-9)
| Grade | Rank | Notes |
|---|---|---|
| 0 | Student Paramedic | Basic — read access to the command board |
| 1 | Newly Qualified Paramedic | Standard |
| 2 | Paramedic | Standard |
| 3 | Specialist Paramedic | Standard |
| 4 | Advanced Paramedic | Standard |
| 5 | Clinical Team Leader | UKHS command tier begins |
| 6 | Duty Manager | Command |
| 7 | Senior Duty Manager | Command |
| 8 | Deputy Operations Manager | Command |
| 9 | Operations Manager | Top of the job (isBoss) |

Every rank's equipment loadout and command flag are set in
`Config.Ranks` — edit freely, this is just a sensible starting point
matching your spec (0 = Student Paramedic with basic command-board
access, up through Newly Qualified Paramedic → Paramedic → Specialist
Paramedic → Advanced Paramedic → Clinical Team Leader → Duty Manager →
Senior Duty Manager → Deputy Operations Manager → Operations Manager).

## Features
- **QBCore or ESX** — `Config.Framework` in `config.lua`. Only
  `client/bridge.lua` and `server/bridge.lua` talk to the framework
  directly; everything else is framework-agnostic.
- **Equipment store (armoury)** — walks up to the equipment point,
  opens a menu showing their rank's exact medical-equipment loadout,
  "Draw full kit" gives it all in one click. Fully re-checked
  server-side against `Config.Ranks[grade]`. No weapons anywhere in
  this resource — it's a medical service.
- **Job-locked garage** — vehicle pull is gated both client-side (menu
  only shows what a rank can pull) and server-side (`requestVehicle`
  callback re-validates job + rank before anything spawns), so it's
  locked to whichever job name `Config.AmbulanceJob[Config.Framework]`
  points at. `Config.GarageVehicles` sets a `minGrade` per vehicle —
  e.g. the air ambulance only shows for grade 5+.
- **Movable vectors** — clock-in, the equipment store, and the garage
  trigger + spawn points are all plain `vector4`s in
  `Config.Stations` — move a station by editing coordinates. Add more
  stations by adding more entries to that table.
- **GPS tracker** — see the GPS section below.

## Companion design (uk_policejob)
This resource is meant to run alongside `uk_policejob`. Each resource
only ever tracks/registers **its own job** — this one handles
`"ambulance"`, the police resource handles `"police"` — while each
one's `Config.GPS.ViewerJobs` includes both jobs, so police can see
ambulance units and vice versa without either resource ever
double-registering the other's job (which would be a problem for the
wasabi_gps integration in particular, since registering the same job
from two different resources is redundant at best).

Running `ukhs_job` on its own without `uk_policejob` still works
fine — ambulance tracking/armoury/garage all function independently.
You'd just have no police-side GPS blips unless something else
provides them.

## Requirements
- Either qb-core **or** es_extended (not both)
- oxmysql
- Optional: wasabi_gps, if you want to use it instead of the built-in
  blip fallback for GPS tracking

## Install
1. Drop the `ukhs_job` folder into your resources directory.
2. Run the matching SQL file — **not both**:
   - QBCore → `install_qbcore.sql` (no custom tables needed — it's
     just a placeholder/reference file)
   - ESX → `install_esx.sql` (this one also inserts the `ambulance`
     job + grades into `esx_jobs`/`esx_job_grades` — skip that block
     if you already have an ambulance job and just re-grade it to
     match instead)
3. **QBCore only**: open `qbcore_job_snippet.lua` in this folder and
   paste the `["ambulance"]` entry into your `qb-core/shared/jobs.lua`,
   replacing your existing ambulance job entry (or merging the grades
   in if you want to keep other fields you've customized there).
4. Open `config.lua`:
   - Set `Config.Framework = "qbcore"` or `"esx"`.
   - Check `Config.AmbulanceJob` matches your actual job name for that
     framework (QBCore defaults to `"ambulance"`; some ESX servers use
     `"ems"` instead).
   - Move `Config.Stations` coordinates to wherever you want your
     station(s) to be.
   - Adjust `Config.Ranks` loadouts, `Config.GarageVehicles`, and
     `Config.GPS` to taste — all fully commented.
   - Every item referenced in a rank's `loadout.items` (e.g.
     `"bandage"`, `"defibrillator"`, `"morphine"`) must already exist
     as a real item in your inventory system — this resource just
     calls the standard AddItem-style function, it doesn't create item
     definitions.
5. Open `fxmanifest.lua` and make sure the dependency block / locale
   shared_script matches your framework (QBCore active by default,
   ESX commented directly below it).
6. Add `ensure ukhs_job` to `server.cfg`, after your framework
   resource, oxmysql, and (if used) wasabi_gps. If you're also running
   `uk_policejob`, order between the two doesn't matter — each
   registers its own job independently and retries if wasabi_gps
   starts later.

## GPS / wasabi_gps integration
`Config.GPS.UseWasabiGPS` is the single true/false switch:

- **`true`** (default) — on start (and again if wasabi_gps starts
  later than this resource), `server/gps.lua` calls wasabi_gps's real,
  documented exports for `"ambulance"`:
  ```lua
  exports.wasabi_gps:registerJob({
      job = "ambulance",
      tracked = true,
      subscribers = Config.GPS.ViewerJobs, -- {"police", "ambulance"} by default
      blipSettings = Config.GPS.BlipSettings.ambulance,
      item = Config.GPS.Item, -- optional item-gated toggle
  })
  ```
  (Source: [docs.wasabiscripts.com — wasabi_gps Exports](https://docs.wasabiscripts.com/wasabi-scripts/free-releases/wasabi_gps/exports).)
  Once registered, wasabi_gps fully owns tracking, subscriptions, and
  blips for `"ambulance"` — this resource's own ping/blip code goes
  quiet while wasabi_gps is active. On stop, this resource calls
  `exports.wasabi_gps:unregisterJob("ambulance")` to clean up.
- **`false`**, or wasabi_gps isn't actually installed/running — this
  resource automatically uses its own built-in ping + blip system
  instead, with the same `ViewerJobs` rules. Zero external
  dependencies either way, so it's safe to leave `UseWasabiGPS = true`
  even on a server that doesn't have wasabi_gps.

## Notes on ESX schema assumptions
Same as the caveats you'd expect from any ESX-compatible script: ESX
forks vary. ESX has no built-in on-duty flag, so this resource keeps
its own state in `ukhs_duty` — see `server/bridge.lua` if your ESX
setup already has its own duty system you'd rather wire in instead.

## Extending
- Add more stations by adding entries to `Config.Stations` — garage
  spawning automatically picks whichever station's trigger point the
  player is nearest to.
- If you want an evidence-locker or patient-record system for UKHS
  (equivalent to `uk_policejob`'s evidence locker), that's a natural
  extension in `server/main.lua` following the same callback pattern.

## Staff revive command
A text-chat command for **server staff** (separate from the ambulance job) to revive players. Works on QBCore and ESX.

- `/revive` — revive yourself
- `/revive [id]` — revive the player with that server ID

Permission and behaviour are configured under `Config.Revive` in `config.lua` (escrow-ignored, so it stays editable). A player may run it if they pass an ACE permission (`ukhs.revive` by default), the generic `command` ace, a QBCore admin permission level, or an ESX admin group — whichever you use. To grant via ACE, add to `server.cfg`:

```
add_ace group.admin ukhs.revive allow
```

Reviving uses native resurrect, so it works even without qb-ambulancejob / esx_ambulancejob installed; when `FireFrameworkEvents` is on it also fires those scripts' revive events to clear any downed state they track. A server export is included for admin menus: `exports.uk_uhsjob:RevivePlayer(serverId)`.
