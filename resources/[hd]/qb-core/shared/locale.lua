-- ═══════════════════════════════════════════════════════════════════
--  QB-CORE COMPATIBILITY BRIDGE | LOCALE SHIM
--  uk_policejob and uk_uhsjob are compiled/escrowed resources that
--  hard-require '@qb-core/shared/locale.lua' as a file include (see
--  their fxmanifest.lua shared_scripts). This file exists purely so
--  that include resolves and both resources start — it's a minimal,
--  never-throws translation shim, not a reproduction of any specific
--  third-party locale file. Anything not registered in Locales['en']
--  just falls back to showing the raw key, which is harmless.
--
--  If you'd rather have proper English strings everywhere those two
--  resources use Lang:t(...), drop a real populated Locales['en']
--  table in here — nothing else needs to change.
-- ═══════════════════════════════════════════════════════════════════

Locales = Locales or {}
Locales['en'] = Locales['en'] or {}

local function interpolate(str, subs)
    if not subs then return str end
    return (str:gsub('%%{(.-)}', function(key)
        local v = subs[key]
        return v ~= nil and tostring(v) or ('%{' .. key .. '}')
    end))
end

Lang = {}

function Lang:t(key, subs)
    local str = Locales['en'][key] or key
    return interpolate(str, subs)
end

-- Some QBCore-ecosystem resources call a global _() helper instead of
-- Lang:t(...) directly.
function _(key, subs)
    return Lang:t(key, subs)
end
