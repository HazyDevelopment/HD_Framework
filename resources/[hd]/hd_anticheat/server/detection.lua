-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | DETECTION
--  Three independent checks: injection/mod-menu tripwires (instant
--  permaban, no scoring — see config.lua's header for exactly what
--  this can and can't detect), impossible movement, and taking real
--  damage without losing health. All three skip admins entirely
--  (IsExemptAdmin, server/main.lua) and skip anyone still inside their
--  post-spawn/post-teleport grace window (MovementGrace).
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════ INJECTION TRIPWIRE ════════════════════════
-- Instant and permanent, deliberately not run through the suspicion-
-- score system the movement/damage checks use below — there's no
-- legitimate reason a real client would ever fire one of these exact
-- event names against this server at all, so there's no false-positive
-- risk worth softening with a threshold.
local function FlagInjection(src, eventName)
    if IsExemptAdmin(src) then return end
    local name = GetPlayerName(src) or ('Player %d'):format(src)
    print(('^1[hd_anticheat]^7 INJECTION TRIPWIRE: %s (src %d) fired "%s" — permanently banning.'):format(name, src, eventName))

    local citizenid = nil
    local Player = Framework and Framework.Functions.GetPlayer(src)
    if Player then citizenid = Player.PlayerData.citizenid end

    MySQL.insert(
        'INSERT INTO hd_anticheat_flags (citizenid, name, type, detail, score, banned) VALUES (?, ?, ?, ?, ?, 1)',
        { citizenid, name, 'injection', eventName, 999 }
    )
    local entry = { src = src, name = name, citizenid = citizenid, type = 'injection', detail = eventName, score = 999, banned = true, at = os.time() }
    table.insert(RecentFlags, 1, entry)
    if #RecentFlags > Config.LogLimit then table.remove(RecentFlags) end
    BroadcastToOpenPanels('flag', entry)

    BanPlayer(src, ('Known injection/mod-menu signature triggered ("%s")'):format(eventName), 'injection')
end

for _, eventName in ipairs(Config.InjectionTripwireEvents) do
    RegisterNetEvent(eventName, function(...)
        FlagInjection(source, eventName)
    end)
end

-- ═══════════════════════════ MOVEMENT ══════════════════════════════════
local LastPos = {}   -- [src] = vector3
local LastCheckAt = {} -- [src] = ms

CreateThread(function()
    while true do
        Wait(Config.CheckIntervalMs)
        local now = GetGameTimer()

        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ped = GetPlayerPed(src)
            local grace = MovementGrace[src]
            -- `grace` being nil at all (not just expired) means this
            -- player's character has never actually finished loading
            -- yet — hd_anticheat:server:playerLoaded hasn't fired. Never
            -- start tracking before that point: the periodic sample here
            -- runs on its own independent timer, completely decoupled
            -- from the connect/spawn sequence, so without this gate a
            -- sample could land squarely across the pre-spawn-ped →
            -- real-saved-position jump every single legitimate
            -- connection makes and read it as a teleport hack.
            if ped and ped ~= 0 and DoesEntityExist(ped) and grace and not IsExemptAdmin(src) then
                local inGrace = now < grace
                local coords = GetEntityCoords(ped)
                local last = LastPos[src]
                local lastAt = LastCheckAt[src]

                if last and lastAt and not inGrace then
                    local elapsedS = (now - lastAt) / 1000.0
                    if elapsedS > 0 then
                        local horizDist = #(vector2(coords.x, coords.y) - vector2(last.x, last.y))
                        local totalDist = #(coords - last)
                        local inVehicle = IsPedInAnyVehicle(ped, false)

                        -- Teleport check first and always (vehicle or not)
                        -- — a jump this big can't be real movement of any
                        -- kind. On-foot speed check only applies outside a
                        -- vehicle; vehicle speeds vary too much
                        -- legitimately (tuned handling, ziptires, ramps)
                        -- to set a safe flat cap for them.
                        if totalDist > Config.TeleportDistance then
                            FlagPlayer(src, 'teleportHack', ('%.0fm in %.1fs'):format(totalDist, elapsedS))
                        elseif not inVehicle then
                            local speed = horizDist / elapsedS
                            if speed > Config.MaxOnFootSpeed then
                                FlagPlayer(src, 'speedHack', ('%.1f m/s on foot'):format(speed))
                            end
                        end
                    end
                end

                LastPos[src] = coords
                LastCheckAt[src] = now
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    LastPos[source] = nil
    LastCheckAt[source] = nil
    MovementGrace[source] = nil
end)

-- ═══════════════════════════ INVINCIBILITY ═════════════════════════════
-- CEventNetworkEntityDamage's exact argument layout has shifted across
-- FiveM builds historically and this can't be verified against a live
-- client from here — only args[1] (the victim entity) is treated as
-- load-bearing below, since that position has been stable for years
-- across every public reference using this event. Worth a real F8/print
-- dump on a live server before leaning on this further.
local PendingDamageCheck = {} -- [src] = { healthBefore = number, at = ms }

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim = args[1]
    if not victim or not DoesEntityExist(victim) or not IsPedAPlayer(victim) then return end

    local src = NetworkGetPlayerIndexFromPed(victim)
    if not src or src == -1 or IsExemptAdmin(src) then return end
    local grace = MovementGrace[src]
    if grace and GetGameTimer() < grace then return end -- e.g. fresh spawn invincibility frames

    PendingDamageCheck[src] = { healthBefore = GetEntityHealth(victim), at = GetGameTimer() }
end)

CreateThread(function()
    while true do
        Wait(100)
        local now = GetGameTimer()
        for src, pending in pairs(PendingDamageCheck) do
            if now - pending.at >= Config.DamageCheckDelayMs then
                PendingDamageCheck[src] = nil
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 and DoesEntityExist(ped) and not IsExemptAdmin(src) then
                    local healthAfter = GetEntityHealth(ped)
                    if healthAfter >= pending.healthBefore then
                        FlagPlayer(src, 'invincibility', ('health unchanged after a hit (%d)'):format(healthAfter))
                    end
                end
            end
        end
    end
end)
