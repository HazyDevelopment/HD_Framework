fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'HD'
description 'Hand-written UK police job — ranks, rank-locked armoury, live GPS linked with uk_uhsjob'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/armoury.lua',
    'client/detain.lua',
}

server_scripts {
    'server/main.lua',
    'server/armoury.lua',
    'server/gps.lua',
    'server/detain.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.svg',
}

-- Same shape as uk_uhsjob's own dependency block: HD_Framework's core
-- object satisfies the calls this resource makes directly, no bridge
-- resource needed. hd_inventory is a soft dependency in code (every
-- call is guarded by GetResourceState('hd_inventory') == 'started'),
-- but listed here too since the armoury is pointless without it.
dependencies {
    'HD_Framework',
    'hd_inventory',
}
