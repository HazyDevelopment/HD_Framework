fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_clothing'
author 'Hazy Development'
description 'HD Framework — wardrobe (save/wear outfits) + clothing stores, standing in for qb-clothing'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
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

dependencies {
    'HD_Framework',
    'oxmysql'
}
