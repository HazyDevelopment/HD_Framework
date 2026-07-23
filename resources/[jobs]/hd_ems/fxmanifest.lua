fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'HD'
description 'Ambulance death script — downed/bleed-out state, real EMS revive, no more instant native respawn'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

-- hd_inventory is a soft dependency in code (guarded by
-- GetResourceState checks) — the revive-item check just always passes
-- if it isn't running. spawnmanager is a hard native dependency
-- (exports.spawnmanager:setAutoSpawn) — it's one of the stock
-- FiveM default resources this server already ensures.
dependencies {
    'HD_Framework',
    'spawnmanager',
}
