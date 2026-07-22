fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_phone'
author 'Hazy Development'
description 'HD Framework — smartphone: Contacts, Messages, Calls, Wire, Picta, Loopz, Garages'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/garages.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/contacts.lua',
    'server/messages.lua',
    'server/calls.lua',
    'server/social.lua',
    'server/garages.lua'
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
