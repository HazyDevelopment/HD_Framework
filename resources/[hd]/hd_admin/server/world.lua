-- ═══════════════════════════════════════════════════════════════════
--  HD ADMIN | WORLD CONTROLS
-- ═══════════════════════════════════════════════════════════════════

RegisterNetEvent('hd_admin:server:setWeather', function(weatherType)
    local src = source
    if not IsAdmin(src) then return end

    local valid = false
    for _, w in ipairs(Config.WeatherTypes) do
        if w == weatherType then valid = true break end
    end
    if not valid then Notify(src, 'Unknown weather type.', 'error') return end

    TriggerClientEvent('hd_admin:client:setWeather', -1, weatherType)
    Notify(src, ('Weather set to %s.'):format(weatherType), 'success')
end)

RegisterNetEvent('hd_admin:server:setTime', function(hour)
    local src = source
    if not IsAdmin(src) then return end

    hour = tonumber(hour)
    if not hour or hour < 0 or hour > 23 then Notify(src, 'Hour must be 0-23.', 'error') return end

    TriggerClientEvent('hd_admin:client:setTime', -1, hour)
    Notify(src, ('Time set to %02d:00.'):format(hour), 'success')
end)

RegisterNetEvent('hd_admin:server:announce', function(message)
    local src = source
    if not IsAdmin(src) then return end

    message = tostring(message or ''):sub(1, 300)
    if message == '' then Notify(src, 'Message is empty.', 'error') return end

    TriggerClientEvent('hd_admin:client:announce', -1, message)
end)
