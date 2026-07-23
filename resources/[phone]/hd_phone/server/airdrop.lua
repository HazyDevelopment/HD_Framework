-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | AIRDROP
--  Broadcast-to-nearby contact share. No storage of its own — accepting
--  just triggers the same hd_phone:server:saveContact event Contacts
--  already uses, so it's saved for whoever accepted, same as if they'd
--  typed it in by hand.
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('hd_phone:server:airdropShare', function()
    local src = source
    local Player = Framework.Functions.GetPlayer(src)
    if not Player then return end

    local myNumber = GetPhoneNumber(src)
    local myName = GetDisplayName(src)
    if not myNumber then return end

    local myPed = GetPlayerPed(src)
    if not myPed or myPed == 0 then return end
    local myCoords = GetEntityCoords(myPed)

    local sent = 0
    for _, targetId in ipairs(Framework.Functions.GetPlayers()) do
        if targetId ~= src then
            local targetPed = GetPlayerPed(targetId)
            if targetPed and targetPed ~= 0 then
                local dist = #(myCoords - GetEntityCoords(targetPed))
                if dist <= Config.Airdrop.Radius then
                    TriggerClientEvent('hd_phone:client:airdropIncoming', targetId, { name = myName, number = myNumber })
                    sent = sent + 1
                end
            end
        end
    end

    TriggerClientEvent('HD:Client:Notify', src, sent > 0 and ('Shared with %d nearby.'):format(sent) or 'Nobody nearby.', sent > 0 and 'success' or 'error')
end)
