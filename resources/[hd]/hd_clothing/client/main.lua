-- ═══════════════════════════════════════════════════════════════════
--  HD_CLOTHING | CLIENT
--  The wardrobe menu itself: reads live variation counts off the
--  ped's own model (GetNumberOfPedDrawableVariations and friends)
--  instead of a hand-maintained catalog, so it works against any ped
--  model with no extra config. Same menu whether opened free via
--  /outfits or at a store — the only difference is whether "save"
--  charges anything (see OpenWardrobe's `atStore` argument).
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local menuOpen = false
local current = { components = {}, props = {} } -- [index] = { drawable, texture }
local previewCam = nil
local camHeading = 0.0
local activeStoreIndex = nil -- nil = free wardrobe (/outfits), else Config.Stores index

-- ═══════════════════════════ APPLY / SNAPSHOT ══════════════════════════
local function ApplyClothing(data)
    local ped = PlayerPedId()
    if data and data.components then
        for idxStr, c in pairs(data.components) do
            SetPedComponentVariation(ped, tonumber(idxStr), c.drawable or 0, c.texture or 0, 0)
        end
    end
    if data and data.props then
        for idxStr, p in pairs(data.props) do
            local idx = tonumber(idxStr)
            if p.drawable and p.drawable >= 0 then
                SetPedPropIndex(ped, idx, p.drawable, p.texture or 0, true)
            else
                ClearPedProp(ped, idx)
            end
        end
    end
end

local function SnapshotCurrent()
    local ped = PlayerPedId()
    current = { components = {}, props = {} }
    for _, cat in ipairs(Config.Categories) do
        if cat.kind == 'component' then
            current.components[cat.index] = {
                drawable = GetPedDrawableVariation(ped, cat.index),
                texture = GetPedTextureVariation(ped, cat.index),
            }
        else
            current.props[cat.index] = {
                drawable = GetPedPropIndex(ped, cat.index),
                texture = GetPedPropTextureIndex(ped, cat.index),
            }
        end
    end
end

-- Catalog entries are matched by (drawable, texture) pair, not stored
-- as a separate "which catalog index am I on" piece of state — that
-- way switching a category's Config.ClothingCatalog around later, or
-- loading a saved outfit that predates it, never leaves stale index
-- bookkeeping behind. Returns nil (shown as "Custom" in the NUI) if
-- the current drawable/texture doesn't match any catalog entry.
local function FindCatalogIndex(catalog, drawable, texture)
    for i, entry in ipairs(catalog) do
        if entry.drawable == drawable and entry.texture == texture then return i end
    end
    return nil
end

local function CategoryPayload()
    local ped = PlayerPedId()
    local list = {}
    for _, cat in ipairs(Config.Categories) do
        local catalog = Config.ClothingCatalog[cat.id]
        local entry
        if cat.kind == 'component' then
            local state = current.components[cat.index] or { drawable = 0, texture = 0 }
            entry = {
                id = cat.id, label = cat.label, kind = 'component', index = cat.index,
                drawable = state.drawable, texture = state.texture,
                drawableCount = GetNumberOfPedDrawableVariations(ped, cat.index),
                textureCount = math.max(1, GetNumberOfPedTextureVariations(ped, cat.index, state.drawable)),
            }
        else
            local state = current.props[cat.index] or { drawable = -1, texture = 0 }
            entry = {
                id = cat.id, label = cat.label, kind = 'prop', index = cat.index, canRemove = cat.canRemove,
                drawable = state.drawable, texture = state.texture,
                drawableCount = GetNumberOfPedPropDrawableVariations(ped, cat.index),
                textureCount = state.drawable >= 0 and math.max(1, GetNumberOfPedPropTextureVariations(ped, cat.index, state.drawable)) or 1,
            }
        end

        if catalog and #catalog > 0 then
            local idx = FindCatalogIndex(catalog, entry.drawable, entry.texture)
            entry.hasCatalog = true
            entry.catalogCount = #catalog
            entry.catalogIndex = idx
            entry.catalogLabel = idx and catalog[idx].label or 'Custom'
        end

        list[#list + 1] = entry
    end
    return list
end

-- ═══════════════════════════ PREVIEW CAMERA ════════════════════════════
local function StartPreviewCam()
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local pheading = GetEntityHeading(ped)
    camHeading = pheading

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local off = Config.PreviewCamOffset
    local rad = math.rad(pheading)
    local camPos = vector3(
        pcoords.x + (off.x * math.cos(rad) - off.y * math.sin(rad)),
        pcoords.y + (off.x * math.sin(rad) + off.y * math.cos(rad)),
        pcoords.z + off.z + 0.55
    )
    SetCamCoord(previewCam, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.55, true)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 400, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
end

local function StopPreviewCam()
    RenderScriptCams(false, true, 300, true, true)
    if previewCam then DestroyCam(previewCam, false) previewCam = nil end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
end

-- Slow orbit while the menu's open, purely cosmetic — no mouse capture
-- needed since the NUI already owns focus.
CreateThread(function()
    while true do
        local sleep = 500
        if menuOpen and previewCam then
            sleep = 0
            camHeading = camHeading + 0.05
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local off = Config.PreviewCamOffset
            local orbitRad = math.rad(camHeading)
            local camPos = vector3(
                pcoords.x + (off.x * math.cos(orbitRad) - off.y * math.sin(orbitRad)),
                pcoords.y + (off.x * math.sin(orbitRad) + off.y * math.cos(orbitRad)),
                pcoords.z + off.z + 0.55
            )
            SetCamCoord(previewCam, camPos.x, camPos.y, camPos.z)
            PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.55, true)
        end
        Wait(sleep)
    end
end)

-- ═══════════════════════════ OPEN / CLOSE ══════════════════════════════
function OpenWardrobe(storeIndex)
    if menuOpen then return end
    menuOpen = true
    activeStoreIndex = storeIndex

    SnapshotCurrent()
    StartPreviewCam()
    SetNuiFocus(true, true)

    local storePayload = nil
    if storeIndex then
        local store = Config.Stores[storeIndex]
        storePayload = { label = store.label, price = store.OutfitPrice }
    end

    SendNUIMessage({
        action = 'open',
        atStore = storeIndex ~= nil,
        store = storePayload,
        maxOutfits = Config.MaxOutfits,
        categories = CategoryPayload(),
    })
    TriggerServerEvent('hd_clothing:server:getOutfits')
end

local function CloseWardrobe()
    if not menuOpen then return end
    menuOpen = false
    activeStoreIndex = nil
    StopPreviewCam()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.OpenCommand, function() OpenWardrobe(nil) end, false)

