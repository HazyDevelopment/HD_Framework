-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | GROUND DROPS (client)
--  A real world prop renders at every nearby drop — per-item now
--  (server/drops.lua's ResolveDropProp, via Config.ItemDropProps),
--  falling back to Config.DropProp for anything unmapped. Each prop is
--  spawned LOCAL and non-networked (CreateObject(..., false, true,
--  true)) — purely decorative, proximity-culled per client, exactly
--  the pattern ox_inventory itself uses for this. Interaction still
--  goes through the marker + [E] prompt below, not native prop physics.
-- ═══════════════════════════════════════════════════════════════════

local LocalDrops = {}
local LocalProps = {} -- [dropId] = object handle

-- Hashes are requested lazily per distinct model actually seen, not
-- pre-loaded for every entry in Config.ItemDropProps up front.
local ModelHashes = {} -- [modelName] = hash

local function GetModelHash(modelName)
    local hash = ModelHashes[modelName]
    if not hash then
        hash = GetHashKey(modelName)
        ModelHashes[modelName] = hash
    end
    return hash
end

-- Config.DropProp specifically is worth pre-warming — it's still the
-- fallback for every item Config.ItemDropProps doesn't map, so it's
-- the model most likely to be needed the moment a player sees any
-- drop at all. Everything else streams in lazily, first-seen, inside
-- SpawnDropProp below.
CreateThread(function() RequestModel(GetModelHash(Config.DropProp)) end)

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    TriggerServerEvent('hd_inventory:server:requestDrops')
end)

local function DespawnDropProp(id)
    local obj = LocalProps[id]
    if obj and DoesEntityExist(obj) then DeleteObject(obj) end
    LocalProps[id] = nil
end

local function SpawnDropProp(id, coords, modelName)
    if LocalProps[id] then return end
    local hash = GetModelHash(modelName or Config.DropProp)
    if not HasModelLoaded(hash) then
        RequestModel(hash) -- keeps nudging the streamer; harmless if already pending
        return
    end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, true, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false) -- decorative only — don't let it shove players/vehicles around
    LocalProps[id] = obj
end

RegisterNetEvent('hd_inventory:client:newDrop', function(drop)
    LocalDrops[drop.id] = drop
    local dcoords = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
    if #(GetEntityCoords(PlayerPedId()) - dcoords) < 15.0 then
        SpawnDropProp(drop.id, dcoords, drop.model) -- immediate feedback if you're the one who just dropped it
    end
end)

RegisterNetEvent('hd_inventory:client:updateDrop', function(drop) LocalDrops[drop.id] = drop end)

RegisterNetEvent('hd_inventory:client:removeDrop', function(id)
    LocalDrops[id] = nil
    DespawnDropProp(id)
end)

RegisterNetEvent('hd_inventory:client:syncDrops', function(list)
    for id in pairs(LocalProps) do DespawnDropProp(id) end -- the render loop respawns whichever are actually nearby
    LocalDrops = {}
    for _, d in ipairs(list) do LocalDrops[d.id] = d end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(LocalProps) do DespawnDropProp(id) end
end)

local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.3, 0.3)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)
end

CreateThread(function()
    while true do
        local sleep = 500
        local pcoords = GetEntityCoords(PlayerPedId())

        for id, drop in pairs(LocalDrops) do
            local dcoords = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
            local dist = #(pcoords - dcoords)
            if dist < 15.0 then
                sleep = 0
                SpawnDropProp(id, dcoords, drop.model)
                DrawMarker(1, dcoords.x, dcoords.y, dcoords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.25, 216, 168, 50, 180, false, true, 2, false, nil, nil, false)
                if dist < Config.DropRadius then
                    DrawText3D(dcoords.x, dcoords.y, dcoords.z + 0.45, '[E] Pick up')
                end
            elseif LocalProps[id] then
                DespawnDropProp(id) -- out of range — cull it, the loop will respawn if we come back
            end
        end

        Wait(sleep)
    end
end)

RegisterKeyMapping('hd_inventory_pickup', 'HD Inventory: pick up nearby drop', 'keyboard', 'E')
RegisterCommand('hd_inventory_pickup', function()
    if IsInventoryOpen() then return end
    local pcoords = GetEntityCoords(PlayerPedId())
    local closestId, closestDist = nil, Config.DropRadius

    for id, drop in pairs(LocalDrops) do
        local dist = #(pcoords - vector3(drop.coords.x, drop.coords.y, drop.coords.z))
        if dist <= closestDist then closestId, closestDist = id, dist end
    end

    if closestId then
        OpenSecondaryInventory({ type = 'drop', id = closestId })
    end
end, false)
