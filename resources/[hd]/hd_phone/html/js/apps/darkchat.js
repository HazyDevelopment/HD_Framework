// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | DARK CHAT
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let myAlias = '';
    let threads = [];
    let activeWin = null;
    let openThreadAlias = null;

    HD.on('myAlias', (alias) => { myAlias = alias; if (activeWin && !openThreadAlias) renderThreads(activeWin); });
    HD.on('darkThreads', (rows) => { threads = rows || []; if (activeWin && !openThreadAlias) renderThreads(activeWin); });
    HD.on('darkConversation', (withAlias, rows) => { if (activeWin && openThreadAlias === withAlias) renderConversation(activeWin, withAlias, rows || []); });
    HD.on('newDarkMessage', () => HD.post('getDarkThreads', {}));

    function renderThreads(win) {
        openThreadAlias = null;
        win.innerHTML = `
            ${HD.backBar('Dark Chat')}
            <div style="padding:10px 16px;font-size:12.5px;color:var(--text-dim);text-align:center;">You are <b style="color:var(--text);">${myAlias}</b></div>
            <div class="app-body">
                ${threads.length ? threads.map((t) => `
                    <div class="list-row" data-thread="${t.alias}">
                        <div class="list-avatar" style="background:linear-gradient(160deg,#4b5563,#111827);">?</div>
                        <div class="list-main"><div class="title">${t.alias}</div><div class="subtitle">${t.fromMe ? 'You: ' : ''}${t.lastMessage}</div></div>
                    </div>
                `).join('') : `<div class="empty-state">No conversations yet.</div>`}
            </div>
            <div class="fab" id="dc-new">+</div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-thread]').forEach((row) => { row.onclick = () => openThread(row.dataset.thread); });
        win.querySelector('#dc-new').onclick = () => renderCompose(win);
    }

    function renderCompose(win) {
        win.innerHTML = `
            ${HD.backBar('New Chat')}
            <div class="app-body">
                <input class="field" id="dc-to" placeholder="Their alias (e.g. Ghost1234)" style="background:var(--surface-2);" />
                <button class="btn-primary" style="margin-top:16px;" id="dc-next">Next</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderThreads(win);
        win.querySelector('#dc-next').onclick = () => {
            const to = win.querySelector('#dc-to').value.trim();
            if (to) openThread(to);
        };
    }

    function openThread(alias) {
        openThreadAlias = alias;
        HD.post('getDarkConversation', { withAlias: alias });
        if (activeWin) renderConversation(activeWin, alias, []);
    }

    function renderConversation(win, alias, rows) {
        win.innerHTML = `
            ${HD.backBar(alias)}
            <div class="app-body" id="dc-list"></div>
            <div class="composer">
                <input class="field" id="dc-input" placeholder="Message" />
                <div class="send-btn" id="dc-send">${sendSvg()}</div>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderThreads(win);
        win.querySelector('#dc-list').innerHTML = rows.map((m) => `<div class="bubble-row ${m.sender === myAlias ? 'me' : ''}"><div class="bubble">${escapeHtml(m.message)}</div></div>`).join('');
        const send = () => {
            const input = win.querySelector('#dc-input');
            const text = input.value.trim();
            if (!text) return;
            HD.post('sendDarkMessage', { to: alias, message: text });
            input.value = '';
            rows.push({ sender: myAlias, message: text });
            renderConversation(win, alias, rows);
        };
        win.querySelector('#dc-send').onclick = send;
        win.querySelector('#dc-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') send(); });
    }

    function escapeHtml(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }
    function sendSvg() { return `<svg width="16" height="16" viewBox="0 0 24 24" fill="#fff"><path d="M3 11l18-8-8 18-2.5-7.5L3 11Z"/></svg>`; }

    window.HDApps.darkchat = {
        open(win) { activeWin = win; renderThreads(win); HD.post('getMyAlias', {}); HD.post('getDarkThreads', {}); },
    };
})();
