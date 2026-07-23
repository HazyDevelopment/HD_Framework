-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | SERVER CORE
--  Owns player identification, loading, saving and the live in-memory
--  Player table. Everything else (jobs, money, metadata) lives on the
--  Player object built in server/player.lua.
-- ═══════════════════════════════════════════════════════════════════

HD = {}
HD.Players = {}          -- [source] = Player object (see server/player.lua)
HD.Shared = { Jobs = Jobs, Items = Items }
HD.Functions = {}

-- ═══════════════════════════ CORE OBJECT EXPORT ═════════════════════
-- exports['HD_Framework']:GetCoreObject() is the only way to reach the
-- core — every HD resource in this server calls it directly, no
-- qb-core (or other framework-name) bridge in between.
exports('GetCoreObject', function() return HD end)

-- ═══════════════════════════ DB VERIFY ═══════════════════════════════
CreateThread(function()
    Wait(1000)
    local ok = pcall(function()
        MySQL.query.await('SELECT 1 FROM `players` LIMIT 1')
    end)
    if not ok then
        print('^1[HD_Framework] ============================================================^7')
        print('^1[HD_Framework] DATABASE NOT INSTALLED.^7')
        print('^1[HD_Framework] Import sql/hd_framework_install.sql before starting the server.^7')
        print('^1[HD_Framework] ============================================================^7')
    else
        print('^2[HD_Framework]^7 Database verified. Ready.')
    end
end)

-- ═══════════════════════════ IDENTIFIER HELPERS ═════════════════════
-- Global (not local) — server/characters.lua needs both too.
function GetLicense(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:match('^license:') then return id end
    end
    return nil
end

function GenerateCitizenId()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' -- no 0/O/1/I ambiguity
    local id
    repeat
        local part = ''
        for _ = 1, 8 do
            local i = math.random(1, #chars)
            part = part .. chars:sub(i, i)
        end
        id = (Config.CitizenIdPrefix or '') .. part
        local exists = MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { id })
    until not exists
    return id
end

-- Turns a `players` row into the same in-memory shape CreatePlayerObject
-- expects — used by server/characters.lua on both select and create.
function RowToPlayerData(row, license)
    return {
        citizenid = row.citizenid,
        license = license,
        charinfo = json.decode(row.charinfo or '{}'),
        job = json.decode(row.job or '{}'),
        money = json.decode(row.money or '{}'),
        metadata = json.decode(row.metadata or '{}'),
        position = json.decode(row.position or 'null'),
    }
end

-- Shared tail end of both selectCharacter and createCharacter — builds
-- the live Player object and tells the client it can finally spawn in.
function FinishLoadingPlayer(src, data)
    local Player = HD.Functions.CreatePlayerObject(src, data)
    HD.Players[src] = Player
    TriggerClientEvent('hd:client:onPlayerLoaded', src, Player.PlayerData)
    TriggerEvent('HD:Server:PlayerLoaded', Player)
    if Config.Debug then print(('^3[HD_Framework]^7 Loaded %s (%s)'):format(Player.PlayerData.citizenid, src)) end
end

-- ═══════════════════════════ CONNECT / DROP ══════════════════════════
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    local license = GetLicense(src)
    if not license then
        deferrals.done('HD_Framework: no valid license identifier found. Are you in offline mode?')
        return
    end
    deferrals.done()
end)

-- Fired by client/main.lua once the client has finished its own
-- bootstrap and is ready to receive data (mirrors QBCore's "player
-- ready" handshake). No character is loaded yet — this only sends the
-- character list so the client can show character select. Actually
-- loading a Player object happens in server/characters.lua, once the
-- player has picked or created one.
RegisterNetEvent('hd:server:playerReady', function()
    local src = source
    if HD.Players[src] then return end -- already loaded, ignore dupes

    local license = GetLicense(src)
    if not license then
        DropPlayer(src, 'HD_Framework: missing license identifier.')
        return
    end

    SendCharacterList(src, license)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local Player = HD.Players[src]
    if not Player then return end
    Player.Functions.Save()
    TriggerEvent('HD:Server:PlayerDropped', Player)
    HD.Players[src] = nil
end)

-- ═══════════════════════════ CORE FUNCTIONS ══════════════════════════
function HD.Functions.GetPlayer(src)
    return HD.Players[src]
end

function HD.Functions.GetPlayerByCitizenId(citizenid)
    for _, Player in pairs(HD.Players) do
        if Player.PlayerData.citizenid == citizenid then return Player end
    end
    return nil
end

function HD.Functions.GetPlayers()
    local sources = {}
    for src in pairs(HD.Players) do sources[#sources + 1] = src end
    return sources
end

function HD.Functions.GetQBPlayers()
    return HD.Players -- alias for QBCore-ecosystem code expecting QBCore.Functions.GetQBPlayers()
end

-- ═══════════════════════════ CALLBACKS ═══════════════════════════════
-- Standard QBCore.Functions.CreateCallback/TriggerCallback pattern —
-- a real gap this had until a live boot test against uk_uhsjob (a
-- genuine QBCore-ecosystem resource) surfaced it: its bridge calls
-- Framework.Functions.CreateCallback expecting it to exist like every
-- other Functions.* method. Event names match real QBCore's own
-- convention exactly, so any off-the-shelf QBCore resource using this
-- pattern works without modification.
local Callbacks = {}

function HD.Functions.CreateCallback(name, cb)
    Callbacks[name] = cb
end

RegisterNetEvent('QBCore:Server:TriggerCallback', function(name, requestId, ...)
    local src = source
    local cb = Callbacks[name]
    if not cb then return end
    cb(src, function(...)
        TriggerClientEvent('QBCore:Client:TriggerCallback', src, requestId, ...)
    end, ...)
end)

-- ═══════════════════════════ AUTO-SAVE ═══════════════════════════════
CreateThread(function()
    while true do
        Wait((Config.AutoSaveIntervalMinutes or 5) * 60000)
        for _, Player in pairs(HD.Players) do
            Player.Functions.Save()
        end
        if Config.Debug then print('^3[HD_Framework]^7 Auto-save complete.') end
    end
end)
