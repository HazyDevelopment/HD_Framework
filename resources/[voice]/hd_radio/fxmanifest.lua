fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_radio'
author 'Hazy Development'
description 'HD Framework — radio channels on pma-voice, gated on the radio item, with a bundled UK-style PTT tone'
version '1.0.0'

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
    'html/js/app.js',
    'html/audio/ptt_on.wav',
    'html/audio/ptt_off.wav'
}

escrow_ignore {
    'config.lua'
}

-- pma-voice is a HARD dependency for this resource specifically — a
-- radio with no voice plugin behind it does nothing. HD_Framework and
-- qb-core are also required for the item-possession check (via
-- hd_inventory through the qb-core bridge chain).
dependencies {
    'pma-voice',
    'qb-core',
    'HD_Framework'
}
