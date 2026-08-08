-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | DASHBOARD INTEGRATION
--  Everything that talks to the hosted HD AntiCheat web dashboard
--  (hd_anticheat_dashboard/ in this repo — a separate Node service,
--  not a FiveM resource) lives here: pulling this server's config
--  overrides at boot and periodically after, reporting bans (identity
--  + optional screenshot evidence) so the license's configured
--  Discord webhook gets posted, and the injection-tripwire screenshot
--  burst. Config.License.Key left blank (config.lua's default) makes
--  every function in this file a no-op — the resource then behaves
--  exactly as it always has, reading only its own local config.lua.
-- ═══════════════════════════════════════════════════════════════════

DashboardWebhookIncludeScreenshots = false

-- Last-known { plan, expiresAt, daysRemaining } from the dashboard, or
-- nil if no license is configured or the first sync hasn't landed yet.
-- Read by server/main.lua's open handler to show the NUI's Overview tab
-- a small license status line — purely informational, nothing in this
-- resource's actual detection/ban logic reads this table.
LicenseStatus = nil

-- Both Key/Secret AND DiscordGuildId are required for this to count as
-- "configured" — a Key/Secret with a blank guild ID would never
-- authenticate against the dashboard anyway (requireServerAuth now
-- requires the X-Discord-Guild-Id header), so treating it as unconfigured
-- here avoids a doomed HTTP round trip every sync interval.
local function LicenseConfigured()
    return Config.License
        and Config.License.Key ~= nil and Config.License.Key ~= ''
        and Config.License.DiscordGuildId ~= nil and Config.License.DiscordGuildId ~= ''
end

-- Turns PerformHttpRequest's callback-based API into something a
-- thread can just Wait() on. Only ever called from inside a dedicated
-- coroutine (an event handler or an explicit CreateThread) — never
-- from the resource's top-level scope — so blocking here only ever
-- delays that one coroutine, nothing else in the resource.
local function HttpAwait(method, url, body, headers, timeoutMs)
    local done, status, respBody = false, nil, nil
    PerformHttpRequest(url, function(s, b) status, respBody, done = s, b, true end, method, body or '', headers or {})
    local waited = 0
    local limit = timeoutMs or 8000
    while not done and waited < limit do
        Wait(50)
        waited = waited + 50
    end
    return status, respBody
end

-- X-Discord-Guild-Id travels on every authenticated call, not just
-- config sync — the dashboard's requireServerAuth (middleware/auth.js)
-- is the one choke point every server-facing route already goes
-- through (config sync, webhook flags, screenshot upload sessions, ban
-- reports), so binding/checking it there covers all of them at once.
local function AuthHeaders(extra)
    local h = {
        ['X-License-Key'] = Config.License.Key,
        ['X-License-Secret'] = Config.License.Secret,
        ['X-Discord-Guild-Id'] = Config.License.DiscordGuildId,
    }
    if extra then for k, v in pairs(extra) do h[k] = v end end
    return h
end

-- ═══════════════════════════ CONFIG SYNC ════════════════════════════
-- Maps the dashboard's JSON field names to this file's Config keys.
-- Anything the buyer hasn't set on the dashboard comes back as JSON
-- null and is left untouched here — see config.lua's header for why
-- that matters (no silent reset to some other default).
local CONFIG_MAP = {
    check_interval_ms = 'CheckIntervalMs',
    spawn_grace_ms = 'SpawnGraceMs',
    max_on_foot_speed = 'MaxOnFootSpeed',
    teleport_distance = 'TeleportDistance',
    damage_check_delay_ms = 'DamageCheckDelayMs',
    ban_threshold = 'BanThreshold',
    score_decay_per_minute = 'ScoreDecayPerMinute',
    ban_message = 'BanMessage',
}
local POINTS_MAP = {
    points_speed_hack = 'speedHack',
    points_teleport_hack = 'teleportHack',
    points_invincibility = 'invincibility',
}

local function ApplyRemoteConfig(data)
    for remoteKey, localKey in pairs(CONFIG_MAP) do
        if data[remoteKey] ~= nil then Config[localKey] = data[remoteKey] end
    end
    for remoteKey, pointKey in pairs(POINTS_MAP) do
        if data[remoteKey] ~= nil then Config.Points[pointKey] = data[remoteKey] end
    end
end

-- Printed once per sync (every 10 minutes) once a plan is within a
-- week of lapsing, and again the moment it actually has — a buyer
-- watching their console has real warning before remote config sync
-- and Discord ban-webhook reporting quietly stop working, not just a
-- surprise 401 on renewal day. `license` here is the `license` object
-- the dashboard's /api/server/config now returns (see
-- hd_anticheat_dashboard_cloudflare/src/routes/config.js) — absent
-- entirely on an older dashboard deploy that predates plans, in which
-- case this is silently skipped, same as any other optional field.
local function WarnIfExpiringSoon(license)
    if type(license) ~= 'table' or license.daysRemaining == nil then return end -- lifetime plan, or an older dashboard build
    if license.daysRemaining <= 7 then
        print(('^3[hd_anticheat]^7 License plan "%s" expires in %d day(s) — renew soon to keep dashboard sync and ban webhooks working.')
            :format(tostring(license.plan), license.daysRemaining))
    end
end

local function FetchWebhookFlags()
    local status, body = HttpAwait('GET', Config.License.DashboardUrl .. '/api/server/webhook-flags', '', AuthHeaders())
    if status == 200 then
        local ok, data = pcall(json.decode, body or '')
        if ok and type(data) == 'table' then
            DashboardWebhookIncludeScreenshots = data.include_screenshots == true
        end
    end
