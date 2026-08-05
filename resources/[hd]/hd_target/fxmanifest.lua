fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_target'
author 'Hazy Development'
description 'HD Target — hold-to-interact targeting reticle and a registration API for other resources'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
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
