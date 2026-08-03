fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'HD'
description 'F1 interaction wheel — GPS/Emotes/Interactions/Work/Walkstyle/General'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

-- HD_Framework's core object + its shared ToggleHandsUp export (see
-- HD_Framework/client/main.lua) are both hard dependencies — the whole
-- Work category and the Hands Up interaction need them. hd_hud,
-- HD_vehiclekeys are soft (guarded by GetResourceState checks in
-- client/main.lua's RunGeneral) — General degrades gracefully without
-- either.
dependencies {
    'HD_Framework',
}
