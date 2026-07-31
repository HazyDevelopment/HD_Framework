// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | WIRE / PICTA / LOOPZ (social feeds)
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    const feeds = { wire: [], picta: [], loopz: [] };
    let activeApp = null;
    let activeWin = null;

    HD.on('feed', (app, posts) => { feeds[app] = posts || []; if (activeApp === app) renderFeed(activeWin, app); });
    HD.on('postCreated', (app) => { if (activeApp === app) HD.post('getFeed', { app }); });
    HD.on('likeUpdated', (postId, count, likedByMe) => {
        if (!activeApp) return;
        const post = feeds[activeApp].find((p) => p.id === postId);
        if (post) { post.likeCount = count; post.likedByMe = likedByMe ? 1 : 0; renderFeed(activeWin, activeApp); }
    });

    function timeAgo(dateStr) {
        const diff = (Date.now() - new Date(dateStr.replace(' ', 'T'))) / 1000;
        if (diff < 60) return 'now';
        if (diff < 3600) return Math.floor(diff / 60) + 'm';
        if (diff < 86400) return Math.floor(diff / 3600) + 'h';
        return Math.floor(diff / 86400) + 'd';
    }

    function renderFeed(win, app) {
        activeApp = app;
        const posts = feeds[app] || [];
        win.innerHTML = `
            ${HD.backBar(app.charAt(0).toUpperCase() + app.slice(1))}
            <div class="app-body">
                ${posts.length ? posts.map((p) => `
                    <div class="card" style="margin-bottom:12px;padding:12px;">
                        <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
                            <div class="list-avatar" style="width:32px;height:32px;font-size:13px;">${p.author_name.charAt(0)}</div>
                            <div style="font-size:13.5px;font-weight:600;">${p.author_name}</div>
                            <div style="font-size:12px;color:var(--text-dim);margin-left:auto;">${timeAgo(p.created)}</div>
                        </div>
                        ${p.content ? `<div style="font-size:14.5px;margin-bottom:${p.image_url ? '8px' : '4px'};">${escapeHtml(p.content)}</div>` : ''}
                        ${p.image_url ? `<img src="${p.image_url}" style="width:100%;border-radius:10px;max-height:220px;object-fit:cover;" onerror="this.style.display='none'"/>` : ''}
                        <div style="display:flex;align-items:center;gap:6px;margin-top:8px;cursor:pointer;" data-like="${p.id}">
                            ${heartSvg(p.likedByMe)}<span style="font-size:12.5px;color:var(--text-dim);">${p.likeCount || 0}</span>
                        </div>
                    </div>
                `).join('') : `<div class="empty-state">Nothing here yet.</div>`}
            </div>
            <div class="fab" id="social-new">+</div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-like]').forEach((el) => { el.onclick = () => HD.post('toggleLike', { postId: +el.dataset.like }); });
        win.querySelector('#social-new').onclick = () => renderCompose(win, app);
    }

    function heartSvg(liked) {
        return `<svg width="16" height="16" viewBox="0 0 24 24" fill="${liked ? '#ef4444' : 'none'}" stroke="${liked ? '#ef4444' : 'currentColor'}" stroke-width="2"><path d="M12 21s-7-4.5-9.3-9A5.3 5.3 0 0 1 12 6.6 5.3 5.3 0 0 1 21.3 12c-2.3 4.5-9.3 9-9.3 9Z"/></svg>`;
    }
    function escapeHtml(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

    function renderCompose(win, app) {
        win.innerHTML = `
            ${HD.backBar('New Post')}
            <div class="app-body">
                <textarea class="field" id="post-content" placeholder="What's happening?" style="min-height:100px;background:var(--surface-2);border-radius:14px;resize:none;"></textarea>
                <input class="field" id="post-image" placeholder="Image URL (optional)" style="background:var(--surface-2);margin-top:10px;"/>
                <button class="btn-primary" style="margin-top:16px;" id="post-submit">Post</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderFeed(win, app);
        win.querySelector('#post-submit').onclick = () => {
            const content = win.querySelector('#post-content').value.trim();
            const imageUrl = win.querySelector('#post-image').value.trim();
            if (!content && !imageUrl) { HD.toast('Write something or add an image.'); return; }
            HD.post('createPost', { app, content, imageUrl });
            renderFeed(win, app);
        };
    }

    function makeApp(appId) {
        return {
            open(win) { activeWin = win; renderFeed(win, appId); HD.post('getFeed', { app: appId }); },
        };
    }
    window.HDApps.wire = makeApp('wire');
    window.HDApps.picta = makeApp('picta');
    window.HDApps.loopz = makeApp('loopz');
})();
