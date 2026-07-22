-- ═══════════════════════════════════════════════════════════════════
--  HAZY DEVELOPMENT | ADVANCED MDT | CLIENT
-- ═══════════════════════════════════════════════════════════════════

local Framework, FrameworkName = nil, nil
local PlayerJob = { name = nil, grade = 0, gradeName = '', isboss = false }
local MdtOpen = false
local CurrentDept = nil

-- ─────────────────────────── Framework ────────────────────────────
CreateThread(function()
    if Config.Framework == 'qb' or (Config.Framework == 'auto' and GetResourceState('qb-core') == 'started') then
        FrameworkName = 'qb'
        Framework = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == 'esx' or (Config.Framework == 'auto' and GetResourceState('es_extended') == 'started') then
        FrameworkName = 'esx'
        Framework = exports['es_extended']:getSharedObject()
    end
    RefreshJob()
end)

function RefreshJob()
    if FrameworkName == 'qb' then
        local pd = Framework.Functions.GetPlayerData()
        if pd and pd.job then
            PlayerJob.name = pd.job.name
            PlayerJob.grade = pd.job.grade and pd.job.grade.level or 0
            PlayerJob.gradeName = pd.job.grade and pd.job.grade.name or ''
            PlayerJob.isboss = pd.job.isboss or false
        end
    elseif FrameworkName == 'esx' then
        local pd = Framework.GetPlayerData()
        if pd and pd.job then
            PlayerJob.name = pd.job.name
            PlayerJob.grade = pd.job.grade or 0
            PlayerJob.gradeName = pd.job.grade_name or ''
            PlayerJob.isboss = false
        end
    end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob.name = job.name
    PlayerJob.grade = job.grade and job.grade.level or 0
    PlayerJob.gradeName = job.grade and job.grade.name or ''
    PlayerJob.isboss = job.isboss or false
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerJob.name = job.name
    PlayerJob.grade = job.grade or 0
    PlayerJob.gradeName = job.grade_name or ''
end)

-- ─────────────────────────── Helpers ──────────────────────────────
local function GetDepartmentForJob()
    for key, dept in pairs(Config.Departments) do
        for _, job in ipairs(dept.Jobs) do
            if PlayerJob.name == job then return key, dept end
        end
    end
    return nil, nil
end

local function IsBoss(dept)
    if dept.UseFrameworkBossFlag and PlayerJob.isboss then return true end
    for _, g in ipairs(dept.BossGrades or {}) do
        if PlayerJob.grade == g then return true end
    end
    local gname = tostring(PlayerJob.gradeName or ''):lower()
    for _, n in ipairs(dept.BossGradeNames or {}) do
        if gname == tostring(n):lower() then return true end
    end
    if dept.BossMinGrade and PlayerJob.grade >= dept.BossMinGrade then return true end
    return false
end

-- ─────────────────────────── Open / Close ─────────────────────────
local function OpenMDT()
    RefreshJob()
    local key, dept = GetDepartmentForJob()
    if not key then
        Config.Notify('You do not have access to an MDT.', 'error')
        return
    end
    CurrentDept = key
    MdtOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        department = key,
        prefix = dept.Prefix,
        brand = dept.Brand,
        brandSub = dept.BrandSub,
        theme = dept.Theme,
        tabs = dept.Tabs,
        isBoss = IsBoss(dept),
        reportTypes = Config.ReportTypes[key] or {},
        vehicleMarkers = Config.VehicleMarkers,
        bloodTypes = Config.BloodTypes
    })
    TriggerServerEvent(dept.Prefix .. ':server:opened')
end

local function CloseMDT()
    MdtOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.Command, OpenMDT, false)
if Config.UseKeybind then
    RegisterKeyMapping(Config.Command, 'Open MDT', 'keyboard', Config.Keybind)
end

RegisterNUICallback('close', function(_, cb)
    CloseMDT()
    cb('ok')
end)

-- ─────────────── NUI <-> Server bridge (prefixed, no collisions) ──
-- The NUI posts to callback 'request' with { prefix, endpoint, data }.
-- We forward to '<prefix>:server:<endpoint>' and resolve with the reply.
local pendingCallbacks = {}
local cbId = 0

RegisterNUICallback('request', function(body, cb)
    cbId = cbId + 1
    local id = cbId
    pendingCallbacks[id] = cb
    TriggerServerEvent(body.prefix .. ':server:' .. body.endpoint, id, body.data or {})
end)

-- Every department prefix shares one client reply event per prefix
CreateThread(function()
    for _, dept in pairs(Config.Departments) do
        RegisterNetEvent(dept.Prefix .. ':client:reply', function(id, result)
            if pendingCallbacks[id] then
                pendingCallbacks[id](result or {})
                pendingCallbacks[id] = nil
            end
        end)

        -- Live feed / broadcast push from Command tab
        RegisterNetEvent(dept.Prefix .. ':client:broadcast', function(payload)
            local key = GetDepartmentForJob()
            if key and Config.Departments[key].Prefix == dept.Prefix then
                SendNUIMessage({ action = 'broadcast', payload = payload })
                if payload and payload.kind == 'livefeed' and not MdtOpen then
                    Config.Notify(('[%s] %s'):format(dept.Brand, payload.message or ''), 'info')
                end
            end
        end)
    end
end)
