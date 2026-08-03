fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_phone'
author 'Hazy Development'
description 'HD Phone — custom smartphone NUI'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/garages.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/onboarding.lua',
    'server/appstore.lua',
    'server/contacts.lua',
    'server/messages.lua',
    'server/calls.lua',
    'server/gallery.lua',
    'server/airdrop.lua',
    'server/social.lua',
    'server/bank.lua',
    'server/mail.lua',
    'server/marketplace.lua',
    'server/notes.lua',
    'server/crypto.lua',
    'server/dating.lua',
    'server/darkchat.lua',
    'server/voicememo.lua',
    'server/garages.lua',
    'server/facetime.lua',
    'server/music.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/js/apps/*.js'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'HD_Framework',
    'oxmysql'
}
