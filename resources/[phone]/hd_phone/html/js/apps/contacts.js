// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | CONTACTS
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let cache = [];

    HD.on('contacts', (rows) => { cache = rows || []; if (activeWin) renderList(activeWin); });

    let activeWin = null;

    function renderList(win) {
        win.innerHTML = `
            ${HD.backBar('Contacts')}
            <div class="app-body">
                ${cache.length ? cache.map((c) => `
                    <div class="list-row" data-contact="${c.id}">
                        <div class="list-avatar">${c.name.charAt(0).toUpperCase()}</div>
                        <div class="list-main"><div class="title">${c.name}</div><div class="subtitle">${c.number}</div></div>
                    </div>
                `).join('') : `<div class="empty-state">No contacts yet. Tap + to add one.</div>`}
            </div>
            <div class="fab" id="contacts-add">+</div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-contact]').forEach((row) => {
            row.onclick = () => {
                const c = cache.find((x) => String(x.id) === row.dataset.contact);
                if (c) renderDetail(win, c);
            };
        });
        win.querySelector('#contacts-add').onclick = () => renderEdit(win, null);
    }

    function renderDetail(win, contact) {
        win.innerHTML = `
            ${HD.backBar(contact.name)}
            <div class="app-body" style="text-align:center;">
                <div class="list-avatar" style="width:76px;height:76px;font-size:28px;margin:10px auto 6px;">${contact.name.charAt(0).toUpperCase()}</div>
                <div style="font-size:19px;font-weight:700;">${contact.name}</div>
                <div style="color:var(--text-dim);font-size:14px;margin-bottom:20px;">${contact.number}</div>
                <div style="display:flex;gap:14px;justify-content:center;">
                    <button class="btn-primary" style="width:auto;padding:12px 22px;" id="c-call">Call</button>
                    <button class="btn-primary" style="width:auto;padding:12px 22px;background:linear-gradient(160deg,#34c759,#16a34a);box-shadow:none;" id="c-msg">Message</button>
                </div>
                <div class="option-list" style="margin-top:26px;">
                    <button class="option-row" id="c-edit">Edit</button>
                    <button class="option-row" id="c-delete" style="color:var(--danger);">Delete Contact</button>
                </div>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderList(win);
        win.querySelector('#c-call').onclick = () => { HD.closeApp(); HD.openApp('phone'); setTimeout(() => window.HDApps.phone.dial(contact.number), 30); };
        win.querySelector('#c-msg').onclick = () => { HD.closeApp(); HD.openApp('messages'); setTimeout(() => window.HDApps.messages.openThread(contact.number), 30); };
        win.querySelector('#c-edit').onclick = () => renderEdit(win, contact);
        win.querySelector('#c-delete').onclick = () => { HD.post('deleteContact', { id: contact.id }); renderList(win); };
    }

    function renderEdit(win, contact) {
        win.innerHTML = `
            ${HD.backBar(contact ? 'Edit Contact' : 'New Contact')}
            <div class="app-body">
                <div class="field-group">
                    <input class="field" id="edit-name" placeholder="Name" value="${contact ? contact.name : ''}" />
                    <input class="field" id="edit-number" placeholder="Phone number" value="${contact ? contact.number : ''}" ${contact ? 'disabled' : ''} />
                </div>
                <button class="btn-primary" style="margin-top:20px;" id="edit-save">Save</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => (contact ? renderDetail(win, contact) : renderList(win));
        win.querySelector('#edit-save').onclick = () => {
            const name = win.querySelector('#edit-name').value.trim();
            const number = win.querySelector('#edit-number').value.trim();
            if (!name || !number) { HD.toast('Enter a name and number.'); return; }
            HD.post('saveContact', { name, number });
            renderList(win);
        };
    }

    window.HDApps.contacts = {
        open(win) {
            activeWin = win;
            renderList(win);
            HD.post('getContacts', {});
        },
        getCache() { return cache; },
    };
})();
