fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_admin'
author 'Hazy Development'
description 'HD Framework — staff admin panel (/admin): players, world, bans'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/players.lua',
    'server/world.lua',
    'server/bans.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'HD_Framework',
    'oxmysql'
}
