fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_mechanic'
author 'Hazy Development'
description 'HD Framework — mechanic shops, MOT/insurance, damage diagnostics, limp mode'
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
    'server/compliance.lua',
    'server/shop.lua',
    'server/limp.lua'
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
    'qb-core',
    'HD_Framework',
    'oxmysql'
}
