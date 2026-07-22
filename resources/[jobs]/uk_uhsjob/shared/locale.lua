-- ═══════════════════════════════════════════════════════════════════
--  LOCALE SHIM
--  Previously included from an external 'qb-core' bridge resource
--  (@qb-core/shared/locale.lua); now self-contained since this server
--  no longer runs a qb-core-named resource at all. A minimal,
--  never-throws translation shim, not a reproduction of any specific
--  third-party locale file. Anything not registered in Locales['en']
--  just falls back to showing the raw key, which is harmless. Drop a
--  real populated Locales['en'] table in here for proper strings.
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

function _(key, subs)
    return Lang:t(key, subs)
end
