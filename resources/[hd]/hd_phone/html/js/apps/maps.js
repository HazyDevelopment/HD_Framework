// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | MAPS
//  A curated pin list rather than a rendered map image (no licensed
//  map asset to draw one from) — tapping a pin sets a real waypoint.
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};

    const CAT_ICON = { garage: '🚗', hospital: '🏥', police: '👮' };

    function render(win, pins) {
        win.innerHTML = `
            ${HD.backBar('Maps')}
            <div class="app-body">
                ${pins.map((p) => `
                    <div class="list-row" data-pin='${JSON.stringify({ x: p.x, y: p.y })}'>
                        <div class="list-avatar">${CAT_ICON[p.category] || '📍'}</div>
                        <div class="list-main"><div class="title">${p.label}</div></div>
                        <div class="list-meta" style="color:var(--accent);">Go</div>
                    </div>
                `).join('')}
                <button class="btn-primary" style="margin-top:16px;" id="maps-share">Share My Location</button>
            </div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-pin]').forEach((row) => {
            row.onclick = () => { HD.post('setWaypoint', JSON.parse(row.dataset.pin)); HD.toast('Waypoint set.'); };
        });
        win.querySelector('#maps-share').onclick = () => {
            HD.post('getStreetName', {}).then((res) => {
                HD.toast(`Location shared: ${res.name || 'Unknown street'}`);
            });
        };
    }

    window.HDApps.maps = {
        open(win) {
            HD.post('getMapPins', {}).then((res) => render(win, res.pins || []));
        },
    };
})();
