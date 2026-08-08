-- ═══════════════════════════════════════════════════════════════════
--  HD ANTICHEAT | REPORTS
--  '/acreport' is open to every player, not just admins — it's the
--  direct line a player has when they've just watched someone do
--  something a normal player can't (fly, no-clip through a wall,
--  survive a headshot). Opens an NUI form (client/main.lua handles the
--  command; this file only ever receives the already-filled-in
--  title/message over 'hd_anticheat:server:submitReport') rather than
--  taking the report text as raw chat args. Persisted to
--  hd_anticheat_reports so the queue survives a restart, and pushed
--  live to any admin who already has the panel open (Reports tab data)
--  plus a dedicated right-side toast to EVERY currently on-duty admin
--  regardless of whether their panel is open at all — a report
--  shouldn't wait on someone happening to be looking at the Reports tab.
-- ═══════════════════════════════════════════════════════════════════

RecentReports = {} -- newest first, mirrors the DB — [1] is newest
local LastReportAt = {} -- [src] = os.time() of that player's last report, for the per-player cooldown

CreateThread(function()
    Wait(1800) -- after main.lua's own DB check has had a chance to print its warning first
    local rows = MySQL.query.await(
        'SELECT id, citizenid, reporter_name, title, message, x, y, z, status, created FROM hd_anticheat_reports ORDER BY id DESC LIMIT 100'
    ) or {}
    for _, row in ipairs(rows) do
        RecentReports[#RecentReports + 1] = {
            id = row.id, citizenid = row.citizenid, name = row.reporter_name,
            title = row.title, message = row.message,
            x = row.x, y = row.y, z = row.z, status = row.status, at = row.created,
        }
    end
end)

RegisterNetEvent('hd_anticheat:server:submitReport', function(title, message)
    local src = source
    if src == 0 then return end -- console has no in-world position to report from

    title = tostring(title or ''):sub(1, 100)
    message = tostring(message or ''):sub(1, 500)
    if title == '' or message == '' then
        Notify(src, 'Enter both a title and details for the report.', 'error')
        return
    end

    local last = LastReportAt[src]
    if last and (os.time() - last) * 1000 < Config.ReportCooldownMs then
        Notify(src, 'Please wait before submitting another report.', 'error')
        return
    end
    LastReportAt[src] = os.time()

    local ped = GetPlayerPed(src)
    local coords = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local name = GetPlayerName(src) or ('Player %d'):format(src)
    local citizenid = GetCitizenId(src)

    local id = MySQL.insert.await(
        'INSERT INTO hd_anticheat_reports (citizenid, reporter_name, title, message, x, y, z, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { citizenid, name, title, message, coords.x, coords.y, coords.z, 'open' }
    )

    local entry = {
        id = id, citizenid = citizenid, name = name, title = title, message = message,
        x = coords.x, y = coords.y, z = coords.z, status = 'open', at = os.time(),
    }
    table.insert(RecentReports, 1, entry)
    if #RecentReports > 200 then table.remove(RecentReports) end

    -- Full row data for anyone with the Reports tab already open...
    BroadcastToOpenPanels('report', entry)
    -- ...and a lightweight right-side toast (just the report number) for
    -- every on-duty admin, panel open or not — the NUI page is always
    -- loaded (ui_page), so this reaches them either way.
    for adminSrc in pairs(OnDuty) do
        TriggerClientEvent('hd_anticheat:client:push', adminSrc, 'reportNotify', { id = id })
    end

    TriggerClientEvent('hd_anticheat:client:reportSubmitted', src)
    Notify(src, 'Report submitted. An admin will review it shortly.', 'success')
end)

RegisterNetEvent('hd_anticheat:server:getReports', function()
    local src = source
    if not IsExemptAdmin(src) then return end
    TriggerClientEvent('hd_anticheat:client:push', src, 'reports', RecentReports)
end)

RegisterNetEvent('hd_anticheat:server:resolveReport', function(reportId)
    local src = source
    if not IsExemptAdmin(src) then return end
    local id = tonumber(reportId)
    if not id then return end

    MySQL.update('UPDATE hd_anticheat_reports SET status = ? WHERE id = ?', { 'resolved', id })
    for _, r in ipairs(RecentReports) do
        if r.id == id then r.status = 'resolved' break end
    end
    BroadcastToOpenPanels('reports', RecentReports)
end)
