(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_radial';
    const $ = (id) => document.getElementById(id);

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

    const ICONS = {
        gps: '<path d="M16 4c-4.4 0-8 3.6-8 8 0 6 8 16 8 16s8-10 8-16c0-4.4-3.6-8-8-8Z"/><circle cx="16" cy="12" r="3" fill="currentColor" stroke="none"/>',
        interactions: '<circle cx="11" cy="10" r="3.2"/><circle cx="21" cy="10" r="3.2"/><path d="M4 26c0-4 3.5-7 7-7s7 3 7 3 3.5-3 7-3 7 3 7 7"/>',
        walkstyle: '<circle cx="16" cy="6" r="2.6" fill="currentColor" stroke="none"/><path d="M16 9v7l-4 10M16 16l4 10M12 13l-4 4M20 13l4 4"/>',
        general: '<circle cx="16" cy="16" r="9"/><path d="M16 9v2M16 21v2M9 16h2M21 16h2M11.5 11.5l1.4 1.4M19.1 19.1l1.4 1.4M11.5 20.5l1.4-1.4M19.1 12.9l1.4-1.4"/>',
        work: '<rect x="6" y="12" width="20" height="13" rx="2"/><path d="M12 12v-2a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
        emotes: '<circle cx="16" cy="16" r="10"/><circle cx="12.5" cy="14" r="1.4" fill="currentColor" stroke="none"/><circle cx="19.5" cy="14" r="1.4" fill="currentColor" stroke="none"/><path d="M11.5 19c1.3 1.2 2.9 1.8 4.5 1.8s3.2-.6 4.5-1.8"/>',
    };
    function iconSvg(id) {
        return `<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${ICONS[id] || '<circle cx="16" cy="16" r="4"/>'}</svg>`;
    }

    const $root = $('root');
    const $ring = $('ring');
    const $hub = $('hub');
    const $hubIcon = $('hubIcon');
    const $hubLabel = $('hubLabel');

    let payload = {};       // full 'open' message — categories + every list
    let atCategory = null;  // null = top-level hub, else the category id currently drilled into

    function positionRing(count, radius) {
        return (i) => {
            const angle = (-90 + i * (360 / count)) * (Math.PI / 180);
            const x = radius * Math.cos(angle);
            const y = radius * Math.sin(angle);
            return `translate(${x}px, ${y}px)`;
        };
    }

    function renderTopLevel() {
        atCategory = null;
        $hubIcon.textContent = '✕';
        $hubLabel.textContent = '';
        const cats = payload.categories || [];
        const place = positionRing(cats.length, 170);
        $ring.innerHTML = cats.map((cat, i) => `
            <div class="radial-btn" style="transform:${place(i)}" data-category="${cat.id}">
                ${iconSvg(cat.icon)}
                <span class="rb-label">${escapeHtml(cat.label)}</span>
            </div>
        `).join('');
        $ring.querySelectorAll('[data-category]').forEach((el) => {
            el.addEventListener('click', () => renderCategory(el.dataset.category));
        });
    }

    function itemsFor(categoryId) {
        const map = {
            emotes: payload.emotes, interactions: payload.interactions, walkstyle: payload.walkstyles,
            general: payload.general, gps: payload.gps, work: payload.work,
        };
        return map[categoryId] || [];
    }

    function renderCategory(categoryId) {
        atCategory = categoryId;
        const cat = (payload.categories || []).find((c) => c.id === categoryId);
        $hubIcon.textContent = '‹';
        $hubLabel.textContent = cat ? cat.label : '';

        const items = itemsFor(categoryId);
        const place = positionRing(Math.max(items.length, 1), 170);
        $ring.innerHTML = items.map((item, i) => `
            <div class="radial-btn" style="transform:${place(i)}" data-index="${i}">
                <span class="rb-label">${escapeHtml(item.label)}</span>
                ${item.sub ? `<span class="rb-sub">${escapeHtml(item.sub)}</span>` : ''}
            </div>
        `).join('');
        $ring.querySelectorAll('[data-index]').forEach((el) => {
            el.addEventListener('click', () => {
                const item = items[Number(el.dataset.index)];
                post('runAction', { category: categoryId, item });
            });
        });
    }

    $hub.addEventListener('click', () => {
        if (atCategory) renderTopLevel();
        else post('close');
    });

    document.addEventListener('keyup', (e) => {
        if (e.key !== 'Escape') return;
        if (atCategory) renderTopLevel();
        else post('close');
    });

    window.addEventListener('message', (event) => {
        const d = event.data;
        if (d.action === 'open') {
            payload = d;
            $root.classList.remove('hidden');
            renderTopLevel();
        } else if (d.action === 'close') {
            $root.classList.add('hidden');
        }
    });
})();
