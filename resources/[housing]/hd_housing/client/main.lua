-- ═══════════════════════════════════════════════════════════════════
--  HD HOUSING | CLIENT
--  Draws an [E] Enter prompt at any owned property's exterior door for
--  its owner, teleports into/out of the frozen sky-pocket interior,
--  and furnishes it with Config.PlainFurniture on entry.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
local myCitizenId = nil
local ownedProperties = {}
local insidePropertyId = nil
local spawnedFurniture = {}

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

RegisterNetEvent('HD:Client:OnPlayerLoaded', function(playerData)
    myCitizenId = playerData.citizenid
    TriggerServerEvent('hd_housing:server:getOwnedProperties')
end)

RegisterNetEvent('hd_housing:client:ownedProperties', function(list)
    ownedProperties = list
end)

local function Draw3DText(coords, text)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING') AddTextComponentString(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- ═══════════════════════════ ENTER (exterior proximity) ═══════════════
CreateThread(function()
    while true do
        local sleep = 800
        if not insidePropertyId and myCitizenId and #ownedProperties > 0 then
            local pc = GetEntityCoords(PlayerPedId())
            for _, p in ipairs(ownedProperties) do
                if p.citizenid == myCitizenId then
                    local d = #(pc - vector3(p.coords.x, p.coords.y, p.coords.z))
                    if d <= Config.InteractDistance then
                        sleep = 0
                        Draw3DText(vector3(p.coords.x, p.coords.y, p.coords.z + 1.0), ('[E] Enter %s'):format(p.label))
                        if IsControlJustReleased(0, 38) then -- E
                            TriggerServerEvent('hd_housing:server:enter', p.id)
                        end
                    end
                end
            end
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

local function ClearFurniture()
    for _, obj in ipairs(spawnedFurniture) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawnedFurniture = {}
end

local function SpawnFurniture(pocket)
    for _, piece in ipairs(Config.PlainFurniture) do
        local hash = GetHashKey(piece.model)
        RequestModel(hash)
        local waited = 0
        while not HasModelLoaded(hash) and waited < 2000 do Wait(50) waited = waited + 50 end
        if HasModelLoaded(hash) then
            local pos = pocket + piece.offset
            local obj = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(obj, piece.heading or 0.0)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(hash)
            spawnedFurniture[#spawnedFurniture + 1] = obj
        end
    end
end

RegisterNetEvent('hd_housing:client:enter', function(property)
    insidePropertyId = property.id
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(450)
    SetEntityCoordsNoOffset(ped, property.pocket.x, property.pocket.y, property.pocket.z, false, false, false)
    SetEntityHeading(ped, 0.0)
    FreezeEntityPosition(ped, true)
    SpawnFurniture(property.pocket)
    Wait(200)
    DoScreenFadeIn(400)
    Config.Notify('Welcome home.', 'success')
end)

RegisterNetEvent('hd_housing:client:exit', function(exteriorCoords)
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(450)
    ClearFurniture()
    FreezeEntityPosition(ped, false)
    SetEntityCoordsNoOffset(ped, exteriorCoords.x, exteriorCoords.y, exteriorCoords.z, false, false, false)
    SetEntityHeading(ped, exteriorCoords.w or 0.0)
    insidePropertyId = nil
    Wait(200)
    DoScreenFadeIn(400)
end)
