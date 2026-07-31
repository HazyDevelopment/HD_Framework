// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | PHOTOS
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let cache = [];
    let activeWin = null;

    HD.on('photos', (rows) => { cache = rows || []; if (activeWin) renderGrid(activeWin); });

    function renderGrid(win) {
        win.innerHTML = `
            ${HD.backBar('Photos')}
            <div class="app-body">
                ${cache.length ? `<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:4px;">
                    ${cache.map((p) => `<div data-photo="${p.id}" style="aspect-ratio:1;background:url('${p.image_url}') center/cover, var(--surface-2);border-radius:4px;cursor:pointer;"></div>`).join('')}
                </div>` : `<div class="empty-state">No photos yet. Take one with the Camera app.</div>`}
            </div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-photo]').forEach((el) => {
            el.onclick = () => {
                const p = cache.find((x) => String(x.id) === el.dataset.photo);
                if (p) renderViewer(win, p);
            };
        });
    }

    function renderViewer(win, photo) {
        win.innerHTML = `
            <div style="position:absolute;inset:0;background:#000;display:flex;align-items:center;justify-content:center;">
                <img src="${photo.image_url}" style="max-width:100%;max-height:100%;object-fit:contain;" />
            </div>
            <div style="position:absolute;top:54px;left:18px;z-index:2;">
                <div class="lock-quick-btn" id="viewer-back" style="background:rgba(0,0,0,0.4);">${chevronBack()}</div>
            </div>`;
        win.querySelector('#viewer-back').onclick = () => renderGrid(win);
    }
    function chevronBack() { return `<svg width="10" height="16" viewBox="0 0 10 16" fill="none" stroke="#fff" stroke-width="2.2"><path d="M8 1 1.5 8 8 15"/></svg>`; }

    window.HDApps.photos = {
        open(win) { activeWin = win; renderGrid(win); HD.post('getPhotos', {}); },
    };
})();
