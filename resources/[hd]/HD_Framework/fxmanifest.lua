fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'HD_Framework'
author 'Hazy Development'
description 'HD_Framework - custom UK-themed FiveM roleplay framework'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/jobs.lua',
    'shared/items.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/player.lua',
    'server/benefits.lua',
    'server/salary.lua',
    'server/commands.lua'
}

client_scripts {
    'client/main.lua',
    'client/events.lua'
}

exports {
    'GetCoreObject'
}

server_exports {
    'GetCoreObject'
}

dependency 'oxmysql'
