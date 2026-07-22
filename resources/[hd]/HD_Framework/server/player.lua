-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | PLAYER OBJECT
--  Builds the per-player table every other resource on this server
--  talks to: Player.PlayerData (read) and Player.Functions.* (write).
--  Field names deliberately mirror the QBCore player object shape
--  (PlayerData.citizenid / charinfo / job.grade.level / job.isboss,
--  Functions.AddMoney/RemoveMoney/SetJob/SetJobDuty) so hazy_mdt,
--  uk_policejob and uk_uhsjob work against it unmodified via the
--  qb-core bridge resource.
-- ═══════════════════════════════════════════════════════════════════

function HD.Functions.CreatePlayerObject(src, data)
    local Player = {}

    Player.PlayerData = {
        source = src,
        citizenid = data.citizenid,
        license = data.license,
        name = GetPlayerName(src) or (data.charinfo.firstname .. ' ' .. data.charinfo.lastname),
        charinfo = data.charinfo,
        job = data.job,
        money = data.money,
        metadata = data.metadata,
        position = data.position,
    }

    local function sync()
        TriggerClientEvent('hd:client:onPlayerDataUpdate', src, Player.PlayerData)
    end

    Player.Functions = {}

    -- ═══════════════════════ MONEY ═══════════════════════════════════
    function Player.Functions.GetMoney(account)
        return Player.PlayerData.money[account] or 0
    end

    function Player.Functions.AddMoney(account, amount, reason)
        if not Config.Accounts[account] then return false end
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        Player.PlayerData.money[account] = (Player.PlayerData.money[account] or 0) + amount
        sync()
        TriggerEvent('HD:Server:OnMoneyChange', src, account, 'add', amount, reason)
        return true
    end

    function Player.Functions.RemoveMoney(account, amount, reason)
        if not Config.Accounts[account] then return false end
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        local current = Player.PlayerData.money[account] or 0
        if current < amount then return false end
        Player.PlayerData.money[account] = current - amount
        sync()
        TriggerEvent('HD:Server:OnMoneyChange', src, account, 'remove', amount, reason)
        return true
    end

    -- ═══════════════════════ JOB ═════════════════════════════════════
    function Player.Functions.SetJob(jobName, grade)
        local jobDef = Jobs[jobName]
        if not jobDef then return false end
        grade = grade or 0
        local gradeDef = jobDef.grades[grade]
        if not gradeDef then return false end

        Player.PlayerData.job = {
            name = jobName,
            label = jobDef.label,
            type = jobDef.type,
            onduty = jobDef.defaultDuty or false,
            grade = { level = grade, name = gradeDef.name },
            isboss = gradeDef.isboss or false,
            payment = gradeDef.payment or 0,
        }
        sync()
        TriggerEvent('HD:Server:OnJobUpdate', src, Player.PlayerData.job)
        Player.Functions.Save()
        return true
    end

    -- Matches the call shape hazy_mdt already makes:
    -- P.Functions.SetJobDuty(newState)
    function Player.Functions.SetJobDuty(state)
        Player.PlayerData.job.onduty = state and true or false
        sync()
        TriggerEvent('HD:Server:OnDutyUpdate', src, Player.PlayerData.job.onduty)
        return true
    end

    -- ═══════════════════════ METADATA ════════════════════════════════
    function Player.Functions.GetMetaData(key)
        return Player.PlayerData.metadata[key]
    end

    function Player.Functions.SetMetaData(key, value)
        Player.PlayerData.metadata[key] = value
        sync()
    end

    -- ═══════════════════════ CHARINFO ════════════════════════════════
    function Player.Functions.SetCharinfo(field, value)
        if Player.PlayerData.charinfo[field] == nil then return false end
        Player.PlayerData.charinfo[field] = value
        sync()
        return true
    end

    -- ═══════════════════════ SAVE ════════════════════════════════════
    function Player.Functions.Save()
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            Player.PlayerData.position = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }
        end

        MySQL.update(
            'UPDATE players SET name = ?, charinfo = ?, job = ?, money = ?, metadata = ?, position = ? WHERE citizenid = ?',
            {
                Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                json.encode(Player.PlayerData.charinfo),
                json.encode(Player.PlayerData.job),
                json.encode(Player.PlayerData.money),
                json.encode(Player.PlayerData.metadata),
                json.encode(Player.PlayerData.position),
                Player.PlayerData.citizenid,
            }
        )
    end

    return Player
end
