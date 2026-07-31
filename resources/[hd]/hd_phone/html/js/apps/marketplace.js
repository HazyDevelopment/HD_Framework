// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | MARKETPLACE
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let listings = [];
    let activeWin = null;

    HD.on('listings', (rows) => { listings = rows || []; if (activeWin) renderList(activeWin); });
    HD.on('listingCreated', () => HD.post('getListings', {}));

    function renderList(win) {
        win.innerHTML = `
            ${HD.backBar('Marketplace')}
            <div class="app-body">
                <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">
                    ${listings.length ? listings.map((l) => `
                        <div class="card" data-listing="${l.id}" style="overflow:hidden;">
                            <div style="width:100%;aspect-ratio:1;background:${l.image_url ? `url('${l.image_url}') center/cover` : 'var(--border)'};"></div>
                            <div style="padding:8px;">
                                <div style="font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${l.title}</div>
                                <div style="font-size:13px;color:var(--accent-2);font-weight:700;">£${l.price}</div>
                            </div>
                        </div>
                    `).join('') : `<div class="empty-state" style="grid-column:1/-1;">No listings yet.</div>`}
                </div>
            </div>
            <div class="fab" id="mkt-new">+</div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-listing]').forEach((el) => {
            el.onclick = () => {
                const l = listings.find((x) => String(x.id) === el.dataset.listing);
                if (l) renderDetail(win, l);
            };
        });
        win.querySelector('#mkt-new').onclick = () => renderCreate(win);
    }

    function renderDetail(win, l) {
        win.innerHTML = `
            ${HD.backBar('Listing')}
            <div class="app-body no-pad">
                <div style="width:100%;aspect-ratio:1.4;background:${l.image_url ? `url('${l.image_url}') center/cover` : 'var(--border)'};"></div>
                <div style="padding:16px;">
                    <div style="font-size:19px;font-weight:700;">${l.title}</div>
                    <div style="font-size:22px;color:var(--accent-2);font-weight:700;margin:6px 0;">£${l.price}</div>
                    <div style="font-size:14px;color:var(--text-dim);margin-bottom:14px;">${l.description || ''}</div>
                    <div style="font-size:13px;color:var(--text-dim);">Seller: ${l.seller_name} · ${l.seller_number}</div>
                </div>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderList(win);
    }

    function renderCreate(win) {
        win.innerHTML = `
            ${HD.backBar('New Listing')}
            <div class="app-body">
                <div class="field-group">
                    <input class="field" id="l-title" placeholder="Title" style="background:var(--surface-2);" />
                    <input class="field" id="l-price" type="number" placeholder="Price (£)" style="background:var(--surface-2);" />
                    <textarea class="field" id="l-desc" placeholder="Description" style="background:var(--surface-2);min-height:70px;resize:none;"></textarea>
                    <input class="field" id="l-image" placeholder="Image URL (optional)" style="background:var(--surface-2);" />
                </div>
                <button class="btn-primary" style="margin-top:16px;" id="l-submit">List Item</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderList(win);
        win.querySelector('#l-submit').onclick = () => {
            const title = win.querySelector('#l-title').value.trim();
            const price = parseInt(win.querySelector('#l-price').value, 10);
            const description = win.querySelector('#l-desc').value.trim();
            const imageUrl = win.querySelector('#l-image').value.trim();
            if (!title || !price) { HD.toast('Enter a title and price.'); return; }
            HD.post('createListing', { title, price, description, imageUrl });
            renderList(win);
        };
    }

    window.HDApps.marketplace = { open(win) { activeWin = win; renderList(win); HD.post('getListings', {}); } };
})();
