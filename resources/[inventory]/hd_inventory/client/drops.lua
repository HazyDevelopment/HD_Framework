-- ═══════════════════════════════════════════════════════════════════
--  HD INVENTORY | GROUND DROPS (client)
--  A real world prop now renders at every nearby drop — a single
--  generic model (Config.DropProp, default 'prop_med_bag_01b', the
--  same battle-tested default ox_inventory itself ships) rather than
--  one accurate model per item, since mapping all 20+ items to
--  correct unique props isn't a realistic ask. Each prop is spawned
--  LOCAL and non-networked (CreateObject(..., false, true, true)) —
--  purely decorative, proximity-culled per client, exactly the
--  pattern ox_inventory itself uses for this. Interaction still goes
--  through the marker + [E] prompt below, not native prop physics.
-- ═══════════════════════════════════════════════════════════════════

local LocalDrops = {}
local LocalProps = {} -- [dropId] = object handle

local dropPropHash = GetHashKey(Config.DropProp)
CreateThread(function() RequestModel(dropPropHash) end)

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    TriggerServerEvent('hd_inventory:server:requestDrops')
end)

local function DespawnDropProp(id)
    local obj = LocalProps[id]
    if obj and DoesEntityExist(obj) then DeleteObject(obj) end
    LocalProps[id] = nil
end

local function SpawnDropProp(id, coords)
    if LocalProps[id] then return end
    if not HasModelLoaded(dropPropHash) then
        RequestModel(dropPropHash) -- keeps nudging the streamer; harmless if already pending
        return
    end
    local obj = CreateObject(dropPropHash, coords.x, coords.y, coords.z, false, true, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false) -- decorative only — don't let it shove players/vehicles around
    LocalProps[id] = obj
end

RegisterNetEvent('hd_inventory:client:newDrop', function(drop)
    LocalDrops[drop.id] = drop
    local dcoords = vector3(drop.coords.x, drop.coords.y, drop.coords.z)
    if #(GetEntityCoords(PlayerPedId()) - dcoords) < 15.0 then
        SpawnDropProp(drop.id, dcoords) -- immediate feedback if you're the one who just dropped it
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
                SpawnDropProp(id, dcoords)
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
