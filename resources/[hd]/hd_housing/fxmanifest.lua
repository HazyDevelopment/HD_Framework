fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_housing'
author 'Hazy Development'
description 'HD Framework — property ownership: starter flats claimed at character creation, a real estate job, a buzzer for guest access, and placeable wardrobe/stash furniture'
version '1.2.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/realestate.lua'
}

server_exports {
    'GetAvailableStarterFlats',
    'ClaimStarterFlat',
    'GetOwnedProperty'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

escrow_ignore {
    'config.lua'
}

-- hd_inventory (the placeable stash's OpenStash export) and hd_clothing
-- (the placeable wardrobe's /outfits command) are soft dependencies —
-- guarded by GetResourceState/just calling the command, no hard
-- fxmanifest dependency needed since neither is required for the rest
-- of housing (entering/buzzing/owning a property) to work.
dependencies {
    'HD_Framework',
    'oxmysql'
}
