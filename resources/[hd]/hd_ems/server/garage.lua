-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | server/garage.lua
--  Vehicle list is job + rank gated server-side, not just hidden
--  client-side, so pulling a vehicle always re-checks access.
-- ═══════════════════════════════════════════════════════════════════

CreateThread(function()
    while GetResourceState('HD_Framework') ~= 'started' do Wait(100) end
    while not Framework do Wait(50) end

    Framework.Functions.CreateCallback('hd_ems:server:getGarageVehicles', function(src, cb)
        local ok, Player = EMS.IsOnDutyAmbulance(src)
        if not ok then return cb({}) end

        local list = {}
        for _, v in ipairs(Config.GarageVehicles) do
            if Player.PlayerData.job.grade.level >= (v.minGrade or 0) then
                list[#list + 1] = { model = v.model, label = v.label }
            end
        end
        cb(list)
    end)

    Framework.Functions.CreateCallback('hd_ems:server:requestVehicle', function(src, cb, model)
        local ok, Player = EMS.IsOnDutyAmbulance(src)
        if not ok then return cb(false) end

        local allowed = false
        for _, v in ipairs(Config.GarageVehicles) do
            if v.model == model and Player.PlayerData.job.grade.level >= (v.minGrade or 0) then
                allowed = true
                break
            end
        end
        cb(allowed)
    end)
end)
