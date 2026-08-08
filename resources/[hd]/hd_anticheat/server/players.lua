-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | PLAYERS TAB
--  Distinct from server/main.lua's BuildPlayerOverview (which feeds the
--  Overview tab and is keyed on suspicion score) — this is the general
--  staff roster: every connected player, their actual account name
--  (GetPlayerName — what FiveM's server browser and most communities
--  mean by "Steam name", regardless of which storefront identity
--  actually backs it), and kick/ban/teleport-to for any of them, for
--  any reason, not just an anticheat flag. Manual ban reuses
--  server/main.lua's own BanPlayer/manualBan — one ban path, not two.
-- ═══════════════════════════════════════════════════════════════════

local function BuildRoster()
    local list = {}
    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        local Player = Framework and Framework.Functions.GetPlayer(src)
        list[#list + 1] = {
            id = src,
            steamName = GetPlayerName(src) or ('Player %d'):format(src),
            charName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or nil,
            citizenid = Player and Player.PlayerData.citizenid or nil,
            ping = GetPlayerPing(src),
            admin = IsExemptAdmin(src),
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

RegisterNetEvent('hd_anticheat:server:getRoster', function()
    local src = source
    if not IsExemptAdmin(src) then return end
    TriggerClientEvent('hd_anticheat:client:push', src, 'roster', BuildRoster())
end)

-- ═══════════════════════════ KICK ═══════════════════════════════════════
RegisterNetEvent('hd_anticheat:server:kick', function(targetId, reason)
    local src = source
    if not IsExemptAdmin(src) then return end
    local id = tonumber(targetId)
    if not id or not GetPlayerName(id) then
        Notify(src, 'Player not found.', 'error')
        return
    end
    reason = tostring(reason or ''):sub(1, 255)
    if reason == '' then reason = 'No reason given' end
    DropPlayer(id, ('Kicked by HD AntiCheat.\nReason: %s'):format(reason))
    Notify(src, 'Kicked.', 'success')
end)

-- ═══════════════════════════ TELEPORT-TO ════════════════════════════════
-- Moves the ADMIN to the target, not the other way round — the admin is
-- already exempt from every anticheat check, so there's nothing here
-- for detection.lua to misread.
RegisterNetEvent('hd_anticheat:server:teleportTo', function(targetId)
    local src = source
    if not IsExemptAdmin(src) then return end
    local id = tonumber(targetId)
    local targetPed = id and GetPlayerPed(id)
    if not targetPed or targetPed == 0 then
        Notify(src, 'Player not found.', 'error')
        return
    end
    local coords = GetEntityCoords(targetPed)
    TriggerClientEvent('hd_anticheat:client:teleport', src, { x = coords.x, y = coords.y, z = coords.z + 1.0 })
end)
