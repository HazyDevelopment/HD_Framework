fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hd_phone'
author 'Hazy Development'
description 'HD Framework — iPhone-style smartphone with a built-in App Store: Contacts, Messages, Calls, FaceTime, AirDrop, Wire, Picta, Loopz, Garages, Bank, Mail, Marketplace, Notes, Crypto, Gallery, Settings'
version '1.3.0'

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
    'server/contacts.lua',
    'server/messages.lua',
    'server/calls.lua',
    'server/social.lua',
    'server/garages.lua',
    'server/bank.lua',
    'server/mail.lua',
    'server/marketplace.lua',
    'server/notes.lua',
    'server/crypto.lua',
    'server/gallery.lua',
    'server/settings.lua',
    'server/appstore.lua',
    'server/airdrop.lua',
    'server/facetime.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

-- SendMail(citizenid, senderLabel, subject, body) — for other resources
-- to drop a system mail into someone's inbox (a future admin broadcast,
-- a marketplace-sale receipt, etc.). Bank already uses it internally.
server_exports {
    'SendMail'
}

escrow_ignore {
    'config.lua'
}

dependencies {
    'HD_Framework',
    'oxmysql'
}
