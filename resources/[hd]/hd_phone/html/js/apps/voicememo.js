// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | VOICE MEMO
//  Real microphone recordings via the browser's own MediaRecorder API.
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let memos = [];
    let activeWin = null;
    let recorder = null;
    let chunks = [];
    let recordStart = 0;
    let recordTimer = null;

    HD.on('voiceMemos', (rows) => { memos = rows || []; if (activeWin) renderList(activeWin); });
    HD.on('voiceMemoAudio', (id, dataUrl) => {
        const audio = new Audio(dataUrl);
        audio.play();
    });

    function renderList(win) {
        win.innerHTML = `
            ${HD.backBar('Voice Memo')}
            <div class="app-body">
                ${memos.length ? memos.map((m) => `
                    <div class="list-row" data-play="${m.id}">
                        <div class="list-avatar" style="background:linear-gradient(160deg,#f43f5e,#7f1d1d);">${playGlyph()}</div>
                        <div class="list-main"><div class="title">Memo — ${m.duration}s</div><div class="subtitle">${m.created}</div></div>
                        <div class="list-meta" data-delete="${m.id}" style="color:var(--danger);">Delete</div>
                    </div>
                `).join('') : `<div class="empty-state">No voice memos yet.</div>`}
            </div>
            <div class="fab" id="vm-record" style="background:${recorder ? 'var(--danger)' : ''};">${recorder ? '■' : '●'}</div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-play]').forEach((row) => {
            row.querySelector('.list-main').onclick = () => HD.post('getVoiceMemoAudio', { id: +row.dataset.play });
        });
        win.querySelectorAll('[data-delete]').forEach((el) => {
            el.onclick = (e) => { e.stopPropagation(); HD.post('deleteVoiceMemo', { id: +el.dataset.delete }); memos = memos.filter((m) => m.id !== +el.dataset.delete); renderList(win); };
        });
        win.querySelector('#vm-record').onclick = () => toggleRecord(win);
    }
    function playGlyph() { return `<svg width="16" height="16" viewBox="0 0 24 24" fill="#fff"><path d="M8 5v14l11-7Z"/></svg>`; }

    async function toggleRecord(win) {
        if (recorder) {
            recorder.stop();
            return;
        }
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            chunks = [];
            recorder = new MediaRecorder(stream);
            recorder.ondataavailable = (e) => chunks.push(e.data);
            recorder.onstop = () => {
                stream.getTracks().forEach((t) => t.stop());
                const duration = Math.min(30, Math.round((Date.now() - recordStart) / 1000));
                const blob = new Blob(chunks, { type: 'audio/webm' });
                const reader = new FileReader();
                reader.onload = () => { HD.post('saveVoiceMemo', { audioData: reader.result, duration }); HD.toast('Voice memo saved.'); };
                reader.readAsDataURL(blob);
                recorder = null;
                clearTimeout(recordTimer);
                renderList(win);
            };
            recorder.start();
            recordStart = Date.now();
            renderList(win);
            recordTimer = setTimeout(() => { if (recorder) recorder.stop(); }, 30000);
        } catch (e) {
            HD.toast('Microphone permission denied.');
        }
    }

    window.HDApps.voicememo = { open(win) { activeWin = win; renderList(win); HD.post('getVoiceMemos', {}); } };
})();
