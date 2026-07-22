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
local function GetLicense(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:match('^license:') then return id end
    end
    return nil
end

local function GenerateCitizenId()
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

local function DefaultCharinfo(src)
    local full = GetPlayerName(src) or 'New Citizen'
    local first, last = full:match('^(%S+)%s+(.*)$')
    if not first then first, last = full, 'Citizen' end
    return {
        firstname = first,
        lastname = last ~= '' and last or 'Citizen',
        birthdate = '01/01/2000',
        gender = 'Not specified',
        nationality = Config.DefaultCharinfo.nationality,
        phone = '07' .. tostring(math.random(100000000, 999999999)),
    }
end

-- ═══════════════════════════ LOAD / CREATE ═══════════════════════════
-- Deliberately single-character-per-license for v1 — multi-character
-- selection is a natural extension point for the phone/UI build
-- phase; hook it in here by branching on a client-picked slot instead
-- of always loading row 1.
local function LoadOrCreatePlayer(src, license)
    local row = MySQL.single.await('SELECT * FROM players WHERE license = ?', { license })

    if row then
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

    -- New citizen: create the row now so citizenid is stable from tick one.
    local citizenid = GenerateCitizenId()
    local charinfo = DefaultCharinfo(src)
    local job = {
        name = 'unemployed',
        label = Jobs['unemployed'].label,
        onduty = Jobs['unemployed'].defaultDuty,
        grade = { level = 0, name = Jobs['unemployed'].grades[0].name },
        isboss = false,
        type = Jobs['unemployed'].type,
    }
    local money = { cash = Config.StartingCash, bank = Config.StartingBank }
    local metadata = { licences = { driver = false } }
    local position = { x = Config.DefaultSpawn.x, y = Config.DefaultSpawn.y, z = Config.DefaultSpawn.z, w = Config.DefaultSpawn.w }

    MySQL.insert.await(
        'INSERT INTO players (citizenid, license, name, charinfo, job, money, metadata, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {
            citizenid, license, charinfo.firstname .. ' ' .. charinfo.lastname,
            json.encode(charinfo), json.encode(job), json.encode(money),
            json.encode(metadata), json.encode(position),
        }
    )

    print(('^2[HD_Framework]^7 New citizen created: %s (%s)'):format(citizenid, charinfo.firstname .. ' ' .. charinfo.lastname))

    return { citizenid = citizenid, license = license, charinfo = charinfo, job = job, money = money, metadata = metadata, position = position }
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
-- bootstrap and is ready to receive PlayerData (mirrors QBCore's
-- "player ready" handshake).
RegisterNetEvent('hd:server:playerReady', function()
    local src = source
    if HD.Players[src] then return end -- already loaded, ignore dupes

    local license = GetLicense(src)
    if not license then
        DropPlayer(src, 'HD_Framework: missing license identifier.')
        return
    end

    local data = LoadOrCreatePlayer(src, license)
    local Player = HD.Functions.CreatePlayerObject(src, data)
    HD.Players[src] = Player

    TriggerClientEvent('hd:client:onPlayerLoaded', src, Player.PlayerData)
    TriggerEvent('HD:Server:PlayerLoaded', Player)
    if Config.Debug then print(('^3[HD_Framework]^7 Loaded %s (%s)'):format(Player.PlayerData.citizenid, src)) end
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
