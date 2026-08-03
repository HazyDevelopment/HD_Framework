-- ═══════════════════════════════════════════════════════════════════
--  HD_HUD | CLIENT — PLAYER HUD
--  Health/armour straight off the ped's own natives, hunger/thirst
--  from HD_Framework's PlayerData.metadata (real, persisted stats —
--  see HD_Framework/config.lua), cash/job from the same PlayerData.
--  Vehicle HUD + seatbelt logic live in client/vehicle.lua.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil
CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local ready = false
RegisterNetEvent('HD:Client:OnPlayerLoaded', function() ready = true end)
RegisterNetEvent('HD:Client:OnPlayerDataUpdate', function() end) -- just here so the event exists to hook if needed later

SendNUIMessage({ action = 'watermark', text = Config.Watermark.Text, color = Config.Watermark.Color })

-- ═══════════════════════════ CUSTOM MINIMAP ════════════════════════════
-- Still the native radar underneath — there's no way to draw real
-- street/blip data from scratch in NUI, every "custom minimap" FiveM
-- HUD (ox_hud, qb-hud, etc.) repositions/resizes the same native one
-- rather than reinventing it. SetMinimapComponentPosition moves it into
-- hd_hud's own layout instead of Rockstar's default corner square;
-- DisplayRadar(false) hides the whole thing — map, health/armour
-- (which ride along with the radar in GTA's own HUD, there's no native
-- to peel just one of them off independently) — while on foot, since
-- the vitals ring above is what covers health/armour there instead.
-- Shown only while driving, exactly the ask: hidden walking, visible
-- in a vehicle.
-- Shifted up from the default corner (vs. the commonly-cited base
-- values every "reposition the minimap" snippet starts from) so it
-- clears the vitals ring row sitting in the actual bottom-left corner
-- — same relative offsets between the three components, just the
-- whole cluster raised together.
-- ═══════════════════════════ /hudsettings ═════════════════════════════
-- Positions/visibility live entirely in the NUI's own localStorage
-- (html/js/app.js) — same client-only pattern as the loading screen's
-- volume slider, since there's nothing here worth persisting server-side.
-- This side just needs to hand NUI focus to the panel while it's open.
local hudSettingsOpen = false
RegisterCommand('hudsettings', function()
    hudSettingsOpen = not hudSettingsOpen
    SetNuiFocus(hudSettingsOpen, hudSettingsOpen)
    SendNUIMessage({ action = 'toggleSettings', show = hudSettingsOpen })
end, false)

RegisterNUICallback('closeHudSettings', function(_, cb)
    hudSettingsOpen = false
    SetNuiFocus(false, false)
    cb({})
end)

local function ApplyCustomMinimapLayout()
    -- minimap_mask governs what the game itself actually crops the
    -- radar texture to — it previously used different position/size
    -- fractions than 'minimap' itself, which is what was producing the
    -- big dark square block and off-centre map content the CSS ring
    -- couldn't paper over. Keeping mask and blur aligned to the exact
    -- same box as minimap removes that mismatch.
    SetMinimapComponentPosition('minimap', 'L', 'B', 0.0, -0.13, 0.1638, 0.183)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0, -0.13, 0.1638, 0.183)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', 0.0, -0.13, 0.1638, 0.183)
end
ApplyCustomMinimapLayout()

CreateThread(function()
    while true do
        Wait(0)
        local inVeh = IsPedInAnyVehicle(PlayerPedId(), false)
        DisplayRadar(inVeh)
    end
end)

-- GTA's own health range is effectively [100, maxHealth] — 100 is the
-- "about to die" floor the native minimap health bar itself uses, not
-- 0 — so a naive 0-maxHealth percentage reads as still-mostly-full
-- right up until death. Clamped the same way the native HUD does it.
local function HealthPercent(ped)
    local health = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    if maxHealth <= 100 then return 0 end
    return math.max(0, math.min(100, math.floor(((health - 100) / (maxHealth - 100)) * 100)))
end

CreateThread(function()
    while true do
        Wait(Config.UpdateMs)
        if ready and Framework then
            local ped = PlayerPedId()
            local pd = Framework.Functions.GetPlayerData()
            local meta = pd.metadata or {}
            local armor = GetPedArmour(ped)

            SendNUIMessage({
                action = 'vitals',
                health = HealthPercent(ped),
                armor = armor > 0 and math.max(0, math.min(100, armor)) or nil,
                hunger = math.floor(meta.hunger or 100),
                thirst = math.floor(meta.thirst or 100),
                cash = (pd.money and pd.money.cash) or 0,
                jobLabel = (pd.job and pd.job.label) or 'Unemployed',
                jobGrade = (pd.job and pd.job.grade and pd.job.grade.name) or nil,
                lowThreshold = Config.LowWarningPercent,
            })
        end
    end
end)
