# hd_housing

Property ownership: a free starter flat picked at character creation,
or a house the real estate job converts later — same `hd_properties`
row shape, same enter/exit flow either way.

## How it works

- **One table, two sources.** `hd_properties` holds every property.
  `type = 'starter'` rows are seeded from `Config.StarterFlats` on
  boot (`INSERT IGNORE`, safe to re-run); `type = 'realestate'` rows
  are created on demand by `/realestate register`. Both are
  `citizenid IS NULL` until someone owns them, and both use the exact
  same interior/furniture flow once owned.
- **Starter flats, claimed during character creation.**
  `HD_Framework/server/characters.lua` calls this resource's exports
  directly (soft dependency — both checks are gated on
  `GetResourceState('hd_housing') == 'started'`, so the framework
  still works with housing absent, characters just get no flat):
  - `GetAvailableStarterFlats()` — only flats with `citizenid IS NULL`,
    so two characters being created at once can never be offered (and
    race to claim) the same one.
  - `ClaimStarterFlat(citizenid, flatId)` — an atomic
    `UPDATE ... WHERE id = ? AND citizenid IS NULL`; the affected-row
    count is the actual race guard, not the earlier read.
- **No real interiors.** Building or importing custom MLO/apartment
  assets wasn't achievable here. Instead every property — starter or
  real-estate — gets its own private "pocket": a small, empty,
  fully self-controlled space high in the sky (each spaced 300 units
  apart on X, so no two pockets can ever overlap or collide with
  anything else in the world), furnished on entry with the same fixed
  `Config.PlainFurniture` prop list. Genuinely plain, not a decorated
  apartment — a functional placeholder. Furniture is spawned client-
  side on entry and deleted on exit, not persisted.
- **Enter/exit.** Client polls its own owned properties (pushed once
  on `HD:Client:OnPlayerLoaded` via `hd_housing:server:getOwnedProperties`)
  against nearby coords; within `Config.InteractDistance` of your own
  property's exterior door, **E** sends you in — screen fades out,
  you're teleported and frozen at the pocket, furniture spawns, fade
  back in. **BACKSPACE** while inside reverses all of it and returns
  you to the exterior door. Ownership is re-checked server-side on
  every `hd_housing:server:enter` (`property.citizenid ~=
  Player.PlayerData.citizenid` is rejected), not just trusted from the
  client's own list.
- **Real estate job** (`server/realestate.lua`): `/realestate register
  [price] [label]` turns wherever the agent is standing into a new
  `type='realestate'` property with a fresh pocket; `/realestate sell
  [id] [server id]` assigns an unowned one to an online citizen (same
  atomic `WHERE citizenid IS NULL` guard as starter-flat claiming).
  Both gated on `Config.RealEstate.AcePermission` (default `hd.admin`)
  **or** having the `Config.RealEstate.JobName` job — there's no
  `realestate` job entry in `HD_Framework/shared/jobs.lua` yet, so the
  ACE permission is the working path today; add the job later if you
  want this playable as a career instead of an admin/staff tool.

## Install

`ensure hd_housing` after `HD_Framework` in `server.cfg` (already
wired in this copy). Import `sql/hd_housing_install.sql` before
starting — `server/main.lua` checks for the `hd_properties` table on
boot and logs and bails out of seeding (without erroring the resource)
if it's missing.

## Configuring

Everything lives in `config.lua`:

- `Config.StarterFlats` — one entry per free flat: `id` (primary key,
  don't reuse/change once live), `label`, `exteriorCoords`
  (`vector4`, real street position + heading, flavour-precision is
  fine), `pocketCoords` (`vector3`, must stay unique/non-overlapping —
  existing entries are spaced 300 units apart on X).
- `Config.PlainFurniture` — the shared furniture layout every plain
  interior uses, as `{ model, offset, heading }` relative to the
  property's own pocket origin.
- `Config.InteractDistance` / `Config.InteriorFloorSize`.
- `Config.RealEstate.AcePermission` / `Config.RealEstate.JobName`.

## Known limitations, by design for this phase

- Interiors are placeholder sky-pockets, not real map assets — see
  above.
- No furniture customization — every property uses the same fixed
  `Config.PlainFurniture` layout, nothing player-placed or persisted.
- No property list/browser UI — `/realestate sell` requires already
  knowing a property's `id`; there's no in-game way to look one up
  beyond checking the database.
