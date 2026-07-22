fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qb-core'
author 'Hazy Development'
description 'Compatibility bridge — forwards the qb-core export/event surface to HD_Framework. Not a duplicate framework: this resource holds no data of its own.'
version '1.0.0'

shared_scripts {
    'shared/locale.lua'
}

client_scripts {
    'client/bridge.lua'
}

server_scripts {
    'server/bridge.lua'
}

exports {
    'GetCoreObject'
}

server_exports {
    'GetCoreObject'
}

dependency 'HD_Framework'
