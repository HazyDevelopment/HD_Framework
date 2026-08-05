-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | CLIENT
--  A blip and a walk-up-and-press-E entry for every one of the 12
--  Config.ApartmentShells, not just owned ones — see config.lua's
--  header and the top-level README's Housing section for why. Owned
--  properties enter normally; unowned ones are previewable the same
--  way, plus draw a small brochure card (id/label/size/price) while
--  you're nearby. No furniture spawning needed any more, these are
--  real, already-furnished gamebuild interiors.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
local myCitizenId = nil
local properties = {} -- full list, every shell — see server's getAllProperties
local propertyBlips = {} -- [id] = blip handle
local insidePropertyId = nil
local loadedIpls = {} -- [iplName] = true, never unrequested once loaded — cheap to keep streamed
local brochureShownFor = nil
local grantedAccess = {} -- [propertyId] = true, client-side mirror of a buzz the owner just accepted — cleared the moment it's used to enter

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

RegisterNetEvent('HD:Client:OnPlayerLoaded', function(playerData)
    myCitizenId = playerData.citizenid
    TriggerServerEvent('hd_housing:server:getAllProperties')
end)

-- HD_Framework fires this once, right after a brand-new character
-- spawns, carrying the starter flat id they just claimed (nil if they
-- skipped picking one) — HD_Framework/server/characters.lua already
-- pointed their very first spawn position at that flat's own interior
-- coords, so this just tells hd_housing's own bookkeeping they're
-- already home (no teleport here, they're already standing in it).
RegisterNetEvent('HD:Client:NewCharacterSpawned', function(homePropertyId)
    if not homePropertyId then return end
    insidePropertyId = homePropertyId
    TriggerServerEvent('hd_housing:server:setInsideFromSpawn', homePropertyId)
end)

-- ═══════════════════════════ BLIPS ═════════════════════════════════════
local function BlipColorFor(p)
    if p.citizenid == myCitizenId then return 2 end   -- green — yours
    if p.citizenid then return 1 end                  -- red — someone else's
    if p.registered then return 5 end                 -- yellow — for sale
    return 3                                           -- grey — not listed yet
end

local function RefreshBlips()
    for _, p in ipairs(properties) do
        local blip = propertyBlips[p.id]
        if not blip or not DoesBlipExist(blip) then
            blip = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
            SetBlipSprite(blip, 40)
            SetBlipAsShortRange(blip, true)
            propertyBlips[p.id] = blip
        end
        SetBlipColour(blip, BlipColorFor(p))
        SetBlipScale(blip, 0.75)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(p.label)
        EndTextCommandSetBlipName(blip)
    end
end

-- A thin local wrapper rather than pointing the "Enter" option straight
-- at the server event — grantedAccess is a one-time flag (the server's
-- own GuestAccess table is the real, authoritative consumption of it;
-- see server/main.lua's enter handler), but the CLIENT's copy needs
-- clearing too the moment it's used, same as the old Draw3DText/E-press
-- code already did, or canInteract below would keep saying "Enter" is
-- still available after the server's already spent it.
RegisterNetEvent('hd_housing:client:targetEnter', function(propertyId)
    grantedAccess[propertyId] = nil
    TriggerServerEvent('hd_housing:server:enter', propertyId)
end)

-- Three mutually-exclusive options per property, gated by canInteract
-- so only the one that actually applies to THIS player right now ever
-- shows — ownership/buzz state changes live (a buzz gets accepted, an
-- unowned flat gets bought), and canInteract is re-evaluated by
-- hd_target on every single poll, so that's picked up automatically
-- with no need to re-register anything when it changes. Falls back to
-- the old walk-up-and-press-E prompt entirely if hd_target isn't
-- installed — never a hard dependency.
local function RegisterPropertyTarget(p)
    if GetResourceState('hd_target') ~= 'started' then return end
    local coords = vector3(p.coords.x, p.coords.y, p.coords.z)
    exports['hd_target']:AddZone('hd_housing_' .. p.id, coords, Config.InteractDistance, {
        {
            icon = '🏠', label = 'Enter ' .. p.label, distance = Config.InteractDistance,
            event = 'hd_housing:client:targetEnter', args = p.id,
            canInteract = function() return p.citizenid == myCitizenId or grantedAccess[p.id] end,
        },
        {
            icon = '👀', label = 'Preview ' .. p.label, distance = Config.InteractDistance,
            serverEvent = 'hd_housing:server:enter', args = p.id,
            canInteract = function() return not p.citizenid end,
        },
        {
            icon = '🔔', label = 'Ring Buzzer — ' .. p.label, distance = Config.InteractDistance,
            serverEvent = 'hd_housing:server:buzz', args = p.id,
            canInteract = function() return p.citizenid and p.citizenid ~= myCitizenId and not grantedAccess[p.id] end,
        },
    })
end

RegisterNetEvent('hd_housing:client:allProperties', function(list)
    properties = list
    RefreshBlips()
    for _, p in ipairs(properties) do RegisterPropertyTarget(p) end
end)

local function Draw3DText(coords, text)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING') AddTextComponentString(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ═══════════════════════════ BROCHURE (NUI) ════════════════════════════
local function ShowBrochure(p)
    if brochureShownFor == p.id then return end
    brochureShownFor = p.id
    SendNUIMessage({
        action = 'brochure',
        show = true,
        id = p.id,
        label = p.label,
        size = p.size,
        price = p.price,
        registered = p.registered,
    })
end

local function HideBrochure()
    if not brochureShownFor then return end
    brochureShownFor = nil
    SendNUIMessage({ action = 'brochure', show = false })
end

-- ═══════════════════════════ ENTER (exterior proximity) ═══════════════
-- The actual enter/preview/buzz interaction itself is hd_target zones
-- now (RegisterPropertyTarget above) — this loop just keeps the
-- brochure card up for whoever's lingering near an unowned property,
-- which isn't really an "interaction" so much as ambient info, plus a
-- Draw3DText+E fallback for a server that hasn't installed hd_target.
local hasTarget = GetResourceState('hd_target') == 'started'

CreateThread(function()
    while true do
        local sleep = 800
        if not insidePropertyId and #properties > 0 then
            local pc = GetEntityCoords(PlayerPedId())
            local nearAny = false

            for _, p in ipairs(properties) do
                local d = #(pc - vector3(p.coords.x, p.coords.y, p.coords.z))
                if d <= Config.InteractDistance then
                    sleep = 0
                    local mine = p.citizenid == myCitizenId
                    local blocked = p.citizenid and not mine and not grantedAccess[p.id] -- owned by someone else, and not just buzzed in
                    local justBuzzedIn = grantedAccess[p.id]

                    nearAny = true
                    if not hasTarget then
                        if blocked then
                            Draw3DText(vector3(p.coords.x, p.coords.y, p.coords.z + 1.0), ('[E] Ring Buzzer — %s'):format(p.label))
                            if IsControlJustReleased(0, 38) then -- E
                                TriggerServerEvent('hd_housing:server:buzz', p.id)
                            end
                        else
                            Draw3DText(vector3(p.coords.x, p.coords.y, p.coords.z + 1.0),
                                mine and ('[E] Enter %s'):format(p.label) or justBuzzedIn and ('[E] Enter %s (buzzed in)'):format(p.label) or ('[E] Preview %s'):format(p.label))
                            if IsControlJustReleased(0, 38) then -- E
                                grantedAccess[p.id] = nil
                                TriggerServerEvent('hd_housing:server:enter', p.id)
                            end
                        end
                    end
                    if not blocked and not mine and not justBuzzedIn then ShowBrochure(p) end
                end
            end

            if not nearAny then HideBrochure() end
        elseif not insidePropertyId then
            HideBrochure()
        end
        Wait(sleep)
    end
end)

-- ═══════════════════════════ EXIT (while inside) ═══════════════════════
CreateThread(function()
    while true do
        Wait(insidePropertyId and 0 or 500)
        if insidePropertyId then
            Draw3DText(GetEntityCoords(PlayerPedId()) + vector3(0.0, 0.0, 1.0), '[BACKSPACE] Leave')
            if IsControlJustReleased(0, 194) then -- BACKSPACE
                TriggerServerEvent('hd_housing:server:exit')
            end
        end
    end
end)

-- High-end shells only — mid-range ones are already part of the base
-- map and need no IPL at all. Requested once and left streamed in for
-- the rest of the session; cheap, and avoids the pop-in of re-requesting
-- it every single time someone comes back.
local function EnsureIpl(iplName)
    if not iplName or loadedIpls[iplName] then return end
    RequestIpl(iplName)
    local waited = 0
    while not IsIplActive(iplName) and waited < Config.IplWaitMs do Wait(50) waited = waited + 50 end
    loadedIpls[iplName] = true
end

RegisterNetEvent('hd_housing:client:enter', function(property)
    insidePropertyId = property.id
    HideBrochure()
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(450)
    EnsureIpl(property.ipl)
    SetEntityCoordsNoOffset(ped, property.pocket.x, property.pocket.y, property.pocket.z, false, false, false)
    SetEntityHeading(ped, 0.0)
    SpawnFurniture(property.furniture or {})
    Wait(200)
    DoScreenFadeIn(400)
    Config.Notify('Welcome home.', 'success')
end)

RegisterNetEvent('hd_housing:client:exit', function(exteriorCoords)
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(450)
    SetEntityCoordsNoOffset(ped, exteriorCoords.x, exteriorCoords.y, exteriorCoords.z, false, false, false)
    SetEntityHeading(ped, exteriorCoords.w or 0.0)
    insidePropertyId = nil
    ClearFurniture()
    Wait(200)
    DoScreenFadeIn(400)
end)

-- ═══════════════════════════ PLACEABLE FURNITURE ═══════════════════════
local furnitureObjects = {} -- [kind] = entity handle

-- Same dispatch the old Draw3DText/E-press furniture prompt used —
-- wardrobe opens a client command, stash round-trips to the server.
-- Kept as one local handler so both the hd_target option and the
-- no-hd_target fallback loop below trigger identically.
RegisterNetEvent('hd_housing:client:targetFurniture', function(kind)
    if kind == 'wardrobe' then
        ExecuteCommand(Config.WardrobeCommand or 'outfits')
    elseif kind == 'stash' then
        TriggerServerEvent('hd_housing:server:openStash', insidePropertyId)
    end
end)

local function DeleteFurnitureObject(kind)
    local obj = furnitureObjects[kind]
    if obj and DoesEntityExist(obj) then
        if GetResourceState('hd_target') == 'started' then exports['hd_target']:RemoveEntity(obj) end
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
    end
    furnitureObjects[kind] = nil
end

local function SpawnOne(kind, data)
    local def = Config.Furniture[kind]
    if not def then return end
    DeleteFurnitureObject(kind)

    local hash = GetHashKey(def.model)
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 3000 do Wait(50) waited = waited + 50 end
    if not HasModelLoaded(hash) then return end

    local obj = CreateObject(hash, data.x, data.y, data.z, false, true, false)
    SetEntityHeading(obj, data.h or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    SetModelAsNoLongerNeeded(hash)
    furnitureObjects[kind] = obj

    if GetResourceState('hd_target') == 'started' then
        exports['hd_target']:AddEntity(obj, {
            { icon = '🗄️', label = 'Open ' .. (def.label or kind), distance = Config.FurnitureInteractDistance,
              event = 'hd_housing:client:targetFurniture', args = kind },
        })
    end
end

function SpawnFurniture(furniture)
    furniture = furniture or {}
    for kind in pairs(Config.Furniture) do
        if furniture[kind] then SpawnOne(kind, furniture[kind])
        else DeleteFurnitureObject(kind) end
    end
end

function ClearFurniture()
    for kind in pairs(Config.Furniture) do DeleteFurnitureObject(kind) end
end

RegisterNetEvent('hd_housing:client:furnitureUpdated', function(furniture)
    SpawnFurniture(furniture)
end)

RegisterCommand('placewardrobe', function()
    if not insidePropertyId then Config.Notify('You need to be inside your home for that.', 'error') return end
    TriggerServerEvent('hd_housing:server:placeFurniture', 'wardrobe')
end, false)

RegisterCommand('placestash', function()
    if not insidePropertyId then Config.Notify('You need to be inside your home for that.', 'error') return end
    TriggerServerEvent('hd_housing:server:placeFurniture', 'stash')
end, false)

-- Proximity interact for whichever furniture is actually placed — only
-- runs the old Draw3DText/E-press prompt when hd_target isn't
-- installed; SpawnOne above already registers a hd_target option on
-- the object itself otherwise.
CreateThread(function()
    while true do
        local sleep = 500
        if insidePropertyId and not hasTarget then
            local pc = GetEntityCoords(PlayerPedId())
            for kind, obj in pairs(furnitureObjects) do
                if obj and DoesEntityExist(obj) then
                    local d = #(pc - GetEntityCoords(obj))
                    if d <= Config.FurnitureInteractDistance then
                        sleep = 0
                        local label = Config.Furniture[kind] and Config.Furniture[kind].label or kind
                        Draw3DText(GetEntityCoords(obj) + vector3(0.0, 0.0, 0.6), ('[E] Open %s'):format(label))
                        if IsControlJustReleased(0, 38) then
                            TriggerEvent('hd_housing:client:targetFurniture', kind)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ═══════════════════════════ BUZZER ═══════════════════════════════════
RegisterNetEvent('hd_housing:client:accessGranted', function(propertyId)
    grantedAccess[propertyId] = true
end)

-- Only reaches the resident who's actually home (server checked
-- InsideInterior before sending this) — a simple NUI prompt rather
-- than a native yes/no, so it can show the visitor's name properly.
RegisterNetEvent('hd_housing:client:buzzRequest', function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'buzz', show = true, visitorName = data.visitorName, propertyId = data.propertyId, visitorSrc = data.visitorSrc })
end)

RegisterNUICallback('buzzRespond', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('hd_housing:server:buzzRespond', data.propertyId, data.visitorSrc, data.accept)
    cb({})
end)
