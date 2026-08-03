-- ═══════════════════════════════════════════════════════════════════
--  hd_policejob | client/detain.lua
--  Receiving end of /detain — frozen at the holding cell for the
--  duration, same "frozen, controls disabled, released later" shape
--  as hd_ems's downed state. Server owns the actual timer; this is
--  presentation + a client-side countdown display only.
-- ═══════════════════════════════════════════════════════════════════

local detained = false
local releaseAt = 0

local function Draw3DText(coords, text)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING') AddTextComponentString(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

RegisterNetEvent('hdpolice:client:detained', function(holdSeconds, cell)
    detained = true
    releaseAt = GetGameTimer() + (holdSeconds * 1000)

    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(450)
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, cell.x, cell.y, cell.z, false, false, false)
    SetEntityHeading(ped, cell.w or 0.0)
    FreezeEntityPosition(ped, true)
    Wait(200)
    DoScreenFadeIn(400)
end)

local function Release()
    local ped = PlayerPedId()
    detained = false
    FreezeEntityPosition(ped, false)
end

RegisterNetEvent('hdpolice:client:released', function()
    if not detained then return end
    Release()
end)

CreateThread(function()
    while true do
        local sleep = 500
        if detained then
            sleep = 0
            DisableControlAction(0, 30, true)  -- move left/right
            DisableControlAction(0, 31, true)  -- move up/down
            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 22, true)  -- jump
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 23, true)  -- enter vehicle
            DisableControlAction(0, 37, true)  -- weapon wheel

            local remaining = math.max(0, math.ceil((releaseAt - GetGameTimer()) / 1000))
            local mins, secs = math.floor(remaining / 60), remaining % 60
            Draw3DText(GetEntityCoords(PlayerPedId()) + vector3(0.0, 0.0, 1.0),
                ('Detained — released in %02d:%02d'):format(mins, secs))
        end
        Wait(sleep)
    end
end)
