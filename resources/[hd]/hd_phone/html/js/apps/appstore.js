// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | APP STORE
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let activeWin = null;

    function grouped() {
        const groups = {};
        HD.state.apps.filter((a) => !a.core).forEach((a) => {
            const cat = a.category || 'Other';
            (groups[cat] = groups[cat] || []).push(a);
        });
        return groups;
    }

    function render(win) {
        const installedSet = new Set(HD.state.installedApps);
        const groups = grouped();
        win.innerHTML = `
            ${HD.backBar('App Store')}
            <div class="app-body">
                ${Object.keys(groups).map((cat) => `
                    <div class="section-title">${cat}</div>
                    ${groups[cat].map((a) => `
                        <div class="list-row">
                            <div class="app-icon" style="width:44px;height:44px;">${HD.iconSvg(a.icon, 26)}</div>
                            <div class="list-main"><div class="title">${a.label}</div></div>
                            <button class="btn-ghost" data-app="${a.id}" data-installed="${installedSet.has(a.id) ? '1' : '0'}" style="color:${installedSet.has(a.id) ? 'var(--danger)' : 'var(--accent)'};font-weight:700;">
                                ${installedSet.has(a.id) ? 'Remove' : 'Get'}
                            </button>
                        </div>
                    `).join('')}
                `).join('')}
            </div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-app]').forEach((btn) => {
            btn.onclick = () => {
                const id = btn.dataset.app;
                if (btn.dataset.installed === '1') HD.post('removeApp', { appId: id });
                else HD.post('installApp', { appId: id });
            };
        });
    }

    window.HDApps.appstore = {
        open(win) { activeWin = win; render(win); },
        refresh() { if (activeWin) render(activeWin); },
    };
})();
