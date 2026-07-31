-- ═══════════════════════════════════════════════════════════════════
--  hd_ems | client/panic.lua
--  /panic — resolves the medic's own street name (a client native,
--  can't be done server-side) and hands the rest off to the server,
--  which builds the actual hd_dispatch call + hd_radio tone.
-- ═══════════════════════════════════════════════════════════════════

local function StreetLabel()
    local coords = GetEntityCoords(PlayerPedId())
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name = GetStreetNameFromHashKey(street1)
    if street2 and street2 ~= 0 then name = name .. ' & ' .. GetStreetNameFromHashKey(street2) end
    return name
end

RegisterCommand(Config.Panic.Command, function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('hd_ems:server:panic', { x = coords.x, y = coords.y, z = coords.z }, StreetLabel())
end, false)
