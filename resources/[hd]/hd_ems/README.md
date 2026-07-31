# hd_ems

The full UK Health Service ambulance job for HD_Framework — duty,
ranks, a rank-locked equipment store, a vehicle garage, live GPS
(shared with `hd_policejob`), a staff `/revive` command, and the
"built-in death script" the ambulance job was missing. This used to be
two resources (`hd_ems` for the death script, `uk_uhsjob` for
everything else) — they're merged here into one.

Without the death script half, dying meant:
`resources/[gamemodes]/basic-gamemode` calls
`exports.spawnmanager:setAutoSpawn(true)`, and spawnmanager
force-respawns anyone 2 seconds after death. There was no window for
EMS to matter at all.

## How it works

### Duty, armoury, garage, GPS

- **Clock in/out** at Pillbox Hill Medical Center ([E] at the station).
  Duty is required (`Config.RequireOnDuty`) to use the armoury, pull a
  garage vehicle, or show up on GPS.
- **Equipment store**: rank-gated medical loadout (`Config.Ranks`,
  grades 0-9, matching `HD_Framework/shared/jobs.lua`'s `ambulance`
  entry exactly) — bandages, painkillers, medkits, splints,
  defibrillators, oxygen masks, morphine, stretchers, surgical/trauma
  kits. Every draw is validated server-side against the medic's actual
  job grade.
- **Garage**: rank-gated vehicle list (`Config.GarageVehicles`), pull
  the nearest free spawn point at the station, return the nearest
  department vehicle from anywhere.
- **GPS** (**F7**): live on-duty ambulance + police units on one map,
  shared with `hd_policejob` via a common client-side blip renderer.
  Hands off to `wasabi_gps` automatically if it's installed
  (`Config.GPS.UseWasabiGPS`), otherwise uses a built-in ping/blip
  fallback — zero external dependencies either way.

### Death & revive

- **On death** (`baseevents:onPlayerDied`): the ped is resurrected
  *in place* immediately (`NetworkResurrectLocalPlayer`), frozen
  (`FreezeEntityPosition`) exactly where it fell, and locked into a
  writhing/downed animation under script control, health held at 1,
  invincible. From the game's own point of view the ped is never
  actually fatally injured for more than a frame — which is exactly
  what stops the native wasted screen and spawnmanager's auto-respawn
  from ever triggering. `client/main.lua` calls
  `exports.spawnmanager:setAutoSpawn(false)` immediately at script
  start (spawnmanager is a hard dependency, so it's guaranteed already
  loaded) and re-asserts it every 100ms for the first ~10 seconds,
  since `basic-gamemode` also flips it on inside its own
  `onClientMapStart` handler and that event's exact firing order
  relative to this resource's own startup isn't guaranteed — the
  re-assertion wins the race unconditionally regardless of how it
  plays out.
- **Downed state**: movement/attack/vehicle controls disabled, a
  status overlay shows elapsed time. `hd_dispatch` already auto-opens
  an EMS call the instant this happens — it has its own client hook
  on `baseevents:onPlayerDied` (`hd_dispatch:server:playerDowned`),
  nothing needed to change there.
- **Revive**: an on-duty `ambulance` medic carrying a `defibrillator`
  item (not consumed — it's equipment) can walk within
  `Config.ReviveDistance` of a downed player and hold **E** for
  `Config.RequiredHoldMs` to revive them at `Config.ReviveHealth`
  (weaker than a fresh spawn, on purpose). Every check — on-duty,
  distance, item — is re-validated server-side.
- **No timer, no self-service respawn**: a downed player stays exactly
  where they fell until a proper EMS revive or staff `/revive` — there
  is no bleed-out failsafe and no "give up and respawn" button. If
  nobody comes, they wait.
- **Staff `/revive [id]`**: ACE-gated (`ukhs.revive`, or the generic
  `command` ACE) — see `Config.Revive`. Clears this resource's own
  downed bookkeeping directly and reuses the exact same
  `hd_ems:client:revived` event an in-person EMS revive fires, so both
  paths land through identical client-side code.

## Configuring

Everything lives in `config.lua`: ranks/loadouts, stations, garage
fleet, GPS, staff revive permissions, and the death-script tuning
(`ReviveHealth`, `ReviveDistance`/`ReviveItem`/`RequiredHoldMs`).

## Install

`ensure hd_ems` after `basic-gamemode` and `HD_Framework` in
`server.cfg` (already wired in this copy). No SQL needed — duty and
rank live on `HD_Framework`'s own `job` column.
