(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_inventory';
    const HOTBAR_SLOTS = 5; // mirrors Config.HotbarSlots in config.lua
    const TITLES = { player: 'Inventory', stash: 'Stash', glovebox: 'Glovebox', trunk: 'Trunk', drop: 'Ground' };

    let panels = { left: null, right: null };
    let dragging = null; // { side, slot, item, amount, locked }
    let ctxTarget = null; // { side, slot, item }

    const $ = (id) => document.getElementById(id);

    function post(action, data) {
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function escapeHtml(str) {
        const d = document.createElement('div');
        d.textContent = str == null ? '' : String(str);
        return d.innerHTML;
    }

    function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

    function colorFor(name) {
        let hash = 0;
        for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
        return `hsl(${Math.abs(hash) % 360}, 55%, 45%)`;
    }

    // ═══════════════════════════ RENDER: HOTBAR ═══════════════════════
    function renderHotbar() {
        const hb = $('hotbar');
        if (!panels.left) { hb.classList.add('hidden'); return; }
        hb.classList.remove('hidden');
        hb.innerHTML = '';
        for (let i = 1; i <= HOTBAR_SLOTS; i++) {
            const item = panels.left.slots[String(i)];
            const el = document.createElement('div');
            el.className = 'hotbar-slot';
            el.innerHTML = `<span class="hotbar-key">${i}</span>` +
                (item ? `<div class="item-tile" style="--c:${colorFor(item.name)}">${HD_ICONS.get(item.name)}</div>${item.amount > 1 ? `<span class="hotbar-amount">${item.amount}</span>` : ''}` : '');
            hb.appendChild(el);
        }
    }

    // ═══════════════════════════ RENDER: PANEL ═════════════════════════
    function renderPanel(side) {
        const panel = panels[side];
        const panelEl = $(`panel-${side}`);
        if (!panel) { panelEl.classList.add('hidden'); return; }
        panelEl.classList.remove('hidden');

        $(`title${cap(side)}`).textContent = TITLES[panel.type] || panel.type;
        const pct = panel.maxWeight ? Math.min(100, (panel.currentWeight / panel.maxWeight) * 100) : 0;
        const fill = $(`weightFill${cap(side)}`);
        fill.style.width = `${pct}%`;
        fill.classList.toggle('over', panel.currentWeight > panel.maxWeight);
        $(`weightText${cap(side)}`).textContent = `${(panel.currentWeight / 1000).toFixed(1)}kg / ${(panel.maxWeight / 1000).toFixed(1)}kg`;

        const grid = $(`grid-${side}`);
        grid.innerHTML = '';
        for (let i = 1; i <= panel.maxSlots; i++) {
            const item = panel.slots[String(i)];
            const cell = document.createElement('div');
            cell.className = 'slot' + (item ? '' : ' empty');
            cell.dataset.side = side;
            cell.dataset.slot = i;

            if (item) {
                cell.innerHTML = `<div class="item-tile" style="--c:${colorFor(item.name)}">${HD_ICONS.get(item.name)}</div>` +
                    (item.amount > 1 ? `<span class="item-amount">${item.amount}</span>` : '');
                cell.addEventListener('mouseenter', (e) => showTooltip(e, item));
                cell.addEventListener('mousemove', moveTooltip);
                cell.addEventListener('mouseleave', hideTooltip);
                cell.addEventListener('mousedown', (e) => { if (e.button === 0) startDrag(e, side, i, item); });
                cell.addEventListener('contextmenu', (e) => { e.preventDefault(); openContextMenu(e, side, i, item); });
            }
            grid.appendChild(cell);
        }
    }

    // ═══════════════════════════ TOOLTIP ═══════════════════════════════
    function showTooltip(e, item) {
        const tip = $('tooltip');
        tip.innerHTML = `
            <div class="tooltip-title">${escapeHtml(item.label)}</div>
            ${item.description ? `<div class="tooltip-desc">${escapeHtml(item.description)}</div>` : ''}
            <div class="tooltip-weight">${(item.weight / 1000).toFixed(2)}kg each${item.amount > 1 ? ` · x${item.amount}` : ''}</div>`;
        tip.classList.remove('hidden');
        moveTooltip(e);
    }
    function moveTooltip(e) {
        const tip = $('tooltip');
        tip.style.left = `${e.clientX + 16}px`;
        tip.style.top = `${e.clientY + 16}px`;
    }
    function hideTooltip() { $('tooltip').classList.add('hidden'); }

    // ═══════════════════════════ DRAG & DROP ════════════════════════════
    function positionGhost(e) {
        const ghost = $('ghost');
        ghost.style.left = `${e.clientX - 27}px`;
        ghost.style.top = `${e.clientY - 27}px`;
    }

    function startDrag(e, side, slot, item) {
        e.preventDefault();
        beginDrag(e, side, slot, item, item.amount, false);
    }

    function beginDrag(e, side, slot, item, amount, locked) {
        dragging = { side, slot, item, amount, locked };
        const ghost = $('ghost');
        ghost.style.background = colorFor(item.name);
        ghost.innerHTML = HD_ICONS.get(item.name);
        ghost.classList.remove('hidden');
        positionGhost(e);
        document.addEventListener('mousemove', onDragMove);
        document.addEventListener('mouseup', onDragEnd);
    }

    function onDragMove(e) {
        positionGhost(e);
        document.querySelectorAll('.slot.drag-over').forEach((el) => el.classList.remove('drag-over'));
        const el = document.elementFromPoint(e.clientX, e.clientY);
        const slotEl = el && el.closest('.slot');
        if (slotEl) slotEl.classList.add('drag-over');
    }

    function onDragEnd(e) {
        document.removeEventListener('mousemove', onDragMove);
        document.removeEventListener('mouseup', onDragEnd);
        $('ghost').classList.add('hidden');
        document.querySelectorAll('.slot.drag-over').forEach((el) => el.classList.remove('drag-over'));

        const d = dragging;
        dragging = null;
        if (!d) return;

        const targetEl = document.elementFromPoint(e.clientX, e.clientY);
        const slotEl = targetEl && targetEl.closest('.slot');

        const finish = (amount) => {
            if (slotEl) {
                const toSide = slotEl.dataset.side;
                const toSlot = Number(slotEl.dataset.slot);
                if (toSide === d.side && toSlot === d.slot) return;
                post('moveItem', { fromSide: d.side, fromSlot: d.slot, toSide, toSlot, amount });
            } else if (d.side === 'left') {
                post('dropItem', { side: d.side, slot: d.slot, amount });
            }
        };

        if (!d.locked && e.shiftKey && d.item.amount > 1) {
            openSplitPrompt(d.item, (amount) => finish(amount));
        } else {
            finish(d.amount);
        }
    }

    // ═══════════════════════════ SPLIT PROMPT ═══════════════════════════
    function openSplitPrompt(item, onConfirm) {
        const modal = $('splitPrompt');
        modal.classList.remove('hidden');
        const range = $('splitRange');
        range.max = item.amount;
        range.value = Math.max(1, Math.ceil(item.amount / 2));
        $('splitValue').textContent = range.value;
        $('splitLabel').textContent = `Split ${item.label}`;
        range.oninput = () => { $('splitValue').textContent = range.value; };
        $('splitCancel').onclick = () => { modal.classList.add('hidden'); };
        $('splitConfirm').onclick = (ev) => {
            modal.classList.add('hidden');
            onConfirm(Number(range.value), ev);
        };
    }

    // ═══════════════════════════ CONTEXT MENU ═══════════════════════════
    function openContextMenu(e, side, slot, item) {
        ctxTarget = { side, slot, item };
        const menu = $('contextMenu');
        menu.classList.remove('hidden');
        menu.style.left = `${e.clientX}px`;
        menu.style.top = `${e.clientY}px`;

        const useBtn = menu.querySelector('[data-act="use"]');
        useBtn.style.display = (item.useable && side === 'left') ? 'block' : 'none';
        const splitBtn = menu.querySelector('[data-act="split"]');
        splitBtn.style.display = item.amount > 1 ? 'block' : 'none';
        const dropBtn = menu.querySelector('[data-act="drop"]');
        dropBtn.style.display = side === 'left' ? 'block' : 'none';
    }

    document.addEventListener('click', () => $('contextMenu').classList.add('hidden'));

    $('contextMenu').addEventListener('click', (e) => {
        const btn = e.target.closest('button[data-act]');
        if (!btn || !ctxTarget) return;
        const { side, slot, item } = ctxTarget;

        if (btn.dataset.act === 'use') {
            post('useItem', { side, slot });
        } else if (btn.dataset.act === 'drop') {
            if (side === 'left') post('dropItem', { side, slot });
        } else if (btn.dataset.act === 'split') {
            openSplitPrompt(item, (amount, ev) => beginDrag(ev, side, slot, item, amount, true));
        }
    });

    // ═══════════════════════════ NUI MESSAGE ROUTER ═════════════════════
    window.addEventListener('message', (event) => {
        const d = event.data;
        switch (d.action) {
            case 'show':
                $('inventory').classList.remove('hidden');
                break;
            case 'hide':
                $('inventory').classList.add('hidden');
                $('contextMenu').classList.add('hidden');
                $('splitPrompt').classList.add('hidden');
                break;
            case 'panel':
                panels[d.side] = d.payload;
                if (d.side === 'left') renderHotbar();
                renderPanel(d.side);
                break;
        }
    });

    document.addEventListener('keyup', (e) => {
        if (e.key !== 'Escape') return;
        if ($('inventory').classList.contains('hidden')) return;
        $('inventory').classList.add('hidden');
        post('close');
    });
})();
