-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | client/armoury.lua
--  Armoury marker + NUI wiring. Drawing/returning gives/removes real
--  hd_inventory items — no native weapon give/remove happens here at
--  all anymore; hd_inventory's own client/main.lua owns equip-toggle
--  for weapon-type items via its generic "Use" flow. The server
--  (server/armoury.lua) is always the source of truth on what an
--  officer is allowed to draw; this file just renders what it hands
--  back.
-- ═══════════════════════════════════════════════════════════════════

local armouryOpen = false

local function IsPolice()
    if not Framework then return false end
    local pd = Framework.Functions.GetPlayerData()
    return pd and pd.job and pd.job.name == Config.JobName
end

local function Draw3DText(coords, text)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING') AddTextComponentString(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function OpenArmoury()
    if armouryOpen then return end
    Framework.Functions.TriggerCallback('hdpolice:getArmoury', function(data)
        if not data then
            TriggerEvent('HD:Client:Notify', 'You must be on duty to access the armoury.', 'error')
            return
        end
        armouryOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            rankLabel = data.rankLabel,
            grade = data.grade,
            isArmedResponse = data.isArmedResponse,
            catalog = data.catalog,
        })
    end)
end

local function CloseArmoury()
    armouryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

CreateThread(function()
    while true do
        local sleep = 800
        if IsPolice() and not armouryOpen then
            local pc = GetEntityCoords(PlayerPedId())
            for _, station in ipairs(Config.Stations) do
                local dist = #(pc - station.Armoury.xyz)
                if dist < Config.InteractDistance then
                    sleep = 0
                    DrawMarker(2, station.Armoury.x, station.Armoury.y, station.Armoury.z + 0.4,
                        0,0,0, 0,0,0, 0.4,0.4,0.4, 30,80,180,180, true, true)
                    if dist < Config.InteractPressDistance then
                        Draw3DText(station.Armoury.xyz + vector3(0,0,1.0), '[E] Open Armoury')
                        if IsControlJustReleased(0, 38) then OpenArmoury() end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNUICallback('close', function(_, cb)
    CloseArmoury()
    cb('ok')
end)

RegisterNUICallback('drawItem', function(data, cb)
    TriggerServerEvent('hdpolice:server:drawItem', data.name)
    cb('ok')
end)

RegisterNUICallback('drawLoadout', function(_, cb)
    TriggerServerEvent('hdpolice:server:drawLoadout')
    cb('ok')
end)

RegisterNUICallback('returnItem', function(data, cb)
    TriggerServerEvent('hdpolice:server:returnItem', data.name)
    cb('ok')
end)

RegisterNUICallback('returnLoadout', function(_, cb)
    TriggerServerEvent('hdpolice:server:returnLoadout')
    cb('ok')
end)
