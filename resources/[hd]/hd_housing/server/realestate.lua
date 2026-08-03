-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | REAL ESTATE JOB
--  /realestate register [price] [label?] — lists the next unclaimed
--  shell from Config.ApartmentShells that isn't one of the free
--  Config.StarterFlatIds. Real interiors are a fixed pool now (see
--  config.lua's header), so this no longer turns wherever the agent
--  happens to be standing into a property the way the old sky-pocket
--  version did — it hands out real, finite inventory instead.
--  /realestate available — shows what's left to register.
--  /realestate sell [id] [server id] — assign an unowned property to
--  a citizen. All three need Config.RealEstate.AcePermission or the
--  configured job.
-- ═══════════════════════════════════════════════════════════════════

local function IsRealEstateAgent(src)
    if IsPlayerAceAllowed(src, Config.RealEstate.AcePermission) then return true end
    local Player = Framework and Framework.Functions.GetPlayer(src)
    return Player ~= nil and Player.PlayerData.job.name == Config.RealEstate.JobName
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('HD:Client:Notify', src, msg, ntype or 'info')
end

-- Any shell not in the free-starter-flat list, that doesn't already
-- have a hd_properties row (registered or not, owned or not) — once
-- registered a shell keeps its row forever, same as a starter flat.
local function NextAvailableShell()
    for _, shell in ipairs(Config.ApartmentShells) do
        if not IsStarterId(shell.id) then
            local exists = MySQL.scalar.await('SELECT 1 FROM hd_properties WHERE id = ?', { shell.id })
            if not exists then return shell end
        end
    end
    return nil
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
        if not price then
            Notify(src, 'Usage: /realestate register [price] [label?]', 'error')
            return
        end
        local labelOverride = table.concat(args, ' ', 3)

        local shell = NextAvailableShell()
        if not shell then
            Notify(src, 'No more real-estate properties left to register.', 'error')
            return
        end

        local label = labelOverride ~= '' and labelOverride or shell.label
        local interior = shell.interior or shell.coords

        MySQL.insert.await([[
            INSERT INTO hd_properties (id, label, type, price, exterior_x, exterior_y, exterior_z, exterior_w, pocket_x, pocket_y, pocket_z, ipl)
            VALUES (?, ?, 'realestate', ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            shell.id, label, price,
            shell.coords.x, shell.coords.y, shell.coords.z, shell.coords.w,
            interior.x, interior.y, interior.z,
            shell.ipl,
        })

        Notify(src, ('Registered "%s" (%s) for £%d.'):format(label, shell.id, price), 'success')
    elseif sub == 'available' then
        local count = 0
        for _, shell in ipairs(Config.ApartmentShells) do
            if not IsStarterId(shell.id) then
                local exists = MySQL.scalar.await('SELECT 1 FROM hd_properties WHERE id = ?', { shell.id })
                if not exists then
                    count = count + 1
                    Notify(src, ('Available: %s (%s)'):format(shell.label, shell.id), 'info')
                end
            end
        end
        if count == 0 then Notify(src, 'Nothing left to register.', 'info') end
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
        Notify(src, 'Usage: /realestate register [price] [label?]  OR  /realestate available  OR  /realestate sell [id] [server id]', 'error')
    end
end, false)
