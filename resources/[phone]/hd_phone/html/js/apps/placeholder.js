// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | PLACEHOLDER
//  Shown for any app id without a dedicated handler yet.
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    window.HDApps.placeholder = {
        open(win, app) {
            win.innerHTML = `
                ${HD.backBar(app.label)}
                <div class="app-body">
                    <div class="empty-state">
                        <div style="margin-bottom:8px;">${HD.iconSvg(app.icon, 48)}</div>
                        <div style="font-size:16px;font-weight:600;color:var(--text);">${app.label}</div>
                        <div>Coming soon.</div>
                    </div>
                </div>`;
            HD.bindBack(win);
        },
    };
})();
