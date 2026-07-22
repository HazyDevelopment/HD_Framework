fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hazy_mdt'
author 'Hazy Development'
description 'Advanced dual-department MDT (Police / UHS) with full QBCore & ESX support'
version '2.1.3'

ui_page 'html/index.html'

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

-- IssueSystemWarrant: added on top of the original hazy_mdt so other
-- HD Framework resources (currently hd_fines, on crossing its debt
-- warrant threshold) can write a real, persistent warrant into this
-- MDT's own mdtpolice_warrants table — the same one the Command tab
-- and civilian search already use — without needing a live officer
-- session. See server/main.lua's IssueWarrantRecord for the shared
-- logic this and Handlers.setWarrant both call.
server_exports {
    'IssueSystemWarrant'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

escrow_ignore {
    'config.lua'
}

dependency 'oxmysql'
