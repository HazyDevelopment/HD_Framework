fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_dispatch'
author 'Hazy Development'
description 'HD Framework — advanced dispatch: police/UHS emergency calls + mechanic recovery calls'
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

server_exports {
    'CreateCall'
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
