fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_hud'
author 'Hazy Development'
description 'HD Framework — custom player + vehicle HUD, seatbelt system'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/vehicle.lua'
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
    'HD_Framework'
}