end

function SyncDashboardConfig()
    if not LicenseConfigured() then return end
    CreateThread(function()
        local status, body = HttpAwait('GET', Config.License.DashboardUrl .. '/api/server/config', '', AuthHeaders())
        local ok, data = pcall(json.decode, body or '')
        data = (ok and type(data) == 'table') and data or {}

        if status == 200 then
            ApplyRemoteConfig(data)
            WarnIfExpiringSoon(data.license)
            LicenseStatus = data.license
            print('^2[hd_anticheat]^7 Dashboard config synced.')
        elseif status == 401 and data.expired then
            -- Distinct from a generic auth failure on purpose — a lapsed
            -- 1-month/3-month plan is expected, recoverable, and NOT the
            -- same problem as a mistyped key/secret. Detection keeps
            -- running either way (this only ever affects remote config
            -- sync and Discord ban-webhook reporting) — see this file's
            -- header for why a blank/invalid license was always a no-op
            -- rather than something that disables the resource.
            print('^1[hd_anticheat] ============================================================^7')
            print(('^1[hd_anticheat] LICENSE EXPIRED: %s^7'):format(tostring(data.error)))
            print('^1[hd_anticheat] Dashboard config sync and ban webhook reporting are paused until renewed.^7')
            print('^1[hd_anticheat] Core detection/banning is unaffected — only these remote features.^7')
            print('^1[hd_anticheat] ============================================================^7')
            LicenseStatus = { expired = true }
        elseif status == 401 and data.guildMismatch then
            -- This license is already bound to a DIFFERENT Discord
            -- server than the one in this config.lua's
            -- Config.License.DiscordGuildId — either the wrong guild ID
            -- got pasted in here, or this key/secret pair was handed to
            -- a server it wasn't issued for. Not something a re-sync
            -- fixes on its own; needs the vendor to confirm/unlink it
            -- dashboard-side (see the license's owner about this).
            print('^1[hd_anticheat] ============================================================^7')
            print('^1[hd_anticheat] LICENSE BOUND TO A DIFFERENT DISCORD SERVER.^7')
            print('^1[hd_anticheat] Config.License.DiscordGuildId does not match the Discord server this license was first activated on.^7')
            print('^1[hd_anticheat] Dashboard config sync and ban webhook reporting are paused — contact whoever issued this license.^7')
            print('^1[hd_anticheat] Core detection/banning is unaffected — only these remote features.^7')
            print('^1[hd_anticheat] ============================================================^7')
            LicenseStatus = { guildMismatch = true }
        elseif status == 401 then
            print('^1[hd_anticheat]^7 Dashboard rejected this license key/secret (check Config.License in config.lua) — using local config.lua values.')
        else
            print(('^3[hd_anticheat]^7 Could not reach dashboard (status %s) — using local config.lua values.'):format(tostring(status)))
        end

        FetchWebhookFlags()
    end)
end

CreateThread(function()
    if not LicenseConfigured() then return end
    Wait(2000) -- let Framework bootstrap first, same grace main.lua's own DB check uses
    SyncDashboardConfig()
    while true do
        Wait(10 * 60 * 1000) -- re-sync every 10 minutes so dashboard edits reach a live server without a restart
        SyncDashboardConfig()
    end
end)

-- ═══════════════════════════ SCREENSHOT BURST ═══════════════════════
-- Blocks the calling coroutine for the burst window before returning —
-- callers (BanPlayer, for injection-kind bans only) are always their
-- own event-handler coroutine, never the shared movement/damage check
-- threads, so this never stalls detection for other players. Returns
-- the ban_token screenshots were filed under, or nil if capture never
-- started (no license, feature off, screenshot-basic not running).
function CaptureInjectionEvidence(src)
    if not LicenseConfigured() or not DashboardWebhookIncludeScreenshots then return nil end
    if GetResourceState('screenshot-basic') ~= 'started' then return nil end

    -- Short timeout on purpose — this sits directly on the ban path, so
    -- a dashboard that's slow or unreachable should fall back to
    -- banning without evidence quickly, not leave a cheater connected
    -- for several extra seconds waiting on a dead HTTP call.
    local status, body = HttpAwait('POST', Config.License.DashboardUrl .. '/api/server/uploads/session', '', AuthHeaders({ ['Content-Type'] = 'application/json' }), 2500)
    if status ~= 200 then return nil end
    local ok, data = pcall(json.decode, body or '')
    if not ok or type(data) ~= 'table' or not data.uploadUrl then return nil end

    TriggerClientEvent('hd_anticheat:client:captureBurst', src, data.uploadUrl, Config.ScreenshotBurstCount, Config.ScreenshotBurstDelayMs)
    -- The player is gone from GetPlayers() the instant DropPlayer runs
    -- right after this returns, so there's no "wait for the client to
    -- ack" option — this is a best-effort window sized to the burst
    -- itself plus room for the last upload to land.
    Wait((Config.ScreenshotBurstCount * Config.ScreenshotBurstDelayMs) + 900)
    return data.banToken
end

-- ═══════════════════════════ BAN REPORTING ══════════════════════════
-- Fire-and-forget on its own thread — BanPlayer doesn't wait on this,
-- the ban itself (hd_admin_bans insert + DropPlayer) has already
-- happened by the time this is called.
function ReportBanToDashboard(info)
    if not LicenseConfigured() then return end
    CreateThread(function()
        HttpAwait('POST', Config.License.DashboardUrl .. '/api/server/bans', json.encode(info), AuthHeaders({ ['Content-Type'] = 'application/json' }))
    end)
end
