-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | server/armoury.lua
--  Rank-gated armoury. Every item — equipment and weapons alike — is a
--  real hd_inventory item now, issued through its documented
--  AddItem/RemoveItem server exports; nothing is auto-equipped. A
--  drawn weapon-type item sits in the officer's inventory until they
--  "Use" it themselves (hd_inventory toggles it in their hand). Every
--  draw/return request is validated here against the officer's
--  *actual* server-side job grade — the client only ever sees a
--  catalog for display.
-- ═══════════════════════════════════════════════════════════════════

HDPolice = HDPolice or {}

local function InvReady()
    return GetResourceState('hd_inventory') == 'started'
end

local Catalog -- built once Framework is ready, memoized

local function BuildCatalog()
    local catalog = {} -- name -> { name, label, minGrade, icon, isWeapon }

    for grade = 0, 15 do
        local rank = Config.Ranks[grade]
        if rank then
            for _, it in ipairs(rank.loadout.items) do
                if not catalog[it.name] then
                    local def = Framework.Shared.Items[it.name]
                    catalog[it.name] = {
                        name = it.name,
                        label = def and def.label or it.name,
                        minGrade = grade,
                        icon = Config.IconNames[it.name] or it.name,
                        isWeapon = def and def.type == 'weapon' or false,
                    }
                end
            end
        end
    end

    return catalog
end

local function InItemLoadout(rank, name)
    for _, it in ipairs(rank.loadout.items) do if it.name == name then return it end end
    return nil
end

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    while not Framework do Wait(50) end
    Catalog = BuildCatalog()

    Framework.Functions.CreateCallback('hdpolice:getArmoury', function(src, cb)
        local ok, Player = HDPolice.IsOnDutyPolice(src)
        if not ok then return cb(nil) end
        local rank = HDPolice.GetRank(Player.PlayerData.job.grade.level)
        if not rank then return cb(nil) end

        local list = {}
        for _, entry in pairs(Catalog) do
            local owned = InvReady() and exports['hd_inventory']:HasItem(src, entry.name, 1) or false
            list[#list + 1] = {
                name = entry.name, label = entry.label, icon = entry.icon, isWeapon = entry.isWeapon,
                minGrade = entry.minGrade, unlocked = entry.minGrade <= Player.PlayerData.job.grade.level,
                owned = owned,
            }
        end
        table.sort(list, function(a, b)
            if a.minGrade ~= b.minGrade then return a.minGrade < b.minGrade end
            return a.name < b.name
        end)

        cb({
            onduty = Player.PlayerData.job.onduty,
            grade = Player.PlayerData.job.grade.level,
            rankLabel = rank.label,
            isArmedResponse = rank.isArmedResponse,
            catalog = list,
        })
    end)
end)

local function GiveInventoryItem(src, it)
    if not InvReady() then return end
    if exports['hd_inventory']:HasItem(src, it.name, it.count) then return end
    local ammo = Config.WeaponAmmo[it.name]
    exports['hd_inventory']:AddItem(src, it.name, it.count, ammo and { ammo = ammo } or nil)
end

-- Weapon-type items get force-unequipped on return so a held weapon
-- can't outlive the inventory slot it came from (drop/return/etc).
local function ForceUnequipIfWeapon(src, name)
    local def = Framework.Shared.Items[name]
    if def and def.type == 'weapon' then
        TriggerClientEvent('hd_inventory:client:forceUnequipWeapon', src, name)
    end
end

RegisterNetEvent('hdpolice:server:drawLoadout', function()
    local src = source
    local ok, Player = HDPolice.IsOnDutyPolice(src)
    if not ok then return end
    local rank = HDPolice.GetRank(Player.PlayerData.job.grade.level)
    if not rank then return end

    for _, it in ipairs(rank.loadout.items) do GiveInventoryItem(src, it) end
    TriggerClientEvent('HD:Client:Notify', src, ('Issued standard %s loadout.'):format(rank.label), 'success')
end)

RegisterNetEvent('hdpolice:server:drawItem', function(name)
    local src = source
    local ok, Player = HDPolice.IsOnDutyPolice(src)
    if not ok then return end
    local rank = HDPolice.GetRank(Player.PlayerData.job.grade.level)
    if not rank then return end

    local it = InItemLoadout(rank, name)
    if not it then
        return TriggerClientEvent('HD:Client:Notify', src, 'That item is not authorised for your rank.', 'error')
    end
    GiveInventoryItem(src, it)
    local def = Framework.Shared.Items[name]
    TriggerClientEvent('HD:Client:Notify', src, ('Drawn: %s'):format(def and def.label or name), 'success')
end)

RegisterNetEvent('hdpolice:server:returnItem', function(name)
    local src = source
    local ok = HDPolice.IsOnDutyPolice(src)
    if not ok then return end
    if not InvReady() then return end

    if exports['hd_inventory']:RemoveItem(src, name, 1) then
        ForceUnequipIfWeapon(src, name)
        TriggerClientEvent('HD:Client:Notify', src, 'Returned to the armoury.', 'info')
    end
end)

RegisterNetEvent('hdpolice:server:returnLoadout', function()
    local src = source
    local ok, Player = HDPolice.IsOnDutyPolice(src)
    if not ok then return end
    local rank = HDPolice.GetRank(Player.PlayerData.job.grade.level)
    if not rank then return end

    if InvReady() then
        for _, it in ipairs(rank.loadout.items) do
            if exports['hd_inventory']:RemoveItem(src, it.name, it.count) then
                ForceUnequipIfWeapon(src, it.name)
            end
        end
    end
    TriggerClientEvent('HD:Client:Notify', src, 'Loadout returned to the armoury.', 'info')
end)
