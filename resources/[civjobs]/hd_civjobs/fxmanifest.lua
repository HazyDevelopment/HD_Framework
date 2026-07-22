fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_civjobs'
author 'Hazy Development'
description 'HD Framework — shift/contract gameplay loop for taxi, HGV, postal, waste, bus, reporter and estate agent jobs'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'HD_Framework'
}
