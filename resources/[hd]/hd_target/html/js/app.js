(function () {
    'use strict';

    const $ = (id) => document.getElementById(id);
    const reticle = $('reticle');
    const optionList = $('optionList');

    function escapeHtml(str) {
        return String(str ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    }

    // `icon` is whatever short glyph/emoji the REGISTERING resource
    // passed (hd_target has no opinionated icon set of its own — it's
    // a generic layer other resources plug options into) — rendered as
    // plain text, omitted entirely if not given.
    function renderOptions(list, selected) {
        optionList.innerHTML = (list || []).map((opt, i) => `
            <div class="option-row${i + 1 === selected ? ' selected' : ''}">
                ${opt.icon ? `<span class="option-icon">${escapeHtml(opt.icon)}</span>` : ''}
                <span>${escapeHtml(opt.label)}</span>
            </div>
        `).join('');
        optionList.classList.toggle('hidden', !list || list.length === 0);
    }

    window.addEventListener('message', (event) => {
        const d = event.data;
        switch (d.action) {
            case 'show':
                reticle.classList.remove('hidden');
                break;
            case 'hide':
                reticle.classList.add('hidden');
                optionList.classList.add('hidden');
                optionList.innerHTML = '';
                break;
            case 'options':
                renderOptions(d.list, d.selected);
                break;
            case 'select': {
                const rows = optionList.querySelectorAll('.option-row');
                rows.forEach((row, i) => row.classList.toggle('selected', i + 1 === d.selected));
                break;
            }
        }
    });
})();
