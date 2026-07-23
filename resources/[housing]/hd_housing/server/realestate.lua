-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | REAL ESTATE JOB
--  /realestate register [price] [label] — turn wherever you're
--  standing into a purchasable property with a plain interior. It's
--  the exact same hd_properties row shape as a starter flat, just
--  type='realestate' with a price and no owner yet.
--  /realestate sell [id] [server id] — assign an unowned property to
--  a citizen. Both commands need Config.RealEstate.AcePermission or
--  the configured job.
-- ═══════════════════════════════════════════════════════════════════

local function IsRealEstateAgent(src)
    if IsPlayerAceAllowed(src, Config.RealEstate.AcePermission) then return true end
    local Player = Framework and Framework.Functions.GetPlayer(src)
    return Player ~= nil and Player.PlayerData.job.name == Config.RealEstate.JobName
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

-- Every real-estate-registered property gets its own pocket, stacked
-- well above the starter flats and spaced the same 300 units apart so
-- neither set can ever collide with the other.
local function NextPocketCoords()
    local count = MySQL.scalar.await("SELECT COUNT(*) FROM hd_properties WHERE type = 'realestate'") or 0
    return vector3(count * 300.0, 300.0, 1000.0)
end

RegisterCommand('realestate', function(source, args)
    local src = source
    if src ~= 0 and not IsRealEstateAgent(src) then
        Notify(src, 'You do not have permission to use this.', 'error')
        return
    end

    local sub = args[1]
    if sub == 'register' then
        local price = tonumber(args[2])
        local label = table.concat(args, ' ', 3)
        if not price or label == '' then
            Notify(src, 'Usage: /realestate register [price] [label]', 'error')
            return
        end

        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local id = 're_' .. tostring(math.random(100000, 999999))
        local pocket = NextPocketCoords()

        MySQL.insert.await([[
            INSERT INTO hd_properties (id, label, type, price, exterior_x, exterior_y, exterior_z, exterior_w, pocket_x, pocket_y, pocket_z)
            VALUES (?, ?, 'realestate', ?, ?, ?, ?, ?, ?, ?, ?)
        ]], { id, label, price, coords.x, coords.y, coords.z, heading, pocket.x, pocket.y, pocket.z })

        Notify(src, ('Registered "%s" (%s) for £%d.'):format(label, id, price), 'success')
    elseif sub == 'sell' then
        local propertyId = args[2]
        local targetId = tonumber(args[3])
        if not propertyId or not targetId then
            Notify(src, 'Usage: /realestate sell [id] [server id]', 'error')
            return
        end

        local Target = Framework and Framework.Functions.GetPlayer(targetId)
        if not Target then
            Notify(src, 'That player is not online.', 'error')
            return
        end

        local row = MySQL.single.await('SELECT * FROM hd_properties WHERE id = ?', { propertyId })
        if not row then
            Notify(src, 'No property with that id.', 'error')
            return
        end
        if row.citizenid then
            Notify(src, 'That property is already owned.', 'error')
            return
        end

        local affected = MySQL.update.await('UPDATE hd_properties SET citizenid = ? WHERE id = ? AND citizenid IS NULL', { Target.PlayerData.citizenid, propertyId })
        if not affected or affected == 0 then
            Notify(src, 'Someone else just bought that.', 'error')
            return
        end

        Notify(src, ('Sold "%s" to %s.'):format(row.label, Target.PlayerData.citizenid), 'success')
        Notify(targetId, ('You now own "%s".'):format(row.label), 'success')
    else
        Notify(src, 'Usage: /realestate register [price] [label]  OR  /realestate sell [id] [server id]', 'error')
    end
end, false)
