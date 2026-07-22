(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_cardealer';

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

    const grid = document.getElementById('grid');
    const catalog = document.getElementById('catalog');

    function render(entries) {
        grid.innerHTML = entries.map((e) => `
            <div class="car-card">
                <div class="car-main">
                    <span class="car-label">${escapeHtml(e.label)}</span>
                    <span class="car-class">${escapeHtml(e.class)}</span>
                </div>
                <div class="car-right">
                    <span class="car-price">£${Number(e.price).toLocaleString()}</span>
                    <button class="buy-btn" data-model="${escapeHtml(e.model)}">Buy</button>
                </div>
            </div>`).join('');
    }

    grid.addEventListener('click', (e) => {
        const btn = e.target.closest('button[data-model]');
        if (!btn) return;
        post('buy', { model: btn.dataset.model });
    });

    document.getElementById('closeBtn').addEventListener('click', () => post('close'));

    window.addEventListener('message', (event) => {
        const d = event.data;
        if (d.action === 'open') {
            render(d.catalog || []);
            catalog.classList.remove('hidden');
        } else if (d.action === 'close') {
            catalog.classList.add('hidden');
        }
    });

    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape' && !catalog.classList.contains('hidden')) {
            catalog.classList.add('hidden');
            post('close');
        }
    });
})();
