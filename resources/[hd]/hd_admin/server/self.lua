-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | SELF TOOLS (noclip / godmode / spectate)
--  These three used to be pure client-side NUI callbacks with no
--  server round trip at all — every other action in this resource
--  re-checks IsAdmin(src) server-side, these didn't, which meant a
--  forged NUI callback (no real admin panel needed) could grant
--  noclip/invincibility to anyone. Routed through here now so they
--  follow the same "server owns the real permission check" pattern as
--  everything else, and so hd_anticheat has an actual admin identity
--  to exempt rather than trusting whatever the client claims.
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('hd_admin:server:toggleNoclip', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('hd_admin:client:toggleNoclip', src)
end)

RegisterNetEvent('hd_admin:server:toggleGodmode', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('hd_admin:client:toggleGodmode', src)
end)

-- Spectate: the spectator's own ped is frozen/hidden client-side while
-- their camera follows the target — no teleporting involved, so there's
-- nothing here for hd_anticheat's position checks to even see. Only the
-- IsAdmin gate matters; the target doesn't need to consent (same as
-- every other admin power in this panel).
RegisterNetEvent('hd_admin:server:startSpectate', function(targetId)
    local src = source
    if not IsAdmin(src) then return end
    local id = tonumber(targetId)
    local targetPed = id and GetPlayerPed(id)
    if not targetPed or targetPed == 0 then
        Notify(src, 'Player not found.', 'error')
        return
    end
    TriggerClientEvent('hd_admin:client:startSpectate', src, id)
end)

RegisterNetEvent('hd_admin:server:stopSpectate', function()
    local src = source
    if not IsAdmin(src) then return end
    TriggerClientEvent('hd_admin:client:stopSpectate', src)
end)
