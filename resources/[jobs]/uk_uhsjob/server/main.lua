-- ===================================================================
-- server/main.lua
-- Duty, armoury (medical equipment issue), and garage (job-locked
-- vehicle pull/return).
-- ===================================================================

Bridge.HydrateESXDuty()

local function requireAmbulance(source, requireDuty)
    local player = Bridge.GetPlayer(source)
    if not player or not player.isAmbulance then return nil end
    if requireDuty == nil then requireDuty = Config.RequireOnDuty end
    if requireDuty and not player.jobOnDuty then return nil end
    return player
end

-- ===================================================================
-- Duty (clock in / out)
-- ===================================================================

RegisterNetEvent('ukhs:server:toggleDuty', function()
    local source = source
    local player = Bridge.GetPlayer(source)
    if not player or not player.isAmbulance then return end

    Bridge.SetDuty(source, not player.jobOnDuty)
    TriggerClientEvent('ukhs:client:dutyChanged', source, not player.jobOnDuty)
end)

-- ===================================================================
-- Armoury (medical equipment)
-- ===================================================================

Bridge.CreateCallback('ukhs:server:getLoadout', function(source, cb)
    local player = requireAmbulance(source)
    if not player then return cb(nil) end

    local rank = Config.Ranks[player.grade]
    if not rank then return cb(nil) end

    cb({
        rankLabel = rank.label,
        grade = player.grade,
        items = rank.loadout.items,
    })
end)

RegisterNetEvent('ukhs:server:drawLoadout', function()
    local source = source
    local player = requireAmbulance(source)
    if not player then return end

    local rank = Config.Ranks[player.grade]
    if not rank then return end

    for _, i in ipairs(rank.loadout.items) do
        Bridge.GiveItem(source, i.name, i.count)
    end

    TriggerClientEvent('ukhs:client:notify', source, ('Equipment issued for %s.'):format(rank.label), 'success')
end)

-- ===================================================================
-- Garage — vehicle list is job + rank gated server-side, not just
-- hidden client-side, so pulling a vehicle always re-checks access.
-- ===================================================================

Bridge.CreateCallback('ukhs:server:getGarageVehicles', function(source, cb)
    local player = requireAmbulance(source)
    if not player then return cb({}) end

    local list = {}
    for _, v in ipairs(Config.GarageVehicles) do
        if player.grade >= (v.minGrade or 0) then
            list[#list + 1] = { model = v.model, label = v.label }
        end
    end
    cb(list)
end)

Bridge.CreateCallback('ukhs:server:requestVehicle', function(source, cb, model)
    local player = requireAmbulance(source)
    if not player then return cb(false) end

    local allowed = false
    for _, v in ipairs(Config.GarageVehicles) do
        if v.model == model and player.grade >= (v.minGrade or 0) then
            allowed = true
            break
        end
    end

    cb(allowed)
end)
