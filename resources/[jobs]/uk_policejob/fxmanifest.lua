fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Hazy Development'
description 'United Kingdom Police — job, armoury, garage, evidence, fingerprint, GPS (QBCore/ESX)'
version '1.0.0+20260719.afaf2677'

shared_scripts {
    'config.lua',

    -- QBCore locale (ACTIVE — matches Config.Framework = "qbcore" in config.lua)
    '@qb-core/shared/locale.lua',

    -- ESX locale — uncomment this AND comment out the qb-core line
    -- above if you set Config.Framework = "esx" in config.lua.
    -- '@es_extended/locale.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/main.lua',
    'client/gps.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua',
    'server/gps.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

-- ===================================================================
-- Escrow
-- If you ever wrap this resource with FiveM's asset-escrow protection
-- (Keymaster), config.lua is excluded from escrow so it always ships
-- in plaintext and stays editable by server owners even though the
-- rest of the resource is locked. Add more paths here (comma
-- separated) if you escrow-protect this and want other files —
-- e.g. qbcore_job_snippet.lua — to stay editable too.
-- ===================================================================
escrow_ignore {
    'config.lua'
}

-- ===================================================================
-- Dependencies
-- Only ONE framework should be running on your server. Keep the block
-- matching Config.Framework active, comment out the other. wasabi_gps
-- is optional — this resource works without it (built-in blip
-- fallback) but will use it automatically if present and
-- Config.GPS.UseWasabiGPS is true.
-- ===================================================================

-- QBCore (ACTIVE by default — Config.Framework = "qbcore")
dependencies {
    'qb-core',
    'oxmysql'
}

-- ESX — uncomment this block and comment out the QBCore block above
-- if Config.Framework = "esx" in config.lua.
-- dependencies {
--     'es_extended',
--     'oxmysql'
-- }

dependency '/assetpacks'