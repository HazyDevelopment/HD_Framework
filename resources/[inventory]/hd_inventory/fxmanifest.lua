fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_inventory'
author 'Hazy Development'
description 'HD Framework — custom grid inventory (player, stashes, vehicle glovebox/trunk, ground drops)'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/vehicles.lua',
    'client/drops.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/containers.lua',
    'server/inventory.lua',
    'server/drops.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/icons.js',
    'html/js/app.js'
}

exports {
    'HasItem',
    'OpenStash'
}

server_exports {
    'HasItem',
    'AddItem',
    'RemoveItem'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'HD_Framework',
    'oxmysql'
}
