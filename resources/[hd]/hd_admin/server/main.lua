-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | SERVER CORE
--  IsAdmin is the one real gate every action in players.lua/world.lua/
--  bans.lua calls independently — global on purpose, all four
--  server/*.lua files in this resource share one Lua environment.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
Jobs = {}  -- cached from Framework.Shared.Jobs — HD_Framework's shared/jobs.lua globals only exist in ITS OWN environment, not ours
Items = {} -- same deal, from Framework.Shared.Items

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
    Jobs = Framework.Shared and Framework.Shared.Jobs or {}
    Items = Framework.Shared and Framework.Shared.Items or {}
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_admin_bans` LIMIT 1') end)
    if not ok then
        print('^1[hd_admin] ============================================================^7')
        print('^1[hd_admin] DATABASE NOT INSTALLED.^7')
        print('^1[hd_admin] Import sql/hd_admin_install.sql before using /admin.^7')
        print('^1[hd_admin] ============================================================^7')
    else
        print('^2[hd_admin]^7 Database verified. Ready.')
    end
end)

-- ═══════════════════════════ DISCORD ROLE CHECK ═══════════════════════
-- See config.lua's "DISCORD ROLE ADMIN" header for the full setup —
-- this is a real, awaited HTTP call to Discord's Bot API, not a cached
-- claim; every IsAdmin(src) call site elsewhere in this resource stays
-- a plain synchronous boolean check, Citizen.Await is what makes that
-- still work despite the network round trip underneath it.
local AdminCache = {} -- [src] = { result = bool, expires = os.time() }

local function GetDiscordId(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:match('^discord:') then return id:gsub('^discord:', '') end
    end
    return nil
end

local function CheckDiscordAdminRole(src)
    if Config.DiscordBotToken == '' or Config.DiscordGuildId == '' or #Config.DiscordAdminRoleIds == 0 then
        return false
    end

    local discordId = GetDiscordId(src)
    if not discordId then return false end -- no Discord identifier at all — can't have a Discord role either

    local p = promise.new()
    PerformHttpRequest(
        ('https://discord.com/api/v10/guilds/%s/members/%s'):format(Config.DiscordGuildId, discordId),
        function(statusCode, responseText)
            if statusCode ~= 200 or not responseText then
                p:resolve(false)
                return
            end
            local ok, data = pcall(json.decode, responseText)
            if not ok or not data or not data.roles then
                p:resolve(false)
                return
            end
            for _, roleId in ipairs(data.roles) do
                for _, adminRoleId in ipairs(Config.DiscordAdminRoleIds) do
                    if roleId == adminRoleId then
                        p:resolve(true)
                        return
                    end
                end
            end
            p:resolve(false)
        end,
        'GET', '', { ['Authorization'] = 'Bot ' .. Config.DiscordBotToken }
    )
    return Citizen.Await(p)
end

function IsAdmin(src)
    if src == 0 then return true end -- server console — not a Discord identity to check, always trusted, same as every other admin gate in this framework

    local cached = AdminCache[src]
    if cached and cached.expires > os.time() then return cached.result end

    local result = CheckDiscordAdminRole(src)
    AdminCache[src] = { result = result, expires = os.time() + Config.DiscordCacheSeconds }
    return result
end

AddEventHandler('playerDropped', function()
    AdminCache[source] = nil
end)

-- The one place outside this resource that needs to know who's a real
-- admin — hd_anticheat calls this to exempt legitimate admin-tool use
-- (noclip, spectate, godmode, teleporting players around) from ever
-- being flagged. `IsAdmin` itself stays a plain global (every file in
-- this resource shares one Lua environment already); this export is
-- the only cross-resource door into it.
exports('IsAdmin', function(src) return IsAdmin(src) end)

-- Best-effort username lookup for a raw Discord snowflake ID — used at
-- ban time (hd_admin's own bans.lua and hd_anticheat) to record who a
-- banned identity actually belongs to, not just an opaque number. The
-- bot token can look up ANY Discord user's public profile this way,
-- not just guild members, so this works even for a ban that happens
-- before the bot's role-check would otherwise see them. Returns nil
-- (never errors) if no bot token is configured or the lookup fails —
-- callers already treat a nil discord_name as "not available".
function ResolveDiscordUsername(discordId)
    if not discordId or Config.DiscordBotToken == '' then return nil end
    local p = promise.new()
    PerformHttpRequest(
        ('https://discord.com/api/v10/users/%s'):format(discordId),
        function(statusCode, responseText)
            if statusCode ~= 200 or not responseText then p:resolve(nil) return end
            local ok, data = pcall(json.decode, responseText)
            if not ok or not data or not data.username then p:resolve(nil) return end
            p:resolve(data.discriminator and data.discriminator ~= '0' and (data.username .. '#' .. data.discriminator) or data.username)
        end,
        'GET', '', { ['Authorization'] = 'Bot ' .. Config.DiscordBotToken }
    )
    return Citizen.Await(p)
end
exports('ResolveDiscordUsername', function(discordId) return ResolveDiscordUsername(discordId) end)

function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

-- Client-side cache only — a UX nicety so the /admin command doesn't
-- even try to open the panel for a non-admin. Never the real gate;
-- every action below re-checks IsAdmin(src) on its own regardless of
-- what this said.
RegisterNetEvent('hd_admin:server:checkAdmin', function()
    TriggerClientEvent('hd_admin:client:isAdmin', source, IsAdmin(source))
end)

RegisterNetEvent('hd_admin:server:open', function()
    local src = source
    if not IsAdmin(src) then
        Notify(src, 'No permission.', 'error')
        return
    end
    TriggerClientEvent('hd_admin:client:open', src)
    -- PushPlayers is a global defined in server/players.lua, called
    -- directly rather than via TriggerEvent — an internal TriggerEvent
    -- doesn't reliably carry `src` through as the handler's `source`,
    -- a real bug I caught once already elsewhere in this build.
    PushPlayers(src)
end)
