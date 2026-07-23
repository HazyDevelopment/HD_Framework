# hd_ems

The "built-in death script" the ambulance job was missing. Without
this, dying meant: `resources/[gamemodes]/basic-gamemode` calls
`exports.spawnmanager:setAutoSpawn(true)`, and spawnmanager
force-respawns anyone 2 seconds after death. There was no window for
EMS to matter at all.

## How it works

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
- **Revive**: an on-duty `ambulance` officer carrying a `defibrillator`
  item (not consumed — it's equipment) can walk within
  `Config.ReviveDistance` of a downed player and hold **E** for
  `Config.RequiredHoldMs` to revive them at `Config.ReviveHealth`
  (weaker than a fresh spawn, on purpose). Every check — on-duty,
  distance, item — is re-validated server-side.
- **No timer, no self-service respawn**: a downed player stays exactly
  where they fell until a proper EMS revive or staff `/revive` — there
  is no bleed-out failsafe and no "give up and respawn" button. If
  nobody comes, they wait.
- **Staff `/revive` compatibility**: `uk_uhsjob`'s existing staff
  revive command fires `qb-ambulancejob:client:Revive` client-side as
  its own "let a downed script clear its state" hook — `hd_ems`
  listens for it and both stands the player up and clears its
  server-side bookkeeping, so staff-revive and EMS-revive never leave
  the state inconsistent with each other.

## Configuring

Everything lives in `config.lua`: `ReviveHealth`,
`ReviveDistance`/`ReviveItem`/`RequiredHoldMs`.

## Install

`ensure hd_ems` after `basic-gamemode` and `HD_Framework` in
`server.cfg` (already wired in this copy).
