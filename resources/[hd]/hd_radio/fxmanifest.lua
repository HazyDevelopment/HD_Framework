fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_radio'
author 'Hazy Development'
description 'HD Framework — TETRA-style handheld radio UI on pma-voice, gated on the radio item, with power/volume/panic/P2P'
version '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/audio/PTT.ogg',
    'html/audio/SingleBleep.ogg',
    'html/audio/Panic.ogg',
    'html/audio/P2P.ogg'
}

escrow_ignore {
    'config.lua'
}

-- pma-voice is a HARD dependency for this resource specifically — a
-- radio with no voice plugin behind it does nothing. HD_Framework is
-- also required for the item-possession check (via hd_inventory,
-- called directly, no bridge in between).
dependencies {
    'pma-voice',
    'HD_Framework'
}
