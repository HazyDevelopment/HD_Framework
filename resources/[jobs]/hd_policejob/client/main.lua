-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | client/main.lua
--  Station blips + the clock-in interaction.
-- ═══════════════════════════════════════════════════════════════════

Framework = nil

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    Framework = exports['HD_Framework']:GetCoreObject()
end)

local function IsPolice()
    if not Framework then return false end
    local pd = Framework.Functions.GetPlayerData()
    return pd and pd.job and pd.job.name == Config.JobName
end

CreateThread(function()
    for _, station in ipairs(Config.Stations) do
        local b = AddBlipForCoord(station.ClockIn.x, station.ClockIn.y, station.ClockIn.z)
        SetBlipSprite(b, 60)
        SetBlipColour(b, 38)
        SetBlipScale(b, 0.85)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(station.label)
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
        if IsPolice() then
            local pc = GetEntityCoords(PlayerPedId())
            for _, station in ipairs(Config.Stations) do
                local dist = #(pc - station.ClockIn.xyz)
                if dist < Config.InteractDistance then
                    sleep = 0
                    DrawMarker(2, station.ClockIn.x, station.ClockIn.y, station.ClockIn.z + 0.4,
                        0,0,0, 0,0,0, 0.4,0.4,0.4, 30,80,180,180, true, true)
                    if dist < Config.InteractPressDistance then
                        local onduty = Framework.Functions.GetPlayerData().job.onduty
                        Draw3DText(station.ClockIn.xyz + vector3(0,0,1.0),
                            onduty and '[E] Clock Off Duty' or '[E] Clock On Duty')
                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('hdpolice:server:toggleDuty')
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
