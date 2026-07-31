-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | server/armoury.lua
--  Rank-gated medical equipment store. Every draw/return request is
--  validated here against the medic's *actual* server-side job grade —
--  the client only ever sees a loadout list for display.
-- ═══════════════════════════════════════════════════════════════════

local function InvReady()
    return GetResourceState('hd_inventory') == 'started'
end

local function GiveInventoryItem(src, it)
    if not InvReady() then return end
    exports['hd_inventory']:AddItem(src, it.name, it.count)
end

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    while not Framework do Wait(50) end

    Framework.Functions.CreateCallback('hd_ems:server:getLoadout', function(src, cb)
        local ok, Player = EMS.IsOnDutyAmbulance(src)
        if not ok then return cb(nil) end

        local rank = EMS.GetRank(Player.PlayerData.job.grade.level)
        if not rank then return cb(nil) end

        cb({
            rankLabel = rank.label,
            grade = Player.PlayerData.job.grade.level,
            items = rank.loadout.items,
        })
    end)
end)

RegisterNetEvent('hd_ems:server:drawLoadout', function()
    local src = source
    local ok, Player = EMS.IsOnDutyAmbulance(src)
    if not ok then return end

    local rank = EMS.GetRank(Player.PlayerData.job.grade.level)
    if not rank then return end

    for _, it in ipairs(rank.loadout.items) do GiveInventoryItem(src, it) end
    TriggerClientEvent('HD:Client:Notify', src, ('Equipment issued for %s.'):format(rank.label), 'success')
end)
