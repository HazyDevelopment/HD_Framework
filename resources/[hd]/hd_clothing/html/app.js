(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_clothing';
    const $ = (id) => document.getElementById(id);

    // Returns the parsed response body — cycle/removeProp's NUI callback
    // replies with the freshly-updated category list (client/main.lua's
    // cb(CategoryPayload())), which the caller needs to actually repaint
    // the control bar with the new drawable/texture number instead of
    // leaving it showing whatever it was at open.
    function post(action, data) {
        return fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => null);
    }

    function escapeHtml(str) {
        const d = document.createElement('div');
        d.textContent = str == null ? '' : String(str);
        return d.innerHTML;
    }

    // ═══════════════════════════ SIDEBAR ICONS ═══════════════════════════
    // Simple monochrome line glyphs, one per category id — a category
    // this doesn't have an entry for just falls back to a plain dot so a
    // future Config.Categories addition never renders a blank button.
    const ICONS = {
        mask: '<path d="M12 4a7 7 0 0 0-7 7v3a7 7 0 0 0 14 0v-3a7 7 0 0 0-7-7Z"/><circle cx="9.5" cy="12" r="1.1" fill="currentColor" stroke="none"/><circle cx="14.5" cy="12" r="1.1" fill="currentColor" stroke="none"/>',
        hair: '<path d="M4 13c0-5 3.5-9 8-9s8 4 8 9c-1.5-1.5-3-1-4-2.5-1 1.5-2.5 2-4 2s-3-.5-4-2c-1 1.5-2.5 1-4 2.5Z"/>',
        torso: '<path d="M8 4 4 6.5V10l2 .8V20h12v-9.2l2-.8V6.5L16 4c-.5 1.5-2 2.5-4 2.5S8.5 5.5 8 4Z"/>',
        undershirt: '<path d="M9 4 6 6v3l1.5.6V20h9V9.6L18 9V6l-3-2c-.3 1.2-1.5 2-3 2s-2.7-.8-3-2Z"/>',
        arms: '<path d="M7 4h10l2 6-3 1-1.5-4.5H16V20H8V6.5H8.5L7 11l-3-1Z"/>',
        legs: '<path d="M7 4h10l1 16h-4l-1-9-1 9H8Z"/>',
        shoes: '<path d="M5 15h4v-3l3 1 6 2c1.5.5 2 1.3 2 2.4V19H5Z"/>',
        bags: '<path d="M8 8V6a4 4 0 0 1 8 0v2h2l1 12H5L6 8Z" fill="none"/><path d="M9 8V6a3 3 0 0 1 6 0v2" fill="none"/>',
        accessory: '<path d="M4 9h4l4 3-4 3H4Z"/><path d="M20 9h-4l-4 3 4 3h4Z"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/>',
        armor: '<path d="M12 3 5 6v6c0 4 3 7.5 7 9 4-1.5 7-5 7-9V6Z"/>',
        hats: '<path d="M12 4a6 6 0 0 1 6 6v1H6v-1a6 6 0 0 1 6-6Z"/><rect x="4" y="11" width="16" height="2.5" rx="1" fill="currentColor" stroke="none"/>',
        glasses: '<circle cx="7" cy="13" r="3.2"/><circle cx="17" cy="13" r="3.2"/><path d="M10.2 13h3.6M3 12l1.2-3M21 12l-1.2-3"/>',
        ears: '<path d="M9 7a3 3 0 0 1 6 0v5a3 3 0 0 1-3 3 3 3 0 0 1-3-3"/><circle cx="12" cy="16.5" r="1.3" fill="currentColor" stroke="none"/>',
        watches: '<circle cx="12" cy="12" r="4.5"/><path d="M9.5 3h5l.5 3.5h-6ZM9.5 21h5l.5-3.5h-6Z"/>',
        bracelets: '<circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="2.5"/>',
    };
    function categoryIcon(id) {
        return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${ICONS[id] || '<circle cx="12" cy="12" r="3"/>'}</svg>`;
    }

    // ═══════════════════════════ STATE ═══════════════════════════════════
    let categories = [];
    let selectedId = null;

    function findCategory(id) { return categories.find((c) => c.id === id); }

    // ═══════════════════════════ SIDEBAR ═══════════════════════════════
    function renderSidebar() {
        const bar = $('sidebar');
        bar.innerHTML = categories.map((cat) => `
            <button class="sidebar-tab ${cat.id === selectedId ? 'active' : ''}" data-id="${cat.id}">
                ${categoryIcon(cat.id)}
                <span class="tab-tip">${escapeHtml(cat.label)}</span>
            </button>
        `).join('');
        bar.querySelectorAll('.sidebar-tab').forEach((btn) => {
            btn.addEventListener('click', () => { selectedId = btn.dataset.id; renderSidebar(); renderControlBar(); });
        });
    }

    // ═══════════════════════════ CONTROL BAR ════════════════════════════
    function renderControlBar() {
        const cat = findCategory(selectedId);
        if (!cat) return;

        $('controlLabel').textContent = cat.label;

        const drawableDisplay = cat.hasCatalog
            ? (cat.catalogLabel || 'Custom')
            : `${cat.drawable}/${Math.max(0, cat.drawableCount - 1)}`;
        $('ctrlDrawableValue').textContent = drawableDisplay;

        $('ctrlRemove').classList.toggle('hidden', !(cat.kind === 'prop' && cat.canRemove));

        // A curated catalog entry already chose its own texture as part
        // of the (drawable, texture) pair — no separate raw texture
        // cycle to show on top of it, same rule client/main.lua's cycle
        // handler applies.
        const showTexture = !cat.hasCatalog;
        $('controlTextureRow').classList.toggle('hidden', !showTexture);
        if (showTexture) {
            $('ctrlTextureValue').textContent = `${cat.texture}/${Math.max(0, cat.textureCount - 1)}`;
        }
    }

    function applyCategories(list) {
        categories = list || [];
        if (!selectedId || !findCategory(selectedId)) {
            selectedId = categories.length ? categories[0].id : null;
        }
        renderSidebar();
        renderControlBar();
    }

    function cycle(field, delta) {
        if (!selectedId) return;
        post('cycle', { id: selectedId, field, delta }).then((list) => { if (list) applyCategories(list); });
    }

    $('ctrlDrawablePrev').addEventListener('click', () => cycle('drawable', -1));
    $('ctrlDrawableNext').addEventListener('click', () => cycle('drawable', 1));
    $('ctrlTexturePrev').addEventListener('click', () => cycle('texture', -1));
    $('ctrlTextureNext').addEventListener('click', () => cycle('texture', 1));
    $('ctrlRemove').addEventListener('click', () => {
        if (!selectedId) return;
        post('removeProp', { id: selectedId }).then((list) => { if (list) applyCategories(list); });
    });

    // ═══════════════════════════ OUTFITS TAB ═════════════════════════════
    function renderOutfits(list) {
        const grid = $('outfitList');
        grid.innerHTML = '';
        $('outfitEmpty').classList.toggle('hidden', list.length > 0);

        list.forEach((o) => {
            const row = document.createElement('div');
            row.className = 'outfit-row';
            row.innerHTML = `
                <div class="outfit-name">${escapeHtml(o.label)}</div>
                <div class="outfit-actions">
                    <button class="outfit-btn outfit-wear">Wear</button>
                    <button class="outfit-btn outfit-del">Del</button>
                </div>`;
            row.querySelector('.outfit-wear').addEventListener('click', () => post('wear', { id: o.id }));
            row.querySelector('.outfit-del').addEventListener('click', () => post('deleteOutfit', { id: o.id }));
            grid.appendChild(row);
        });
    }

    // ═══════════════════════════ TABS ═════════════════════════════════
    document.querySelectorAll('.side-tab').forEach((tab) => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.side-tab').forEach((t) => t.classList.remove('active'));
            tab.classList.add('active');
            $('tabSave').classList.toggle('hidden', tab.dataset.tab !== 'save');
            $('tabOutfits').classList.toggle('hidden', tab.dataset.tab !== 'outfits');
        });
    });

    // ═══════════════════════════ SAVE / CLOSE ═════════════════════════════
    $('saveBtn').addEventListener('click', () => {
        const label = $('outfitName').value.trim();
        if (!label) return;
        post('save', { label });
    });

    $('closeBtn').addEventListener('click', () => post('close'));

    function showSaveMsg(ok, msg) {
        const el = $('saveMsg');
        el.textContent = msg || '';
        el.className = 'side-note ' + (ok ? 'ok' : 'err');
        el.classList.toggle('hidden', !msg);
        if (msg) setTimeout(() => el.classList.add('hidden'), 3500);
    }

    // ═══════════════════════════ NUI MESSAGE ROUTER ═════════════════════
    window.addEventListener('message', (event) => {
        const d = event.data;
        switch (d.action) {
            case 'open':
                $('root').classList.remove('hidden');
                $('panelSub').textContent = d.atStore
                    ? `${d.store.label} — buying an outfit here costs £${d.store.price}.`
                    : 'Free — try anything, save what you like.';
                $('saveBtn').textContent = d.atStore ? `Buy Outfit (£${d.store.price})` : 'Save Outfit';
                $('outfitName').value = '';
                showSaveMsg(true, '');
                applyCategories(d.categories || []);
                break;
            case 'refreshCategories':
                applyCategories(d.categories || []);
                break;
            case 'outfits':
                renderOutfits(d.list || []);
                break;
            case 'saveResult':
                showSaveMsg(d.ok, d.msg);
                break;
            case 'close':
                $('root').classList.add('hidden');
                break;
        }
    });

    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape' && !$('root').classList.contains('hidden')) post('close');
    });
})();
