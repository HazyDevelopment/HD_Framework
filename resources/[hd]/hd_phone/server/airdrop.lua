-- ═══════════════════════════════════════════════════════════════════
--  HD PHONE | AIRDROP
--  Broadcasts to every other online phone within Config.Airdrop.Radius
--  whose receive_drop setting is on; accepting just runs a normal
--  Contacts save on their end.
-- ═══════════════════════════════════════════════════════════════════

local PendingOffers = {} -- targetSrc -> { fromSrc, fromName, fromNumber }

RegisterNetEvent('hd_phone:server:sendAirdrop', function(x, y, z)
    local src = source
    local Player = GetPlayerOrNil(src)
    if not Player then return end
    local myCoords = vector3(x + 0.0, y + 0.0, z + 0.0)
    local myName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    local myNumber = Player.PlayerData.charinfo.phone

    local sent = 0
    for _, srcStr in ipairs(GetPlayers()) do
        local candidate = tonumber(srcStr)
        if candidate ~= src then
            local ped = GetPlayerPed(candidate)
            if ped and ped ~= 0 then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist <= Config.Airdrop.Radius then
                    local settings = GetOrCreateSettings(GetPlayerOrNil(candidate) and GetPlayerOrNil(candidate).PlayerData.citizenid or '')
                    if settings.receive_drop == 1 then
                        PendingOffers[candidate] = { fromSrc = src, fromName = myName, fromNumber = myNumber }
                        TriggerClientEvent('hd_phone:client:airdropOffer', candidate, myName, myNumber)
                        sent = sent + 1
                    end
                end
            end
        end
    end
    Notify(src, ('AirDrop sent to %d nearby phone(s).'):format(sent), sent > 0 and 'success' or 'error')
end)

RegisterNetEvent('hd_phone:server:airdropRespond', function(accept)
    local src = source
    local offer = PendingOffers[src]
    PendingOffers[src] = nil
    if not offer then return end
    if not accept then return end

    local Player = GetPlayerOrNil(src)
    if not Player then return end
    MySQL.query.await([[
        INSERT INTO hd_phone_contacts (owner, name, number) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name)
    ]], { Player.PlayerData.citizenid, offer.fromName, offer.fromNumber })
    Notify(src, ('Saved %s to Contacts.'):format(offer.fromName), 'success')
end)
