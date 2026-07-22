fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'HD_vehiclekeys'
author 'Hazy Development'
description 'HD Framework — vehicle locking and shared keys, server-authoritative per plate'
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

exports {
    'IsLocked'
}

server_exports {
    'HasKeys'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'qb-core',
    'HD_Framework',
    'oxmysql'
}
