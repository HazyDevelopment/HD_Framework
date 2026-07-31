// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | GARAGES
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let vehicles = [];
    let activeWin = null;

    HD.on('vehicles', (rows) => { vehicles = rows || []; if (activeWin) render(activeWin); });
    HD.on('vehicleStored', () => HD.post('getVehicles', {}));

    function render(win) {
        win.innerHTML = `
            ${HD.backBar('Garages')}
            <div class="app-body">
                ${vehicles.length ? vehicles.map((v) => `
                    <div class="list-row">
                        <div class="list-avatar" style="background:linear-gradient(160deg,#818cf8,#4338ca);">${carGlyph()}</div>
                        <div class="list-main"><div class="title">${v.vehicle}</div><div class="subtitle">${v.plate} · ${v.state === 1 ? 'Garaged' : 'Out'}</div></div>
                        <button class="btn-ghost" data-vehicle-action="${v.plate}" data-state="${v.state}" data-garage="${v.garage || ''}">${v.state === 1 ? 'Retrieve' : 'Store'}</button>
                    </div>
                `).join('') : `<div class="empty-state">No vehicles yet.</div>`}
            </div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-vehicle-action]').forEach((btn) => {
            btn.onclick = () => {
                const plate = btn.dataset.vehicleAction;
                if (btn.dataset.state === '1') {
                    HD.post('retrieveVehicle', { plate, garageKey: btn.dataset.garage });
                } else {
                    HD.post('storeVehicle', { garageKey: 'legion' }).then((res) => {
                        if (res && res.ok === false) HD.toast(res.reason);
                    });
                }
            };
        });
    }
    function carGlyph() { return `<svg width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M4 16v-3l2-5a2 2 0 0 1 2-1.3h8A2 2 0 0 1 18 8l2 5v3a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-1H6v1a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1Z"/><circle cx="7.5" cy="15" r="1.2" fill="#4338ca"/><circle cx="16.5" cy="15" r="1.2" fill="#4338ca"/></svg>`; }

    window.HDApps.garages = { open(win) { activeWin = win; render(win); HD.post('getVehicles', {}); } };
})();
