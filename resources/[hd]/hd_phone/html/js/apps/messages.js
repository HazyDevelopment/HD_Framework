// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | MESSAGES
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let threads = [];
    let activeWin = null;
    let openThreadNumber = null;

    HD.on('threads', (rows) => {
        threads = rows || [];
        HD.state.unread.messages = threads.reduce((sum, t) => sum + (t.unread || 0), 0);
        if (activeWin && !openThreadNumber) renderThreads(activeWin);
    });
    HD.on('conversation', (withNumber, rows) => {
        if (activeWin && openThreadNumber === withNumber) renderConversation(activeWin, withNumber, rows || []);
    });
    HD.on('newMessage', (payload) => {
        HD.post('getThreads', {});
        if (activeWin && openThreadNumber === payload.sender) HD.post('getConversation', { withNumber: payload.sender });
        if (!activeWin) HD.toast(`New message from ${payload.sender}`);
    });

    function contactName(number) {
        const c = window.HDApps.contacts && window.HDApps.contacts.getCache().find((x) => x.number === number);
        return c ? c.name : number;
    }

    function renderThreads(win) {
        openThreadNumber = null;
        win.innerHTML = `
            ${HD.backBar('Messages')}
            <div class="app-body">
                ${threads.length ? threads.map((t) => `
                    <div class="list-row" data-thread="${t.number}">
                        <div class="list-avatar">${contactName(t.number).charAt(0).toUpperCase()}</div>
                        <div class="list-main"><div class="title">${contactName(t.number)}</div><div class="subtitle">${t.fromMe ? 'You: ' : ''}${t.lastMessage}</div></div>
                        ${t.unread ? `<div class="list-meta"><span style="background:var(--accent);color:#fff;border-radius:9px;padding:1px 7px;font-size:11px;">${t.unread}</span></div>` : ''}
                    </div>
                `).join('') : `<div class="empty-state">No messages yet.</div>`}
            </div>
            <div class="fab" id="msg-new">+</div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-thread]').forEach((row) => {
            row.onclick = () => openThread(row.dataset.thread);
        });
        win.querySelector('#msg-new').onclick = () => renderCompose(win);
    }

    function renderCompose(win) {
        win.innerHTML = `
            ${HD.backBar('New Message')}
            <div class="app-body">
                <input class="field" style="background:var(--surface-2);" id="compose-to" placeholder="Phone number" />
                <button class="btn-primary" style="margin-top:16px;" id="compose-next">Next</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderThreads(win);
        win.querySelector('#compose-next').onclick = () => {
            const to = win.querySelector('#compose-to').value.trim();
            if (!to) return;
            openThread(to);
        };
    }

    function openThread(number) {
        openThreadNumber = number;
        HD.post('getConversation', { withNumber: number });
        if (activeWin) renderConversation(activeWin, number, []);
    }

    function renderConversation(win, number, rows) {
        win.innerHTML = `
            ${HD.backBar(contactName(number))}
            <div class="app-body" id="msg-list" style="display:flex;flex-direction:column;">
                ${rows.map((m) => `<div class="bubble-row ${m.sender !== number ? 'me' : ''}"><div class="bubble">${escapeHtml(m.message)}</div></div>`).join('')}
            </div>
            <div class="composer">
                <input class="field" id="msg-input" placeholder="Message" />
                <div class="send-btn" id="msg-send">${sendSvg()}</div>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderThreads(win);
        const list = win.querySelector('#msg-list');
        list.scrollTop = list.scrollHeight;
        const send = () => {
            const input = win.querySelector('#msg-input');
            const text = input.value.trim();
            if (!text) return;
            HD.post('sendMessage', { to: number, message: text });
            input.value = '';
            rows.push({ sender: HD.state.number, message: text });
            renderConversation(win, number, rows);
        };
        win.querySelector('#msg-send').onclick = send;
        win.querySelector('#msg-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') send(); });
    }

    function escapeHtml(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }
    function sendSvg() { return `<svg width="16" height="16" viewBox="0 0 24 24" fill="#fff"><path d="M3 11l18-8-8 18-2.5-7.5L3 11Z"/></svg>`; }

    window.HDApps.messages = {
        open(win) { activeWin = win; renderThreads(win); HD.post('getThreads', {}); },
        openThread,
    };
})();
