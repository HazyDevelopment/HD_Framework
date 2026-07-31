-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | server/panic.lua
--  /panic raises a top-priority hd_dispatch call visible to both
--  police and ambulance (hd_dispatch/config.lua's 'panic' call type
--  already lists both jobs) and rings hd_radio's Panic.ogg for every
--  eligible responder — the exact same tone/flash the radio's own
--  physical panic button uses, see hd_radio/server/main.lua.
-- ═══════════════════════════════════════════════════════════════════

local PanicCooldown = {} -- [src] = GetGameTimer() of last press

RegisterNetEvent('hdpolice:server:panic', function(coords, streetLabel)
    local src = source
    local ok, Player = HDPolice.IsOnDutyPolice(src)
    if not ok then
        TriggerClientEvent('HD:Client:Notify', src, 'You must be on-duty police to use the panic button.', 'error')
        return
    end

    local now = GetGameTimer()
    if PanicCooldown[src] and (now - PanicCooldown[src]) < (Config.Panic.Cooldown * 1000) then return end
    PanicCooldown[src] = now

    if GetResourceState('hd_dispatch') ~= 'started' then
        TriggerClientEvent('HD:Client:Notify', src, 'Dispatch is not running — panic alert could not be sent.', 'error')
        return
    end

    local callsign = ('%s-%d'):format(Config.ShortName, src)
    local name = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '?', Player.PlayerData.charinfo.lastname or '?')
    local coordsTable = type(coords) == 'table' and coords or { x = 0, y = 0, z = 0 }

    local call, targets = exports['hd_dispatch']:CreateCall('panic', {
        title = 'PANIC ALERT — Officer Down',
        description = ('%s — %s'):format(callsign, name),
        coords = coordsTable,
        locationLabel = type(streetLabel) == 'string' and streetLabel:sub(1, 100) or nil,
        priority = 1,
        caller = { name = name, src = src },
    })

    if not call then return end

    if GetResourceState('hd_radio') == 'started' then
        for _, targetSrc in ipairs(targets or {}) do
            TriggerClientEvent('hd_radio:client:panicTone', targetSrc)
        end
    end

    TriggerClientEvent('HD:Client:Notify', src, 'Panic alert sent to police and ambulance.', 'success')
end)
