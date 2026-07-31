// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | MAIL
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let mail = [];
    let activeWin = null;

    HD.on('mail', (rows) => { mail = rows || []; if (activeWin) renderList(activeWin); });

    function renderList(win) {
        win.innerHTML = `
            ${HD.backBar('Mail')}
            <div class="app-body">
                ${mail.length ? mail.map((m) => `
                    <div class="list-row" data-mail="${m.id}" style="${m.is_read ? '' : 'font-weight:600;'}">
                        <div class="list-avatar" style="background:linear-gradient(160deg,#60a5fa,#2563eb);">${m.sender_label.charAt(0)}</div>
                        <div class="list-main"><div class="title">${m.sender_label}</div><div class="subtitle">${m.subject}</div></div>
                        ${!m.is_read ? `<div style="width:8px;height:8px;border-radius:50%;background:var(--accent);"></div>` : ''}
                    </div>
                `).join('') : `<div class="empty-state">No mail yet.</div>`}
            </div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-mail]').forEach((row) => {
            row.onclick = () => {
                const m = mail.find((x) => String(x.id) === row.dataset.mail);
                if (m) renderDetail(win, m);
            };
        });
    }

    function renderDetail(win, m) {
        if (!m.is_read) HD.post('readMail', { id: m.id });
        m.is_read = 1;
        win.innerHTML = `
            ${HD.backBar(m.sender_label)}
            <div class="app-body">
                <div style="font-size:17px;font-weight:700;margin-bottom:4px;">${m.subject}</div>
                <div style="font-size:12px;color:var(--text-dim);margin-bottom:16px;">${m.created}</div>
                <div style="font-size:14.5px;line-height:1.5;white-space:pre-wrap;">${m.body}</div>
                <button class="btn-ghost" style="color:var(--danger);margin-top:24px;" id="mail-delete">Delete</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderList(win);
        win.querySelector('#mail-delete').onclick = () => { HD.post('deleteMail', { id: m.id }); mail = mail.filter((x) => x.id !== m.id); renderList(win); };
    }

    window.HDApps.mail = { open(win) { activeWin = win; renderList(win); HD.post('getMail', {}); } };
})();
