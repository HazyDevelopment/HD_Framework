-- ═══════════════════════════════════════════════════════════════════
--  HAZY DEVELOPMENT | ADVANCED MDT | SERVER
-- ═══════════════════════════════════════════════════════════════════

local Framework, FrameworkName = nil, nil

CreateThread(function()
    if Config.Framework == 'hd' or (Config.Framework == 'auto' and GetResourceState('HD_Framework') == 'started') then
        FrameworkName = 'hd'
        Framework = exports['HD_Framework']:GetCoreObject()
    elseif Config.Framework == 'esx' or (Config.Framework == 'auto' and GetResourceState('es_extended') == 'started') then
        FrameworkName = 'esx'
        Framework = exports['es_extended']:getSharedObject()
    end
end)

-- ─────────────────────────── Duty state ───────────────────────────
-- OnDuty[prefix][src] = true. Kept in memory; cleared on drop.
local OnDuty = {}
for _, dept in pairs(Config.Departments) do OnDuty[dept.Prefix] = {} end

local function GetOnDutyTargets(dept)
    if not Config.Duty.RequireDutyToBroadcast then return -1 end
    local list = {}
    for src, on in pairs(OnDuty[dept.Prefix]) do
        if on then list[#list + 1] = src end
    end
    return list
end

-- ─────────────────────────── Discord webhooks ─────────────────────
local function SendWebhook(url, embed)
    if type(url) ~= 'string' or url == '' or not url:match('^https?://') then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = Config.WebhookName,
        avatar_url = (Config.WebhookAvatar ~= '' and Config.WebhookAvatar) or nil,
        embeds = { embed }
    }), { ['Content-Type'] = 'application/json' })
end

local function WebhookFor(deptKey, kind)
    local hooks = Config.Webhooks[deptKey]
    return hooks and hooks[kind] or ''
end

