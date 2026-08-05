-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | SERVER CORE
--  Framework bootstrap, the admin bypass, suspicion scoring, the ban
--  action (writes to hd_admin's own hd_admin_bans table — one ban
--  list/one connect-time gate for the whole framework, not a competing
--  second one), and the NUI panel's server side. Order matters in this
--  file — everything below is a plain top-level statement executed
--  once at resource start, and a `local function` is only visible to
--  code written AFTER it, not just code that happens to run after it.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

CreateThread(function()
    Wait(1500)
    local ok = pcall(function() MySQL.query.await('SELECT 1 FROM `hd_anticheat_flags` LIMIT 1') end)
    if not ok then
        print('^1[hd_anticheat] ============================================================^7')
        print('^1[hd_anticheat] DATABASE NOT INSTALLED.^7')
        print('^1[hd_anticheat] Import sql/hd_anticheat_install.sql before starting this resource.^7')
        print('^1[hd_anticheat] ============================================================^7')
    else
        print('^2[hd_anticheat]^7 Database verified. Watching for exploits.')
    end
end)

-- ═══════════════════════════ ADMIN BYPASS ══════════════════════════════
-- A blanket exemption, not a per-tool one — a verified admin (the same
-- Discord-role check hd_admin's own panel gates on) is simply outside
-- every check this resource runs, full stop. That covers noclip,
-- spectate, godmode, and anything else the admin panel does, without
-- this resource needing to know which specific tool is active.
local AdminBypassCache = {} -- [src] = { result, expires } — same short TTL idea as hd_admin's own cache, just avoids an export call every single check tick
function IsExemptAdmin(src)
    if src == 0 then return true end
    local cached = AdminBypassCache[src]
    if cached and cached.expires > GetGameTimer() then return cached.result end
    local ok, result = pcall(function() return exports['hd_admin']:IsAdmin(src) end)
    result = ok and result == true
    AdminBypassCache[src] = { result = result, expires = GetGameTimer() + 15000 }
    return result
end

function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

local function GetCitizenId(src)
    local Player = Framework and Framework.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid or nil
end

-- ═══════════════════════════ SUSPICION SCORE ═══════════════════════════
PlayerScore = {}   -- [src] = { score = number, lastDecayAt = ms }
RecentFlags = {}   -- ring buffer for the NUI's Detections tab — [1] is newest

local function DecayScore(src)
    local st = PlayerScore[src]
    if not st then return 0 end
    local now = GetGameTimer()
    local elapsedMin = (now - st.lastDecayAt) / 60000
    if elapsedMin > 0 then
        st.score = math.max(0, st.score - elapsedMin * Config.ScoreDecayPerMinute)
        st.lastDecayAt = now
    end
    return st.score
end

-- ═══════════════════════════ BAN ═══════════════════════════════════════
-- Same table, same connect-time gate hd_admin/server/bans.lua already
-- enforces — a player banned here is blocked from ever loading a
-- character again exactly like an admin-issued ban, no separate ban
-- list for staff to check two places for. Captures Steam/Discord/Cfx.re
-- identity at ban time (the connection's gone right after, there's no
-- second chance to look these up) so the reason a player was banned is
-- never just a number — it's a specific, checkable account.
--
-- `kind` (speedHack/teleportHack/invincibility/injection/manual)
-- defaults to 'manual' and is only load-bearing for one thing: an
-- 'injection' ban is the only kind that triggers the dashboard's
-- screenshot-burst evidence capture (server/dashboard.lua) before the
-- player is dropped — see config.lua's header for why that's scoped to
-- injection specifically.
function BanPlayer(src, reason, kind)
    kind = kind or 'manual'
    local name = GetPlayerName(src) or ('Player %d'):format(src)
    local license, discordId, cfxId, steamId = nil, nil, nil, nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            if id:match('^license:') then license = id
            elseif id:match('^discord:') then discordId = id:gsub('^discord:', '')
            elseif id:match('^fivem:') then cfxId = id:gsub('^fivem:', '')
            elseif id:match('^steam:') then steamId = id:gsub('^steam:', '') end
        end
    end
    if not license then return false end

    local discordName = nil
    if discordId then
        local ok, resolved = pcall(function() return exports['hd_admin']:ResolveDiscordUsername(discordId) end)
        discordName = ok and resolved or nil
    end

    -- Only for injection bans, and only once a dashboard license with
    -- screenshot evidence enabled is actually configured (both checked
    -- inside CaptureInjectionEvidence) — blocks this coroutine for the
    -- burst window, nothing else.
    local banToken = nil
    if kind == 'injection' then
        banToken = CaptureInjectionEvidence(src)
    end

    MySQL.insert.await(
        'INSERT INTO hd_admin_bans (license, discord_id, discord_name, cfx_id, name, reason, banned_by, expires) VALUES (?, ?, ?, ?, ?, ?, ?, NULL)',
        { license, discordId, discordName, cfxId, name, reason, 'HD AntiCheat' }
    )

    local identityLines = {}
    if discordName or discordId then identityLines[#identityLines + 1] = ('Discord: %s'):format(discordName or ('ID ' .. discordId)) end
    if cfxId then identityLines[#identityLines + 1] = ('Cfx.re ID: %s'):format(cfxId) end
    local identityText = #identityLines > 0 and ('\n' .. table.concat(identityLines, '\n')) or ''

    DropPlayer(src, Config.BanMessage:format(reason) .. identityText)

    -- Optional, self-hosted only — see config.lua's header for why this
    -- resource doesn't (and can't) run a real shared ban network itself.
    if Config.GlobalBanWebhookUrl ~= '' then
        PerformHttpRequest(Config.GlobalBanWebhookUrl, function() end, 'POST',
            json.encode({ name = name, license = license, discordId = discordId, discordName = discordName, cfxId = cfxId, reason = reason, at = os.time() }),
            { ['Content-Type'] = 'application/json' }
        )
    end

    -- Optional dashboard reporting (server/dashboard.lua) — posts to
    -- whatever Discord webhook the license holder configured, with the
    -- Cfx.re/Steam/Discord identity above and any screenshot evidence
    -- just captured. A no-op if Config.License.Key is blank.
    ReportBanToDashboard({
        playerName = name, kind = kind, reason = reason,
        steamId = steamId, discordId = discordId, discordName = discordName,
        cfxId = cfxId, cfxName = name, banToken = banToken,
    })

    return true
end

-- Called by detection.lua whenever a check trips. Handles logging,
-- scoring, the ban threshold, and pushing a live update to any open
-- NUI panel — the one place all of that happens so detection.lua's
-- checks stay focused on just detecting.
function FlagPlayer(src, kind, detail)
    if IsExemptAdmin(src) then return end -- belt and braces — callers already check this themselves, but never trust a cheat to matter here twice

    if not PlayerScore[src] then PlayerScore[src] = { score = 0, lastDecayAt = GetGameTimer() } end
    DecayScore(src)
    local st = PlayerScore[src]
    st.score = st.score + (Config.Points[kind] or 25)

    local citizenid = GetCitizenId(src)
    local name = GetPlayerName(src) or ('Player %d'):format(src)
    local willBan = st.score >= Config.BanThreshold

    MySQL.insert(
        'INSERT INTO hd_anticheat_flags (citizenid, name, type, detail, score, banned) VALUES (?, ?, ?, ?, ?, ?)',
        { citizenid, name, kind, detail or '', math.floor(st.score), willBan and 1 or 0 }
    )

    local entry = { src = src, name = name, citizenid = citizenid, type = kind, detail = detail or '', score = math.floor(st.score), banned = willBan, at = os.time() }
    table.insert(RecentFlags, 1, entry)
    if #RecentFlags > Config.LogLimit then table.remove(RecentFlags) end
    BroadcastToOpenPanels('flag', entry)

    print(('^3[hd_anticheat]^7 %s (src %d) flagged: %s — %s (score %d)'):format(name, src, kind, detail or '', math.floor(st.score)))

    if willBan then
        BanPlayer(src, ('Automatic detection: %s (%s)'):format(kind, detail or 'no further detail'), kind)
        PlayerScore[src] = nil
    end
end

AddEventHandler('playerDropped', function()
    PlayerScore[source] = nil
    AdminBypassCache[source] = nil
end)

-- ═══════════════════════════ NUI PANEL ══════════════════════════════════
local OpenPanels = {} -- [src] = true while that admin's panel is open — live flag pushes only go to these, not every connected admin

function BroadcastToOpenPanels(action, data)
    for src in pairs(OpenPanels) do
        TriggerClientEvent('hd_anticheat:client:push', src, action, data)
    end
end

local function BuildPlayerOverview()
    local list = {}
    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        local Player = Framework and Framework.Functions.GetPlayer(src)
        if Player then
            DecayScore(src)
            list[#list + 1] = {
                id = src,
                name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                citizenid = Player.PlayerData.citizenid,
                ping = GetPlayerPing(src),
                admin = IsExemptAdmin(src),
                score = PlayerScore[src] and math.floor(PlayerScore[src].score) or 0,
            }
        end
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    return list
end

RegisterNetEvent('hd_anticheat:server:open', function()
    local src = source
    if not IsExemptAdmin(src) then
        Notify(src, 'No permission.', 'error')
        return
    end
    OpenPanels[src] = true
    TriggerClientEvent('hd_anticheat:client:open', src)
    TriggerClientEvent('hd_anticheat:client:push', src, 'players', BuildPlayerOverview())
    TriggerClientEvent('hd_anticheat:client:push', src, 'flags', RecentFlags)
end)

RegisterNetEvent('hd_anticheat:server:close', function()
    OpenPanels[source] = nil
end)

RegisterNetEvent('hd_anticheat:server:refresh', function()
    local src = source
    if not IsExemptAdmin(src) then return end
    TriggerClientEvent('hd_anticheat:client:push', src, 'players', BuildPlayerOverview())
end)

-- Manual ban straight from the panel — for a flagged player an admin
-- wants gone before the score naturally crosses the threshold, or any
-- other player entirely (a report, an obvious exploit an admin saw
-- directly). Re-checks IsExemptAdmin same as every other admin action
-- anywhere in this framework.
RegisterNetEvent('hd_anticheat:server:manualBan', function(targetId, reason)
    local src = source
    if not IsExemptAdmin(src) then return end
    local id = tonumber(targetId)
    if not id or not GetPlayerName(id) then
        Notify(src, 'Player not found.', 'error')
        return
    end
    local reasonText = tostring(reason or ''):sub(1, 255)
    local ok = BanPlayer(id, reasonText ~= '' and reasonText or 'Manually banned via HD AntiCheat')
    Notify(src, ok and 'Banned.' or 'Could not ban — no license identifier found.', ok and 'success' or 'error')
    PlayerScore[id] = nil
end)

RegisterNetEvent('hd_anticheat:server:clearScore', function(targetId)
    local src = source
    if not IsExemptAdmin(src) then return end
    PlayerScore[tonumber(targetId)] = nil
    Notify(src, 'Cleared.', 'success')
    TriggerClientEvent('hd_anticheat:client:push', src, 'players', BuildPlayerOverview())
end)

AddEventHandler('playerDropped', function()
    OpenPanels[source] = nil
end)

-- ═══════════════════════════ MOVEMENT GRACE (exported) ═════════════════
-- Any resource that legitimately teleports a player (hd_housing's
-- enter/exit, hd_admin's teleport tools, a future revive/respawn flow)
-- can call this first so that jump doesn't itself read as a teleport
-- hack. Not load-bearing for safety — the suspicion-score system above
-- already means one un-graced legitimate jump can't reach the ban
-- threshold by itself — this just keeps it from adding noise at all.
MovementGrace = {} -- [src] = ms timestamp until which movement checks are skipped
exports('GrantMovementGrace', function(src, ms)
    MovementGrace[tonumber(src) or 0] = GetGameTimer() + (tonumber(ms) or Config.SpawnGraceMs)
end)

RegisterNetEvent('hd_anticheat:server:playerLoaded', function()
    MovementGrace[source] = GetGameTimer() + Config.SpawnGraceMs
end)
