fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_anticheat'
author 'Hazy Development'
description 'HD AntiCheat — server-authoritative exploit detection with an admin monitoring panel'
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
    'server/dashboard.lua',
    'server/detection.lua'
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
    'HD_Framework',
    'hd_admin',
    'oxmysql'
}

-- NOT listed in `dependencies` above on purpose — that would force
-- every server running this resource to install it, even servers that
-- never touch the web dashboard's Discord webhook feature at all.
-- `screenshot-basic` (https://github.com/citizenfx/screenshot-basic)
-- is only needed if you want screenshot evidence on injection bans;
-- `ensure screenshot-basic` above `ensure hd_anticheat` in server.cfg
-- to opt in. See config.lua's Config.License block and
-- hd_anticheat_dashboard/README.md for the full setup.
