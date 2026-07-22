-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | PLAYER ACTIONS
--  Every single event here re-checks IsAdmin(src) itself — the panel
--  only opening for admins client-side is a UX nicety, never the
--  real gate. PushPlayers is global (not local) so server/main.lua's
--  open handler can call it directly by src, not via TriggerEvent.
-- ═══════════════════════════════════════════════════════════════════

local function BuildPlayerList()
    local list = {}
    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        local Player = Framework.Functions.GetPlayer(src)
        if Player then
            list[#list + 1] = {
                id = src,
                name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                citizenid = Player.PlayerData.citizenid,
                job = Player.PlayerData.job.label,
                jobName = Player.PlayerData.job.name,
                ping = GetPlayerPing(src),
            }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function PushPlayers(src)
    if not IsAdmin(src) then return end
    TriggerClientEvent('hd_admin:client:players', src, BuildPlayerList())
end

RegisterNetEvent('hd_admin:server:getPlayers', function()
    PushPlayers(source)
end)

-- ═══════════════════════════ TELEPORT ═════════════════════════════════
RegisterNetEvent('hd_admin:server:teleportTo', function(targetId)
    local src = source
    if not IsAdmin(src) then return end
    local targetPed = GetPlayerPed(tonumber(targetId) or 0)
    if not targetPed or targetPed == 0 then Notify(src, 'Player not found.', 'error') return end
    local coords = GetEntityCoords(targetPed)
    TriggerClientEvent('hd_admin:client:teleport', src, { x = coords.x, y = coords.y, z = coords.z + Config.TeleportZOffset })
end)

RegisterNetEvent('hd_admin:server:bringHere', function(targetId)
    local src = source
    if not IsAdmin(src) then return end
    local myPed = GetPlayerPed(src)
    if not myPed or myPed == 0 then return end
    local coords = GetEntityCoords(myPed)
    local id = tonumber(targetId)
    if not id or not GetPlayerPed(id) or GetPlayerPed(id) == 0 then Notify(src, 'Player not found.', 'error') return end
    TriggerClientEvent('hd_admin:client:teleport', id, { x = coords.x, y = coords.y, z = coords.z + Config.TeleportZOffset })
    Notify(src, 'Brought them to you.', 'success')
end)

-- ═══════════════════════════ HEAL / FREEZE ═════════════════════════════
RegisterNetEvent('hd_admin:server:heal', function(targetId)
    local src = source
    if not IsAdmin(src) then return end
    local id = tonumber(targetId)
    if not id then return end
    TriggerClientEvent('hd_admin:client:heal', id)
    Notify(src, 'Healed.', 'success')
end)

RegisterNetEvent('hd_admin:server:toggleFreeze', function(targetId)
    local src = source
    if not IsAdmin(src) then return end
    local id = tonumber(targetId)
    if not id then return end
    TriggerClientEvent('hd_admin:client:toggleFreeze', id)
    Notify(src, 'Toggled freeze.', 'success')
end)

-- ═══════════════════════════ KICK ══════════════════════════════════════
RegisterNetEvent('hd_admin:server:kick', function(targetId, reason)
    local src = source
    if not IsAdmin(src) then return end
    local id = tonumber(targetId)
    if not id then return end
    reason = tostring(reason or ''):sub(1, 255)
    if reason == '' then reason = 'No reason given' end
    DropPlayer(id, ('Kicked by an admin.\nReason: %s'):format(reason))
    Notify(src, 'Kicked.', 'success')
end)

-- ═══════════════════════════ MONEY / JOB / ITEMS ═══════════════════════
RegisterNetEvent('hd_admin:server:giveMoney', function(targetId, account, amount)
    local src = source
    if not IsAdmin(src) then return end
    local Target = Framework.Functions.GetPlayer(tonumber(targetId))
    amount = tonumber(amount)
    if not Target or not amount or (account ~= 'cash' and account ~= 'bank') then
        Notify(src, 'Invalid target/account/amount.', 'error')
        return
    end
    if Target.Functions.AddMoney(account, amount, 'hd-admin') then
        Notify(src, ('Gave £%d %s.'):format(amount, account), 'success')
    end
end)

RegisterNetEvent('hd_admin:server:setJob', function(targetId, jobName, grade)
    local src = source
    if not IsAdmin(src) then return end
    local Target = Framework.Functions.GetPlayer(tonumber(targetId))
    if not Target then Notify(src, 'Player not found.', 'error') return end
    if not Jobs[jobName] then Notify(src, 'Unknown job.', 'error') return end
    if Target.Functions.SetJob(jobName, tonumber(grade) or 0) then
        Notify(src, ('Set job to %s.'):format(Jobs[jobName].label), 'success')
    else
        Notify(src, 'Invalid grade for that job.', 'error')
    end
end)

RegisterNetEvent('hd_admin:server:giveItem', function(targetId, itemName, amount)
    local src = source
    if not IsAdmin(src) then return end
    local id = tonumber(targetId)
    amount = tonumber(amount) or 1
    if not id or not Items[itemName] then Notify(src, 'Invalid target/item.', 'error') return end
    if GetResourceState('hd_inventory') ~= 'started' then
        Notify(src, 'hd_inventory not installed.', 'error')
        return
    end
    if exports['hd_inventory']:AddItem(id, itemName, amount) then
        Notify(src, ('Gave %dx %s.'):format(amount, Items[itemName].label), 'success')
    else
        Notify(src, "Couldn't give item (inventory full/too heavy?).", 'error')
    end
end)

-- ═══════════════════════════ AVAILABLE OPTIONS FOR THE UI ══════════════
-- Sent once on open so the NUI can populate its job/item dropdowns
-- without hardcoding either list client-side.
RegisterNetEvent('hd_admin:server:getOptions', function()
    local src = source
    if not IsAdmin(src) then return end

    local jobList = {}
    for name, def in pairs(Jobs) do
        jobList[#jobList + 1] = { name = name, label = def.label, grades = def.grades }
    end
    table.sort(jobList, function(a, b) return a.label < b.label end)

    local itemList = {}
    for name, def in pairs(Items) do
        itemList[#itemList + 1] = { name = name, label = def.label }
    end
    table.sort(itemList, function(a, b) return a.label < b.label end)

    TriggerClientEvent('hd_admin:client:options', src, { jobs = jobList, items = itemList, weather = Config.WeatherTypes })
end)
