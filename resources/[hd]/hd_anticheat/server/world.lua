-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | WORLD TAB
--  Separate from hd_admin's own server/world.lua (weather/time/its own
--  announce) — this resource's World tab is scoped to exactly what an
--  anticheat panel needs: clearing stray/broken props, and a way to
--  reach every player at once when something needs saying urgently
--  (e.g. "everyone hold still, dealing with a mod-menu incident").
-- ═══════════════════════════════════════════════════════════════════

-- See config.lua's WorldResetRadius comment for why this is a broadcast
-- to every client rather than one server-side call — there's no native
-- that resets the whole map at once, so each client is asked to tidy up
-- the area around wherever it actually is.
RegisterNetEvent('hd_anticheat:server:worldReset', function()
    local src = source
    if not IsExemptAdmin(src) then return end
    TriggerClientEvent('hd_anticheat:client:worldReset', -1, Config.WorldResetRadius)
    Notify(src, 'World reset dispatched — clearing stray objects near every connected player.', 'success')
end)

RegisterNetEvent('hd_anticheat:server:announce', function(message)
    local src = source
    if not IsExemptAdmin(src) then return end

    message = tostring(message or ''):sub(1, 300)
    if message == '' then
        Notify(src, 'Message is empty.', 'error')
        return
    end

    local Admin = Framework and Framework.Functions.GetPlayer(src)
    local adminName = Admin and (Admin.PlayerData.charinfo.firstname .. ' ' .. Admin.PlayerData.charinfo.lastname) or 'Console'

    -- -1 = every connected client, sender included — same broadcast
    -- target hd_admin's own announce uses for exactly the same reason:
    -- an admin reading their own announcement back confirms it actually
    -- went out.
    TriggerClientEvent('hd_anticheat:client:announce', -1, message, adminName)
end)
