# Hazy Development — Advanced MDT (v2.1.0)

Dual-department Mobile Data Terminal for FiveM with full **QBCore** and **ESX** support.

- **Police MDT** — navy blue & white, prefix `mdtpolice`
- **UHS** (United Kingdom Health Services, `ambulance` job) — army green & white, prefix `mdtuhs`

The two departments are fully isolated: separate event prefixes, separate NUI data and separate database tables, so they never collide even inside the same resource.

## Requirements
- [oxmysql](https://github.com/overextended/oxmysql)
- QBCore **or** ESX (auto-detected; force via `Config.Framework`)

## Install
1. Drop the `hazy_mdt` folder into your `resources` directory.
2. **Import the SQL file for your framework** (required — tables are no longer created automatically):
   - QBCore → `sql/install_qbcore.sql`
   - ESX → `sql/install_esx.sql`
3. Add to `server.cfg` (after oxmysql and your framework):
   ```
   ensure oxmysql
   ensure hazy_mdt
   ```
4. In game: `/mdt` or **F6** (rebindable). The MDT that opens matches your job.

> On startup the server checks the tables exist. If you forgot the SQL import, the console prints a clear warning telling you which file to run.

## Features
| Tab | Police | UHS |
|---|---|---|
| Dashboard | Boss updates, live feed, callsign | Same |
| Civilian Search | Characters, history, licenses, warrants, mugshot links | Characters, history, patient records |
| Vehicle Check | Plate, registered owner, markers | — |
| Patient Records | — | Patient, staff, blood type, medications, follow-up |
| New Report / Reports | Incident, Investigation, Arrest, Traffic Stop — attach civilians, shows on their record | Medical reports, same flow |
| Command (boss only) | Post updates & training, issue warrants with reason, live-feed broadcast | Same (no warrants) |
| Settings | Callsign, Light / Dark / Custom colours, reset to default | Same |

Text colour adapts automatically to any light, dark or custom colour so writing stays visible everywhere.

## Job compatibility
Works out of the box with both the **custom UK jobs** and **stock QBCore / ESX** police & ambulance:

| Job | Boss (Command tab) | Detected via |
|---|---|---|
| Custom UK Police (`police`) | Grade 15 — Commissioner | `isboss` flag + grade name `commissioner` |
| Custom UK UHS (`ambulance`) | Grade 9 — Operations Manager | `isboss` flag + grade name `opsmanager` |
| Stock qb-policejob (`police`) | Grade 4 — Boss | `isboss` flag + grade name `boss` |
| Stock qb ambulance (`ambulance`) | Grade 4 — Boss | `isboss` flag + grade name `boss` |
| Stock esx police/ambulance | Highest grade — `boss` | grade name `boss` |

Boss detection is driven by `UseFrameworkBossFlag`, `BossGradeNames`, `BossGrades` and `BossMinGrade` in `config.lua` — all documented inline. QBCore populates `job.isboss` from the top grade's `isboss = true`, so every QBCore variant works with no extra setup. ESX has no boss flag, so ESX matches on grade name (or set `BossMinGrade`).

If your server renames the police/ambulance job, add the name to the department's `Jobs` list. The MDT never touches the job resources themselves — civilian and vehicle data is read straight from the framework tables, so it's fully independent of which police/ambulance script you run.

### Duty
The MDT's own on/off-duty toggle syncs to the framework duty flag (`SetJobDuty` on QBCore, `esx:setJobDuty` on ESX) when `Config.Duty.SyncFramework = true`, so toggling duty in the MDT lines up with the custom job's clock-in system.

## Customisation
`config.lua` is **escrow-ignored** — jobs, boss grades, themes, tabs, report types, vehicle markers, blood types, keybind, mugshot host whitelist and notifications are all editable there.

---
© Hazy Development
