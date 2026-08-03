fx_version 'cerulean'
game 'gta5'

name 'hd_loadingscreen'
author 'Hazy Development'
description 'HD Framework — branded loading screen: logo, UK RP slideshow, YouTube background music'
version '1.0.0'

-- Loading screens are a special manifest directive, not a normal
-- client/server resource — there's no Lua runtime backing this page at
-- all, it's shown by the CitizenFX launcher itself before the game's
-- own client resources even start streaming in. That's why the
-- "config" here is html/config.js, not a .lua file — a loadscreen has
-- nowhere to run Lua.
loadscreen 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/config.js',
    'html/app.js',
    'html/images/*.png',
    'html/images/*.jpg'
}
