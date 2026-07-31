fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'HD'
description 'UK Health Service — the main ambulance job: duty, ranks, armoury, garage, GPS, staff revive, /panic, and the death/revive script'
version '2.1.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/job.lua',
    'client/gps.lua',
    'client/panic.lua',
}

server_scripts {
    'server/main.lua',
    'server/job.lua',
    'server/armoury.lua',
    'server/garage.lua',
    'server/gps.lua',
    'server/revive.lua',
    'server/panic.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

-- hd_inventory is a soft dependency in code (guarded by
-- GetResourceState checks) throughout — armoury/garage/revive-item all
-- degrade open rather than error if it isn't running. spawnmanager is
-- a hard native dependency (exports.spawnmanager:setAutoSpawn) — it's
-- one of the stock FiveM default resources this server already
-- ensures. wasabi_gps is optional — GPS works without it via the
-- built-in fallback, see config.lua's GPS section. hd_dispatch and
-- hd_radio are ALSO soft dependencies (server/panic.lua guards both).
dependencies {
    'HD_Framework',
    'spawnmanager',
}
