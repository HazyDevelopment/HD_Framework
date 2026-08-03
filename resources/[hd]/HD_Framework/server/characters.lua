-- ═══════════════════════════════════════════════════════════════════
--  HD_FRAMEWORK | CHARACTERS
--  Everything about picking, creating and deleting a citizenid row for
--  the connecting license lives here. server/main.lua only calls
--  SendCharacterList once a license is confirmed on playerReady —
--  nothing spawns until one of the events below fires.
-- ═══════════════════════════════════════════════════════════════════

function SendCharacterList(src, license)
    local rows = MySQL.query.await('SELECT citizenid, charinfo, job FROM players WHERE license = ? ORDER BY last_updated DESC', { license })
    local list = {}
    for _, row in ipairs(rows or {}) do
        local charinfo = json.decode(row.charinfo or '{}')
        local job = json.decode(row.job or '{}')
        list[#list + 1] = {
            citizenid = row.citizenid,
            firstname = charinfo.firstname,
            lastname = charinfo.lastname,
            jobLabel = job and job.label or 'Unemployed',
        }
    end
    TriggerClientEvent('hd:client:showCharacterSelect', src, list, Config.MaxCharacterSlots, Config.Nationalities)
end

RegisterNetEvent('hd:server:selectCharacter', function(citizenid)
    local src = source
    if HD.Players[src] then return end -- already playing, ignore dupes
    local license = GetLicense(src)
    if not license or type(citizenid) ~= 'string' then return end

    local row = MySQL.single.await('SELECT * FROM players WHERE citizenid = ? AND license = ?', { citizenid, license })
    if not row then
        TriggerClientEvent('HD:Client:Notify', src, 'That character does not belong to you.', 'error')
        SendCharacterList(src, license)
        return
    end

    FinishLoadingPlayer(src, RowToPlayerData(row, license))
end)

RegisterNetEvent('hd:server:deleteCharacter', function(citizenid)
    local src = source
    if HD.Players[src] then return end -- can't delete once already playing
    local license = GetLicense(src)
    if not license or type(citizenid) ~= 'string' then return end

    MySQL.query.await('DELETE FROM players WHERE citizenid = ? AND license = ?', { citizenid, license })
    SendCharacterList(src, license)
end)

RegisterNetEvent('hd:server:getStarterFlats', function()
    local src = source
    local flats = GetResourceState('hd_housing') == 'started' and exports['hd_housing']:GetAvailableStarterFlats() or {}
    TriggerClientEvent('hd:client:starterFlats', src, flats)
end)

local function ValidName(name)
    return type(name) == 'string' and name:match("^[%a][%a' %-]*$") ~= nil
end

-- Re-checked against Config.Nationalities itself, not just trusted
-- from whatever the NUI's dropdown sent — same "the real gate is
-- server-side" rule as every other field here.
local function ValidNationality(nationality)
    if type(nationality) ~= 'string' then return false end
    for _, n in ipairs(Config.Nationalities) do
        if n == nationality then return true end
    end
    return false
end

RegisterNetEvent('hd:server:createCharacter', function(data)
    local src = source
    if HD.Players[src] then return end
    local license = GetLicense(src)
    if not license or type(data) ~= 'table' then return end

    -- Slot limit is enforced here, server-side, regardless of what the
    -- client's own "New Character" button visibility says.
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE license = ?', { license })
    if count and count >= (Config.MaxCharacterSlots or 5) then
        TriggerClientEvent('HD:Client:Notify', src, 'You already have the maximum number of characters.', 'error')
        return
    end

    local firstname = type(data.firstname) == 'string' and data.firstname:match('^%s*(.-)%s*$'):sub(1, 30) or ''
    local lastname = type(data.lastname) == 'string' and data.lastname:match('^%s*(.-)%s*$'):sub(1, 30) or ''
    if not ValidName(firstname) or not ValidName(lastname) then
        TriggerClientEvent('HD:Client:Notify', src, 'Enter a valid first and last name.', 'error')
        return
    end

    local year, month, day = tonumber(data.dobYear), tonumber(data.dobMonth), tonumber(data.dobDay)
    local currentYear = tonumber(os.date('%Y'))
    if not year or not month or not day
        or year < 1900 or year > (currentYear - 16)
        or month < 1 or month > 12 or day < 1 or day > 31 then
        TriggerClientEvent('HD:Client:Notify', src, 'Enter a valid date of birth (must be 16 or older).', 'error')
        return
    end
    local birthdate = ('%02d/%02d/%04d'):format(month, day, year)

    local citizenid = GenerateCitizenId()
    local charinfo = {
        firstname = firstname,
        lastname = lastname,
        birthdate = birthdate,
        gender = type(data.gender) == 'string' and data.gender:sub(1, 20) or 'Not specified',
        nationality = ValidNationality(data.nationality) and data.nationality or Config.DefaultCharinfo.nationality,
        phone = GenerateUKPhoneNumber(),
    }
    local job = {
        name = 'unemployed',
        label = Jobs['unemployed'].label,
        onduty = Jobs['unemployed'].defaultDuty,
        grade = { level = 0, name = Jobs['unemployed'].grades[0].name },
        isboss = false,
        type = Jobs['unemployed'].type,
    }
    local money = { cash = Config.StartingCash, bank = Config.StartingBank }
    local metadata = { licences = { driver = false }, hunger = 100, thirst = 100 }
    local position = { x = Config.DefaultSpawn.x, y = Config.DefaultSpawn.y, z = Config.DefaultSpawn.z, w = Config.DefaultSpawn.w }

    MySQL.insert.await(
        'INSERT INTO players (citizenid, license, name, charinfo, job, money, metadata, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {
            citizenid, license, firstname .. ' ' .. lastname,
            json.encode(charinfo), json.encode(job), json.encode(money),
            json.encode(metadata), json.encode(position),
        }
    )

    if type(data.flatId) == 'string' and GetResourceState('hd_housing') == 'started' then
        exports['hd_housing']:ClaimStarterFlat(citizenid, data.flatId)
    end

    print(('^2[HD_Framework]^7 New citizen created: %s (%s)'):format(citizenid, firstname .. ' ' .. lastname))

    FinishLoadingPlayer(src, {
        citizenid = citizenid, license = license, charinfo = charinfo,
        job = job, money = money, metadata = metadata, position = position,
    }, true) -- isNew: forces the wardrobe open once this character spawns in, see client/main.lua
end)
