fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_fines'
author 'Hazy Development'
description 'HD Framework — police fines / UHS treatment invoices + debt, feeding hd_society funds'
version '1.1.0'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'qb-core',
    'HD_Framework',
    'oxmysql'
}