-- ─────────────────────────── DB install check ─────────────────────
-- Tables are NOT created automatically. The server owner must import
-- the matching SQL file first:
--   • QBCore  → sql/install_qbcore.sql
--   • ESX     → sql/install_esx.sql
-- This block only VERIFIES the tables exist and warns if they don't.
CreateThread(function()
    Wait(2000)
    local missing = {}
    for _, dept in pairs(Config.Departments) do
        local ok = pcall(function()
            MySQL.query.await('SELECT 1 FROM `' .. dept.Prefix .. '_updates` LIMIT 1')
        end)
        if not ok then missing[#missing + 1] = dept.Prefix end
    end
    if #missing > 0 then
        print('^1[hazy_mdt] ============================================================^7')
        print('^1[hazy_mdt] DATABASE NOT INSTALLED.^7')
        print('^1[hazy_mdt] Import the SQL file for your framework before using the MDT:^7')
        print('^3[hazy_mdt]   QBCore -> sql/install_qbcore.sql^7')
        print('^3[hazy_mdt]   ESX    -> sql/install_esx.sql^7')
        print(('^1[hazy_mdt] Missing tables for prefix(es): %s^7'):format(table.concat(missing, ', ')))
        print('^1[hazy_mdt] ============================================================^7')
    else
        print('^2[hazy_mdt]^7 Database verified (prefixes: mdtpolice, mdtuhs)')
    end
end)

-- ─────────────────────────── Player helpers ───────────────────────
local function GetChar(src)
    if FrameworkName == 'hd' then
        local P = Framework.Functions.GetPlayer(src)
        if not P then return nil end
        return {
            identifier = P.PlayerData.citizenid,
            name = P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname,
            job = P.PlayerData.job.name,
            grade = P.PlayerData.job.grade and P.PlayerData.job.grade.level or 0,
            gradeName = P.PlayerData.job.grade and P.PlayerData.job.grade.name or '',
            isboss = P.PlayerData.job.isboss or false
        }
    elseif FrameworkName == 'esx' then
        local P = Framework.GetPlayerFromId(src)
        if not P then return nil end
        return {
            identifier = P.identifier,
            name = P.getName(),
            job = P.job.name,
            grade = P.job.grade or 0,
            gradeName = P.job.grade_name or '',
            isboss = false
        }
    end
end

local function HasDeptAccess(char, dept)
    if not char then return false end
    for _, j in ipairs(dept.Jobs) do
        if char.job == j then return true end
    end
    return false
end

local function IsBoss(char, dept)
    if not char then return false end
    if dept.UseFrameworkBossFlag and char.isboss then return true end
    for _, g in ipairs(dept.BossGrades or {}) do
        if char.grade == g then return true end
    end
    local gname = tostring(char.gradeName or ''):lower()
    for _, n in ipairs(dept.BossGradeNames or {}) do
        if gname == tostring(n):lower() then return true end
    end
    if dept.BossMinGrade and char.grade >= dept.BossMinGrade then return true end
    return false
end

local function GetCallsign(prefix, identifier)
    local row = MySQL.single.await('SELECT callsign FROM `' .. prefix .. '_settings` WHERE identifier = ?', { identifier })
    return row and row.callsign or ''
end

local function UrlAllowed(url)
    if type(url) ~= 'string' or not url:match('^https?://') then return false end
    if #Config.MugshotWhitelist == 0 then return true end
    local host = url:match('^https?://([^/]+)')
    if not host then return false end
    for _, h in ipairs(Config.MugshotWhitelist) do
        if host == h then return true end
    end
    return false
end

-- ─────────────────────────── Civilian lookups ─────────────────────
local function SearchCivilians(term)
    term = '%' .. (term or '') .. '%'
    if FrameworkName == 'hd' then
        local rows = MySQL.query.await([[
            SELECT citizenid, charinfo, metadata FROM players
            WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
               OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ',
                         JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
            LIMIT ?]], { term, term, term, Config.MaxSearchResults }) or {}
        local out = {}
        for _, r in ipairs(rows) do
            local ci = json.decode(r.charinfo) or {}
            local md = json.decode(r.metadata or '{}') or {}
            local lic = {}
            if md.licences then
                for k, v in pairs(md.licences) do
                    if v then lic[#lic + 1] = k end
                end
            end
            out[#out + 1] = {
                citizenid = r.citizenid,
                name = (ci.firstname or '') .. ' ' .. (ci.lastname or ''),
                dob = ci.birthdate or 'Unknown',
                phone = ci.phone or '',
                licenses = lic
            }
        end
        return out
    elseif FrameworkName == 'esx' then
        local rows = MySQL.query.await([[
            SELECT identifier, firstname, lastname, dateofbirth FROM users
            WHERE firstname LIKE ? OR lastname LIKE ? OR CONCAT(firstname, ' ', lastname) LIKE ?
            LIMIT ?]], { term, term, term, Config.MaxSearchResults }) or {}
        local out = {}
        for _, r in ipairs(rows) do
            local lic = {}
            local lrows = MySQL.query.await('SELECT type FROM user_licenses WHERE owner = ?', { r.identifier }) or {}
            for _, l in ipairs(lrows) do lic[#lic + 1] = l.type end
            out[#out + 1] = {
                citizenid = r.identifier,
                name = (r.firstname or '') .. ' ' .. (r.lastname or ''),
                dob = r.dateofbirth or 'Unknown',
                phone = '',
                licenses = lic
            }
        end
        return out
    end
    return {}
end

local function SearchVehicles(term)
    term = '%' .. (term or '') .. '%'
    if FrameworkName == 'hd' then
        local rows = MySQL.query.await([[
            SELECT pv.plate, pv.vehicle, p.charinfo FROM player_vehicles pv
            LEFT JOIN players p ON p.citizenid = pv.citizenid
            WHERE pv.plate LIKE ? LIMIT ?]], { term, Config.MaxSearchResults }) or {}
        local out = {}
        for _, r in ipairs(rows) do
            local ci = json.decode(r.charinfo or '{}') or {}
            out[#out + 1] = {
                plate = r.plate,
                model = r.vehicle,
                owner = (ci.firstname or 'Unknown') .. ' ' .. (ci.lastname or '')
            }
        end
        return out
    elseif FrameworkName == 'esx' then
        local rows = MySQL.query.await([[
            SELECT ov.plate, ov.vehicle, u.firstname, u.lastname FROM owned_vehicles ov
            LEFT JOIN users u ON u.identifier = ov.owner
            WHERE ov.plate LIKE ? LIMIT ?]], { term, Config.MaxSearchResults }) or {}
        local out = {}
        for _, r in ipairs(rows) do
            local vjson = json.decode(r.vehicle or '{}') or {}
            out[#out + 1] = {
                plate = r.plate,
                model = vjson.model and tostring(vjson.model) or 'Unknown',
                owner = (r.firstname or 'Unknown') .. ' ' .. (r.lastname or '')
            }
        end
        return out
    end
    return {}
end

-- ─────────────────────────── Endpoint handlers ────────────────────
-- Every handler: fn(src, char, deptKey, dept, data) -> table
local Handlers = {}

Handlers.dashboard = function(src, char, deptKey, dept)
    local p = dept.Prefix
    local updates = MySQL.query.await('SELECT * FROM `' .. p .. '_updates` ORDER BY id DESC LIMIT ?', { Config.DashboardUpdateLimit }) or {}
    local settings = MySQL.single.await('SELECT callsign, theme FROM `' .. p .. '_settings` WHERE identifier = ?', { char.identifier })
    return {
        updates = updates,
        callsign = settings and settings.callsign or '',
        theme = settings and settings.theme and json.decode(settings.theme) or nil,
        officer = char.name,
        dutyEnabled = Config.Duty.Enabled,
        onDuty = OnDuty[p][src] == true
    }
end

Handlers.toggleDuty = function(src, char, deptKey, dept, data)
    if not Config.Duty.Enabled then return { ok = false, error = 'Duty toggles are disabled.' } end
    local p = dept.Prefix
    local newState = not (OnDuty[p][src] == true)
    OnDuty[p][src] = newState or nil

    -- Optionally sync the framework's own duty flag
    if Config.Duty.SyncFramework then
        if FrameworkName == 'hd' then
            local P = Framework.Functions.GetPlayer(src)
            if P and P.Functions.SetJobDuty then P.Functions.SetJobDuty(newState) end
        elseif FrameworkName == 'esx' then
            TriggerEvent('esx:setJobDuty', src, newState)
        end
    end

    local hook = WebhookFor(deptKey, 'duty')
    if hook ~= '' then
        SendWebhook(hook, {
            title = newState and '🟢 On Duty' or '⚪ Off Duty',
            description = ('**%s** (%s) is now %s.'):format(char.name, dept.Brand, newState and 'on duty' or 'off duty'),
            color = newState and Config.WebhookColors.dutyOn or Config.WebhookColors.dutyOff,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        })
    end
    return { ok = true, onDuty = newState }
end

Handlers.saveSettings = function(src, char, deptKey, dept, data)
    local theme = data.theme and json.encode(data.theme) or nil
    MySQL.query.await(
        'INSERT INTO `' .. dept.Prefix .. '_settings` (identifier, callsign, theme) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE callsign = VALUES(callsign), theme = VALUES(theme)',
        { char.identifier, tostring(data.callsign or ''):sub(1, 20), theme })
    return { ok = true }
end

Handlers.postUpdate = function(src, char, deptKey, dept, data)
    if not IsBoss(char, dept) then return { ok = false, error = 'Command access only.' } end
    local kind = data.kind == 'training' and 'training' or 'update'
    MySQL.insert.await(
        'INSERT INTO `' .. dept.Prefix .. '_updates` (kind, title, message, author, callsign) VALUES (?, ?, ?, ?, ?)',
        { kind, tostring(data.title or ''):sub(1, 120), tostring(data.message or ''), char.name, GetCallsign(dept.Prefix, char.identifier) })
    return { ok = true }
end

Handlers.liveFeed = function(src, char, deptKey, dept, data)
    if not IsBoss(char, dept) then return { ok = false, error = 'Command access only.' } end
    local targets = GetOnDutyTargets(dept)
    local payload = {
        kind = 'livefeed',
        message = tostring(data.message or ''),
        author = char.name,
        callsign = GetCallsign(dept.Prefix, char.identifier),
        time = os.date('%H:%M')
    }
    if targets == -1 then
        TriggerClientEvent(dept.Prefix .. ':client:broadcast', -1, payload)
    else
        for _, t in ipairs(targets) do
            TriggerClientEvent(dept.Prefix .. ':client:broadcast', t, payload)
        end
    end
    return { ok = true }
end

Handlers.civSearch = function(src, char, deptKey, dept, data)
    return { results = SearchCivilians(data.term) }
end

Handlers.civProfile = function(src, char, deptKey, dept, data)
    local cid = tostring(data.citizenid or '')
    local p = dept.Prefix
    local pol = Config.Departments.police.Prefix
    local profile = { citizenid = cid }

    -- history: reports in THIS department that involve the civilian
    profile.history = MySQL.query.await(
        'SELECT id, rtype, title, author, created FROM `' .. p .. '_reports` WHERE involved LIKE ? ORDER BY id DESC LIMIT 25',
        { '%' .. cid .. '%' }) or {}

    if deptKey == 'police' then
        profile.warrants = MySQL.query.await(
            'SELECT * FROM `' .. pol .. '_warrants` WHERE citizenid = ? AND active = 1 ORDER BY id DESC', { cid }) or {}
        local mug = MySQL.single.await('SELECT url FROM `' .. pol .. '_mugshots` WHERE citizenid = ?', { cid })
        profile.mugshot = mug and mug.url or nil
    end

    if deptKey == 'uhs' then
        profile.patientRecords = MySQL.query.await(
            'SELECT * FROM `' .. Config.Departments.uhs.Prefix .. '_patients` WHERE citizenid = ? ORDER BY id DESC LIMIT 25', { cid }) or {}
    end
    return profile
end

Handlers.setMugshot = function(src, char, deptKey, dept, data)
    if deptKey ~= 'police' then return { ok = false, error = 'Police only.' } end
    if not UrlAllowed(data.url) then return { ok = false, error = 'Image link not allowed. Use an approved image host (https).' } end
    MySQL.query.await(
        'INSERT INTO `' .. dept.Prefix .. '_mugshots` (citizenid, url, set_by) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE url = VALUES(url), set_by = VALUES(set_by)',
        { tostring(data.citizenid), tostring(data.url), char.name })
    return { ok = true }
end

Handlers.vehicleSearch = function(src, char, deptKey, dept, data)
    if deptKey ~= 'police' then return { ok = false, error = 'Police only.' } end
    local results = SearchVehicles(data.term)
    local mechanicUp = GetResourceState('hd_mechanic') == 'started'
    for _, v in ipairs(results) do
        local m = MySQL.single.await('SELECT marker, notes, set_by FROM `' .. dept.Prefix .. '_vehicle_markers` WHERE plate = ?', { v.plate })
        if m then v.marker, v.markerNotes, v.markerBy = m.marker, m.notes, m.set_by end

        -- MOT/insurance/limp status from hd_mechanic, if installed — a
        -- real UK-relevant plate check, not just ownership/markers.
        if mechanicUp then
            local compliance = exports['hd_mechanic']:GetCompliance(v.plate)
            v.motValid = compliance.motValid
            v.insuranceValid = compliance.insuranceValid
            v.limpMode = compliance.limpMode
        end
    end
    return { results = results }
end

Handlers.setVehicleMarker = function(src, char, deptKey, dept, data)
    if deptKey ~= 'police' then return { ok = false, error = 'Police only.' } end
    local plate = tostring(data.plate or ''):sub(1, 12)
    if data.marker and data.marker ~= '' then
        MySQL.query.await(
            'INSERT INTO `' .. dept.Prefix .. '_vehicle_markers` (plate, marker, notes, set_by) VALUES (?, ?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE marker = VALUES(marker), notes = VALUES(notes), set_by = VALUES(set_by)',
            { plate, tostring(data.marker):sub(1, 30), tostring(data.notes or ''), char.name })
    else
        MySQL.query.await('DELETE FROM `' .. dept.Prefix .. '_vehicle_markers` WHERE plate = ?', { plate })
    end
    return { ok = true }
end

Handlers.createReport = function(src, char, deptKey, dept, data)
    local involved = data.involved or {}
    local id = MySQL.insert.await(
        'INSERT INTO `' .. dept.Prefix .. '_reports` (rtype, title, content, involved, author, author_callsign) VALUES (?, ?, ?, ?, ?, ?)',
        { tostring(data.rtype or 'Incident'):sub(1, 40), tostring(data.title or ''):sub(1, 120),
          tostring(data.content or ''), json.encode(involved), char.name,
          GetCallsign(dept.Prefix, char.identifier) })

    local hook = WebhookFor(deptKey, 'reports')
    if hook ~= '' then
        local names = {}
        for _, c in ipairs(involved) do names[#names + 1] = c.name end
        local body = tostring(data.content or '')
        if #body > 1000 then body = body:sub(1, 1000) .. '…' end
        SendWebhook(hook, {
            title = ('📄 %s Report #%d'):format(tostring(data.rtype or 'Incident'), id),
            description = ('**%s**\n%s'):format(tostring(data.title or ''), body),
            color = Config.WebhookColors[deptKey] or 3092790,
            fields = {
                { name = 'Filed by', value = char.name, inline = true },
                { name = 'Involved', value = (#names > 0 and table.concat(names, ', ')) or 'None', inline = true }
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        })
    end
    return { ok = true, id = id }
end

Handlers.searchReports = function(src, char, deptKey, dept, data)
    local term = '%' .. tostring(data.term or '') .. '%'
    local rows = MySQL.query.await(
        'SELECT id, rtype, title, author, author_callsign, created FROM `' .. dept.Prefix .. '_reports` ' ..
        'WHERE title LIKE ? OR content LIKE ? OR author LIKE ? OR involved LIKE ? ORDER BY id DESC LIMIT 40',
        { term, term, term, term }) or {}
    return { results = rows }
end

Handlers.getReport = function(src, char, deptKey, dept, data)
    local row = MySQL.single.await('SELECT * FROM `' .. dept.Prefix .. '_reports` WHERE id = ?', { tonumber(data.id) or 0 })
    if row then row.involved = json.decode(row.involved or '[]') end
    return { report = row }
end

-- Shared by Handlers.setWarrant (a real officer, via the MDT NUI) and
-- the IssueSystemWarrant export below (another resource, no officer
-- involved) — one code path for the actual insert + live feed +
-- webhook, so the two can never drift out of sync with each other.
local function IssueWarrantRecord(dept, deptKey, citizenid, name, reason, issuedBy)
    MySQL.insert.await(
        'INSERT INTO `' .. dept.Prefix .. '_warrants` (citizenid, name, reason, issued_by) VALUES (?, ?, ?, ?)',
        { tostring(citizenid), tostring(name or ''):sub(1, 80), tostring(reason or ''), tostring(issuedBy) })

    local payload = {
        kind = 'livefeed',
        message = ('WARRANT ISSUED: %s — %s'):format(name or 'Unknown', reason or ''),
        author = issuedBy, time = os.date('%H:%M')
    }
    local targets = GetOnDutyTargets(dept)
    if targets == -1 then
        TriggerClientEvent(dept.Prefix .. ':client:broadcast', -1, payload)
    else
        for _, t in ipairs(targets) do TriggerClientEvent(dept.Prefix .. ':client:broadcast', t, payload) end
    end

    local hook = WebhookFor(deptKey, 'warrants')
    if hook ~= '' then
        SendWebhook(hook, {
            title = '⚠️ Warrant Issued',
            description = ('A warrant has been issued for **%s**.'):format(name or 'Unknown'),
            color = Config.WebhookColors.warrant,
            fields = {
                { name = 'Reason', value = tostring(reason or 'N/A') },
                { name = 'Issued by', value = issuedBy, inline = true }
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        })
    end
end

Handlers.setWarrant = function(src, char, deptKey, dept, data)
    if deptKey ~= 'police' then return { ok = false, error = 'Police only.' } end
    if not IsBoss(char, dept) then return { ok = false, error = 'Command access only.' } end
    IssueWarrantRecord(dept, deptKey, data.citizenid, data.name, data.reason, char.name)
    return { ok = true }
end

-- For other resources: write a real warrant into this MDT's own
-- mdtpolice_warrants table with no officer session involved — used by
-- hd_fines when a citizen's debt crosses its warrant threshold. Same
-- table Handlers.civProfile reads for civilian search, so it shows up
-- there immediately, and it survives independently of any one live
-- hd_dispatch call. Always targets the police department specifically
-- — warrants are a police-only concept in this MDT (see the deptKey
-- checks in Handlers.setWarrant/clearWarrant above).
exports('IssueSystemWarrant', function(citizenid, name, reason, issuedBy)
    local dept = Config.Departments.police
    if not dept then return false end
    IssueWarrantRecord(dept, 'police', citizenid, name, reason, issuedBy or 'System')
    return true
end)

Handlers.clearWarrant = function(src, char, deptKey, dept, data)
    if deptKey ~= 'police' then return { ok = false, error = 'Police only.' } end
    if not IsBoss(char, dept) then return { ok = false, error = 'Command access only.' } end
    local w = MySQL.single.await('SELECT name FROM `' .. dept.Prefix .. '_warrants` WHERE id = ?', { tonumber(data.id) or 0 })
    MySQL.query.await('UPDATE `' .. dept.Prefix .. '_warrants` SET active = 0 WHERE id = ?', { tonumber(data.id) or 0 })
    local hook = WebhookFor(deptKey, 'warrants')
    if hook ~= '' and w then
        SendWebhook(hook, {
            title = '✅ Warrant Cleared',
            description = ('The warrant for **%s** has been cleared by **%s**.'):format(w.name, char.name),
            color = Config.WebhookColors.dutyOn,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        })
    end
    return { ok = true }
end

Handlers.createPatient = function(src, char, deptKey, dept, data)
    if deptKey ~= 'uhs' then return { ok = false, error = 'UHS only.' } end
    local id = MySQL.insert.await(
        'INSERT INTO `' .. dept.Prefix .. '_patients` (citizenid, name, blood_type, medications, staff, treatment, notes, author) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { tostring(data.citizenid or ''), tostring(data.name or ''):sub(1, 80), tostring(data.bloodType or ''):sub(1, 5),
          tostring(data.medications or ''), tostring(data.staff or ''), tostring(data.treatment or ''),
          tostring(data.notes or ''), char.name })
    return { ok = true, id = id }
end

Handlers.searchPatients = function(src, char, deptKey, dept, data)
    if deptKey ~= 'uhs' then return { ok = false, error = 'UHS only.' } end
    local term = '%' .. tostring(data.term or '') .. '%'
    local rows = MySQL.query.await(
        'SELECT * FROM `' .. dept.Prefix .. '_patients` WHERE name LIKE ? OR citizenid LIKE ? ORDER BY id DESC LIMIT 40',
        { term, term }) or {}
    return { results = rows }
end

-- ─────────────────────────── Event registration ───────────────────
CreateThread(function()
    for deptKey, dept in pairs(Config.Departments) do
        RegisterNetEvent(dept.Prefix .. ':server:opened', function()
            local src = source
            if Config.Duty.Enabled and Config.Duty.DefaultOnDuty and OnDuty[dept.Prefix][src] == nil then
                local char = GetChar(src)
                if HasDeptAccess(char, dept) then OnDuty[dept.Prefix][src] = true end
            end
        end)
        for name, fn in pairs(Handlers) do
            RegisterNetEvent(dept.Prefix .. ':server:' .. name, function(cbId, data)
                local src = source
                local char = GetChar(src)
                if not HasDeptAccess(char, dept) then
                    TriggerClientEvent(dept.Prefix .. ':client:reply', src, cbId, { ok = false, error = 'No access.' })
                    return
                end
                local ok, result = pcall(fn, src, char, deptKey, dept, data or {})
                if not ok then
                    print(('^1[hazy_mdt]^7 handler error (%s:%s): %s'):format(dept.Prefix, name, result))
                    result = { ok = false, error = 'Internal error.' }
                end
                TriggerClientEvent(dept.Prefix .. ':client:reply', src, cbId, result)
            end)
        end
    end
end)

-- Clear duty state when a player disconnects (prevents stale broadcast targets)
AddEventHandler('playerDropped', function()
    local src = source
    for _, tbl in pairs(OnDuty) do tbl[src] = nil end
end)
