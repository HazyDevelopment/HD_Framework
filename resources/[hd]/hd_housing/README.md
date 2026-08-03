# hd_housing

Property ownership: a free starter flat picked at character creation,
or a house the real estate job sells later — one `hd_properties` row
either way, same enter/exit/buzzer/furniture flow regardless of how it
was acquired.

## How it works

- **Real interiors, not placeholders.** Every property is one of the
  fixed `Config.ApartmentShells` — genuine game-shipped MP Apartment
  interiors (the same shells GTA Online itself uses), not a custom MLO
  and not an empty sky-pocket. Mid-range ones are already part of the
  base map; the high-end Eclipse Towers units stream in via `RequestIpl`
  the first time anyone enters. Interiors ship **unfurnished** — see
  Furniture below for the only things that ever appear inside one.
- **Starter flats, claimed during character creation.**
  `HD_Framework/server/characters.lua` calls this resource's exports
  directly (soft dependency — gated on
  `GetResourceState('hd_housing') == 'started'`, so the framework still
  works with housing absent, characters just get no flat):
  - `GetAvailableStarterFlats()` — only shells with `citizenid IS NULL`,
    so two characters being created at once can never race for the
    same one.
  - `ClaimStarterFlat(citizenid, flatId)` — an atomic
    `UPDATE ... WHERE id = ? AND citizenid IS NULL`; the affected-row
    count is the actual race guard, not the earlier read. The address
    shown on the character-creation picker **is** the real address of
    the shell you're claiming — nothing separate to keep in sync.
- **Only the owner has a key.** `hd_housing:server:enter` rejects
  anyone whose citizenid doesn't match the property's owner — a
  standing key, not a one-time thing. There's no separate "shared keys"
  list; instead:
- **Buzzer.** Standing at a door you don't own shows `[E] Ring
  Buzzer` instead of Enter. If the owner is actually home (inside that
  exact property right now) they get an accept/decline NUI prompt
  naming you; accepting grants you a **one-time** entry — you still
  have to walk up and press E yourself, and it's consumed the moment
  you use it, so a friend let in once doesn't keep a standing key. If
  the owner isn't home, you just get "No answer," same as a real
  intercom.
- **Placeable furniture.** `/placewardrobe` and `/placestash`, owner-only,
  while standing inside your own property — drops a real wardrobe or
  stash prop at your exact position/heading (`server/main.lua`'s
  `placeFurniture`, position read server-side off the networked ped,
  never trusted from the client). Saved to the property's row
  (`hd_properties.furniture`, a small JSON blob) and re-spawned for
  anyone who walks in from then on — owner or a buzzed-in guest.
  Interacting with the wardrobe runs `Config.WardrobeCommand`
  (`/outfits`, i.e. hd_clothing's own free wardrobe); interacting with
  the stash opens a real per-property `hd_inventory` stash via its
  documented `OpenStash` export.
- **Real estate job** (`server/realestate.lua`): `/realestate register
  [price] [label]` lists the next unclaimed non-starter shell;
  `/realestate sell [id] [server id]` assigns an unowned one to an
  online citizen (same atomic `WHERE citizenid IS NULL` guard as
  starter-flat claiming). Both gated on `Config.RealEstate.AcePermission`
  (default `hd.admin`) **or** having the `Config.RealEstate.JobName`
  job — there's no `realestate` job entry in
  `HD_Framework/shared/jobs.lua` yet, so the ACE permission is the
  working path today.

## Install

`ensure hd_housing` after `HD_Framework` in `server.cfg` (already
wired in this copy). Import `sql/hd_housing_install.sql` before
starting — `server/main.lua` checks for the `hd_properties` table on
boot and logs and bails out of seeding (without erroring the resource)
if it's missing.

## Configuring

Everything lives in `config.lua`:

- `Config.ApartmentShells` — the fixed pool of real interiors, each
  `{ id, label, size, coords, ipl?, interior? }`. `label` is the real
  address shown everywhere (character creation, brochures, blips).
- `Config.StarterFlatIds` — which shell ids are offered free at
  character creation; everything else is real-estate exclusive.
- `Config.Furniture` — the wardrobe/stash prop models + labels.
  `Config.FurnitureInteractDistance` / `Config.WardrobeCommand` (must
  match hd_clothing's own `Config.OpenCommand`).
- `Config.InteractDistance` / `Config.IplWaitMs`.
- `Config.RealEstate.AcePermission` / `Config.RealEstate.JobName`.

## Known limitations, by design for this phase

- Fixed pool of real interiors — you can't spin up an arbitrary new
  one at a coordinate the way the old sky-pocket system could; there
  are only as many properties as `Config.ApartmentShells` lists.
- One wardrobe and one stash per property, not an arbitrary furniture-
  placement system — no rotating/repositioning after the fact besides
  placing again (which just overwrites the saved spot).
- No property list/browser UI beyond the walk-up brochure — finding a
  specific property by id still means checking the database.
