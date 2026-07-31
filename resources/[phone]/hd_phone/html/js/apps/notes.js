// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | NOTES
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let notes = [];
    let activeWin = null;

    HD.on('notes', (rows) => { notes = rows || []; if (activeWin) renderList(activeWin); });

    function renderList(win) {
        win.innerHTML = `
            ${HD.backBar('Notes')}
            <div class="app-body">
                ${notes.length ? notes.map((n) => `
                    <div class="list-row" data-note="${n.id}">
                        <div class="list-main"><div class="title">${(n.content.split('\n')[0] || 'New Note').slice(0, 40)}</div><div class="subtitle">${n.updated}</div></div>
                    </div>
                `).join('') : `<div class="empty-state">No notes yet.</div>`}
            </div>
            <div class="fab" id="note-new">+</div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-note]').forEach((row) => {
            row.onclick = () => {
                const n = notes.find((x) => String(x.id) === row.dataset.note);
                if (n) renderEditor(win, n);
            };
        });
        win.querySelector('#note-new').onclick = () => renderEditor(win, null);
    }

    function renderEditor(win, note) {
        win.innerHTML = `
            ${HD.backBar('Note')}
            <div class="app-body">
                <textarea class="field" id="note-text" placeholder="Start typing…" style="min-height:400px;background:transparent;font-size:15px;line-height:1.5;">${note ? note.content : ''}</textarea>
            </div>
            ${note ? '<div style="position:absolute;bottom:20px;right:20px;"><button class="btn-ghost" style="color:var(--danger);" id="note-delete">Delete</button></div>' : ''}`;
        win.querySelector('#app-back').onclick = () => {
            const content = win.querySelector('#note-text').value.trim();
            if (content) HD.post('saveNote', { id: note ? note.id : null, content });
            renderList(win);
        };
        const del = win.querySelector('#note-delete');
        if (del) del.onclick = () => { HD.post('deleteNote', { id: note.id }); renderList(win); };
    }

    window.HDApps.notes = { open(win) { activeWin = win; renderList(win); HD.post('getNotes', {}); } };
})();