-- ═══════════════════════════ NUI CALLBACKS ═════════════════════════════
RegisterNUICallback('cycle', function(data, cb)
    local ped = PlayerPedId()
    local cat = nil
    for _, c in ipairs(Config.Categories) do if c.id == data.id then cat = c break end end
    if not cat then cb({}) return end

    -- A curated Config.ClothingCatalog entry for this category takes
    -- over the "drawable" arrows entirely — they step through the
    -- server's own named list instead of raw native variations, each
    -- entry setting both drawable and texture together as a matched
    -- pair. Texture cycling stays raw-native either way; a curated
    -- catalog entry already chose its own texture, there's nothing
    -- meaningful to layer a second raw texture cycle on top of it for.
    local catalog = Config.ClothingCatalog[cat.id]
    local useCatalog = catalog and #catalog > 0 and data.field == 'drawable'

    if cat.kind == 'component' then
        local state = current.components[cat.index] or { drawable = 0, texture = 0 }
        if useCatalog then
            local idx = FindCatalogIndex(catalog, state.drawable, state.texture) or 1
            idx = ((idx - 1 + data.delta) % #catalog) + 1
            state.drawable, state.texture = catalog[idx].drawable, catalog[idx].texture
        elseif data.field == 'drawable' then
            local count = GetNumberOfPedDrawableVariations(ped, cat.index)
            state.drawable = (state.drawable + data.delta) % math.max(1, count)
            state.texture = 0
        else
            local texCount = math.max(1, GetNumberOfPedTextureVariations(ped, cat.index, state.drawable))
            state.texture = (state.texture + data.delta) % texCount
        end
        current.components[cat.index] = state
        SetPedComponentVariation(ped, cat.index, state.drawable, state.texture, 0)
    else
        local state = current.props[cat.index] or { drawable = -1, texture = 0 }
        if useCatalog then
            local idx = FindCatalogIndex(catalog, state.drawable, state.texture) or 1
            idx = ((idx - 1 + data.delta) % #catalog) + 1
            state.drawable, state.texture = catalog[idx].drawable, catalog[idx].texture
        elseif data.field == 'drawable' then
            local count = GetNumberOfPedPropDrawableVariations(ped, cat.index)
            local lo = cat.canRemove and -1 or 0
            state.drawable = state.drawable + data.delta
            if state.drawable >= count then state.drawable = lo end
            if state.drawable < lo then state.drawable = count - 1 end
            state.texture = 0
        else
            if state.drawable >= 0 then
                local texCount = math.max(1, GetNumberOfPedPropTextureVariations(ped, cat.index, state.drawable))
                state.texture = (state.texture + data.delta) % texCount
            end
        end
        current.props[cat.index] = state
        if state.drawable >= 0 then
            SetPedPropIndex(ped, cat.index, state.drawable, state.texture, true)
        else
            ClearPedProp(ped, cat.index)
        end
    end

    cb(CategoryPayload())
end)

RegisterNUICallback('removeProp', function(data, cb)
    local cat = nil
    for _, c in ipairs(Config.Categories) do if c.id == data.id then cat = c break end end
    if cat and cat.kind == 'prop' then
        ClearPedProp(PlayerPedId(), cat.index)
        current.props[cat.index] = { drawable = -1, texture = 0 }
    end
    cb(CategoryPayload())
end)

RegisterNUICallback('save', function(data, cb)
    TriggerServerEvent('hd_clothing:server:saveOutfit', {
        label = data.label,
        components = current.components,
        props = current.props,
        storeIndex = activeStoreIndex,
    })
    cb({})
end)

RegisterNUICallback('wear', function(data, cb)
    TriggerServerEvent('hd_clothing:server:wearOutfit', data.id)
    cb({})
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
    TriggerServerEvent('hd_clothing:server:deleteOutfit', data.id)
    cb({})
end)

RegisterNUICallback('close', function(_, cb)
    CloseWardrobe()
    cb({})
end)

-- ═══════════════════════════ SERVER → CLIENT ═══════════════════════════
RegisterNetEvent('hd_clothing:client:outfitsList', function(list)
    SendNUIMessage({ action = 'outfits', list = list })
end)

RegisterNetEvent('hd_clothing:client:outfitApplied', function(data)
    ApplyClothing(data)
    if menuOpen then
        SnapshotCurrent()
        SendNUIMessage({ action = 'refreshCategories', categories = CategoryPayload() })
    end
end)

RegisterNetEvent('hd_clothing:client:saveResult', function(ok, msg)
    SendNUIMessage({ action = 'saveResult', ok = ok, msg = msg })
end)

-- Applies whatever this citizen was last wearing, the moment their
-- character finishes loading — same hook every other resource here
-- uses to react to HD_Framework's player-loaded event.
RegisterNetEvent('HD:Client:OnPlayerLoaded', function()
    TriggerServerEvent('hd_clothing:server:getMyClothing')
end)

-- ═══════════════════════════ STORE PEDS ════════════════════════════════
local storePeds = {}

CreateThread(function()
    for i, store in ipairs(Config.Stores) do
        local hash = GetHashKey(store.pedModel)
        RequestModel(hash)
        local waited = 0
        while not HasModelLoaded(hash) and waited < 5000 do Wait(50) waited = waited + 50 end
        if HasModelLoaded(hash) then
            local ped = CreatePed(4, hash, store.coords.x, store.coords.y, store.coords.z - 1.0, store.coords.w, false, true)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            storePeds[i] = ped
        end

        local b = AddBlipForCoord(store.coords.x, store.coords.y, store.coords.z)
        SetBlipSprite(b, 366)
        SetBlipColour(b, 3)
        SetBlipScale(b, 0.75)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(store.label)
        EndTextCommandSetBlipName(b)
    end
end)

local function Draw3DText(coords, text)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING') AddTextComponentString(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local sleep = 800
        if not menuOpen then
            local pc = GetEntityCoords(PlayerPedId())
            for i, store in ipairs(Config.Stores) do
                local dist = #(pc - store.coords.xyz)
                if dist < Config.InteractDistance then
                    sleep = 0
                    if dist < Config.InteractPressDistance then
                        Draw3DText(store.coords.xyz + vector3(0, 0, 1.0), ('[E] %s — Buy an outfit (£%d)'):format(store.label, store.OutfitPrice))
                        if IsControlJustReleased(0, 38) then
                            OpenWardrobe(i)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
