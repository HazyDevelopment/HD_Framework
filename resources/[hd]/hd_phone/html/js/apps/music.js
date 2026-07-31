// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | MUSIC
//  Real playback via the YouTube IFrame Player API (audio-focused —
//  the player itself is visually hidden, only controls are shown).
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let playlist = [];
    let activeWin = null;
    let ytPlayer = null;
    let ytReady = false;
    let currentIndex = -1;

    HD.on('playlist', (rows) => { playlist = rows || []; if (activeWin) render(activeWin); });

    function extractVideoId(url) {
        const m = url.match(/(?:youtu\.be\/|v=|embed\/)([A-Za-z0-9_-]{11})/);
        return m ? m[1] : null;
    }

    function ensurePlayer() {
        if (ytPlayer || document.getElementById('yt-player-frame')) return;
        const holder = document.createElement('div');
        holder.id = 'yt-player-frame';
        holder.style.cssText = 'position:absolute;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none;';
        document.getElementById('device').appendChild(holder);

        if (window.YT && window.YT.Player) {
            createPlayer(holder);
        } else {
            const tag = document.createElement('script');
            tag.src = 'https://www.youtube.com/iframe_api';
            document.body.appendChild(tag);
            window.onYouTubeIframeAPIReady = () => createPlayer(holder);
        }
    }
    function createPlayer(holder) {
        const div = document.createElement('div');
        holder.appendChild(div);
        ytPlayer = new window.YT.Player(div, {
            height: '1', width: '1',
            events: {
                onReady: () => { ytReady = true; },
                onStateChange: (e) => { if (e.data === window.YT.PlayerState.ENDED) playNext(); },
            },
        });
    }

    function playTrack(i) {
        if (!playlist[i]) return;
        currentIndex = i;
        ensurePlayer();
        const tryPlay = () => {
            if (ytReady && ytPlayer) ytPlayer.loadVideoById(playlist[i].video_id);
            else setTimeout(tryPlay, 300);
        };
        tryPlay();
        if (activeWin) render(activeWin);
    }
    function playNext() { if (currentIndex + 1 < playlist.length) playTrack(currentIndex + 1); }
    function playPrev() { if (currentIndex - 1 >= 0) playTrack(currentIndex - 1); }
    function togglePause() {
        if (!ytPlayer) return;
        const state = ytPlayer.getPlayerState();
        if (state === window.YT.PlayerState.PLAYING) ytPlayer.pauseVideo(); else ytPlayer.playVideo();
        if (activeWin) render(activeWin);
    }

    function render(win) {
        const current = playlist[currentIndex];
        win.innerHTML = `
            ${HD.backBar('Music')}
            <div class="app-body">
                ${current ? `
                    <div class="card" style="padding:18px;text-align:center;margin-bottom:16px;">
                        <div style="width:80px;height:80px;border-radius:14px;background:linear-gradient(160deg,#fb7185,#be123c);margin:0 auto 10px;display:flex;align-items:center;justify-content:center;">${noteSvg()}</div>
                        <div style="font-weight:700;font-size:15px;">${current.title}</div>
                        <div style="display:flex;justify-content:center;gap:26px;margin-top:14px;">
                            <button id="mus-prev">${prevSvg()}</button>
                            <button id="mus-toggle">${playSvg()}</button>
                            <button id="mus-next">${nextSvg()}</button>
                        </div>
                    </div>` : ''}
                <div class="field-group" style="flex-direction:row;margin-bottom:14px;">
                    <input class="field" id="mus-url" placeholder="Paste a YouTube link" style="background:var(--surface-2);flex:1;" />
                    <button class="btn-primary" style="width:auto;padding:12px 16px;" id="mus-add">Add</button>
                </div>
                ${playlist.map((t, i) => `
                    <div class="list-row" data-track="${i}">
                        <div class="list-avatar" style="background:${i === currentIndex ? 'linear-gradient(160deg,#fb7185,#be123c)' : 'var(--border)'};">${i + 1}</div>
                        <div class="list-main"><div class="title">${t.title}</div></div>
                        <div class="list-meta" data-remove="${t.id}" style="color:var(--danger);">✕</div>
                    </div>
                `).join('')}
            </div>`;
        HD.bindBack(win);
        const addBtn = win.querySelector('#mus-add');
        if (addBtn) addBtn.onclick = () => {
            const url = win.querySelector('#mus-url').value.trim();
            const id = extractVideoId(url);
            if (!id) { HD.toast('Enter a valid YouTube link.'); return; }
            HD.post('addTrack', { videoId: id, title: 'YouTube Track' });
        };
        win.querySelectorAll('[data-track]').forEach((row) => { row.querySelector('.list-main').onclick = () => playTrack(+row.dataset.track); });
        win.querySelectorAll('[data-remove]').forEach((el) => { el.onclick = (e) => { e.stopPropagation(); HD.post('removeTrack', { id: +el.dataset.remove }); }; });
        const prev = win.querySelector('#mus-prev'); if (prev) prev.onclick = playPrev;
        const next = win.querySelector('#mus-next'); if (next) next.onclick = playNext;
        const toggle = win.querySelector('#mus-toggle'); if (toggle) toggle.onclick = togglePause;
    }
    function noteSvg() { return `<svg width="34" height="34" viewBox="0 0 24 24" fill="#fff"><circle cx="7.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/><path d="M10 18V5.5L19 3v11" stroke="#fff" stroke-width="1.8" fill="none"/></svg>`; }
    function prevSvg() { return `<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6 10-6v12z"/></svg>`; }
    function playSvg() { return `<svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7Z"/></svg>`; }
    function nextSvg() { return `<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M16 6h2v12h-2zM4.5 6l10 6-10 6Z"/></svg>`; }

    window.HDApps.music = { open(win) { activeWin = win; render(win); HD.post('getPlaylist', {}); } };
})();
