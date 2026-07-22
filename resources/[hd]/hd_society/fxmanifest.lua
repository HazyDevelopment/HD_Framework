fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_society'
author 'Hazy Development'
description 'HD Framework — society/business funds, boss deposit-withdraw menu, on-duty wages drawn from the fund not thin air'
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
    'html/css/style.css',
    'html/js/app.js'
}

server_exports {
    'AddFunds',
    'RemoveFunds',
    'GetBalance'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'qb-core',
    'HD_Framework',
    'oxmysql'
}
