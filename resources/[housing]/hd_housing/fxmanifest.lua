fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_housing'
author 'Hazy Development'
description 'HD Framework — property ownership: starter flats claimed at character creation + a real estate job for converting any location into an ownable property'
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
    'server/realestate.lua'
}

server_exports {
    'GetAvailableStarterFlats',
    'ClaimStarterFlat',
    'GetOwnedProperty'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'HD_Framework',
    'oxmysql'
}
