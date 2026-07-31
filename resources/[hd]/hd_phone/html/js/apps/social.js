// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | WIRE / PICTA / LOOPZ (social feeds)
//  Wire specifically also gates on its own account (username/password/
//  profile picture) — see wireAccount below. Picta/Loopz open straight
//  into the feed under the character's real name, same as before.
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    const feeds = { wire: [], picta: [], loopz: [] };
    let activeApp = null;
    let activeWin = null;
    let wireAccount = null; // { username, pfp_url } | null, resolved from the server, not assumed

    HD.on('feed', (app, posts) => { feeds[app] = posts || []; if (activeApp === app) renderFeed(activeWin, app); });
    HD.on('postCreated', (app) => { if (activeApp === app) HD.post('getFeed', { app }); });
    HD.on('likeUpdated', (postId, count, likedByMe) => {
        if (!activeApp) return;
        const post = feeds[activeApp].find((p) => p.id === postId);
        if (post) { post.likeCount = count; post.likedByMe = likedByMe ? 1 : 0; renderFeed(activeWin, activeApp); }
    });
    HD.on('wireAccount', (account) => {
        wireAccount = account || null;
        if (activeApp !== 'wire' || !activeWin) return;
        if (wireAccount) { renderFeed(activeWin, 'wire'); HD.post('getFeed', { app: 'wire' }); }
        else renderWireSignup(activeWin);
    });

    function timeAgo(dateStr) {
        const diff = (Date.now() - new Date(dateStr.replace(' ', 'T'))) / 1000;
        if (diff < 60) return 'now';
        if (diff < 3600) return Math.floor(diff / 60) + 'm';
        if (diff < 86400) return Math.floor(diff / 3600) + 'h';
        return Math.floor(diff / 86400) + 'd';
    }

    function avatarHtml(name, pfpUrl) {
        if (pfpUrl) return `<img src="${pfpUrl}" style="width:32px;height:32px;border-radius:50%;object-fit:cover;" onerror="this.outerHTML='${(name || '?').charAt(0)}'"/>`;
        return `<div class="list-avatar" style="width:32px;height:32px;font-size:13px;">${(name || '?').charAt(0)}</div>`;
    }

    function renderFeed(win, app) {
        activeApp = app;
        const posts = feeds[app] || [];
        win.innerHTML = `
            ${HD.backBar(app.charAt(0).toUpperCase() + app.slice(1))}
            <div class="app-body">
                ${app === 'wire' && wireAccount ? `
                    <div style="display:flex;align-items:center;gap:8px;margin-bottom:14px;">
                        ${avatarHtml(wireAccount.username, wireAccount.pfp_url)}
                        <div style="font-size:13px;color:var(--text-dim);">Signed in as <b style="color:var(--text);">${escapeHtml(wireAccount.username)}</b></div>
                    </div>
                ` : ''}
                ${posts.length ? posts.map((p) => `
                    <div class="card" style="margin-bottom:12px;padding:12px;">
                        <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
                            ${avatarHtml(p.author_name, p.author_pfp)}
                            <div style="font-size:13.5px;font-weight:600;">${escapeHtml(p.author_name)}</div>
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
    function escapeHtml(s) { const d = document.createElement('div'); d.textContent = s == null ? '' : s; return d.innerHTML; }

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

    // ═══════════════════════════ WIRE ACCOUNT GATE ═══════════════════════
    function renderWireSignup(win) {
        win.innerHTML = `
            ${HD.backBar('Wire')}
            <div class="app-body" style="display:flex;flex-direction:column;align-items:center;padding-top:10px;">
                <div style="width:64px;height:64px;border-radius:50%;background:var(--surface-2);display:flex;align-items:center;justify-content:center;margin-bottom:6px;">${wireLogoSvg()}</div>
                <h1 style="font-size:19px;margin-bottom:2px;">Create your Wire account</h1>
                <p class="muted" style="font-size:12.5px;color:var(--text-dim);text-align:center;margin-bottom:16px;">Separate from your HD ID — a username and password just for Wire.</p>
                <div class="field-group" style="width:100%;">
                    <input class="field" id="wire-username" placeholder="Username" style="background:var(--surface-2);border-radius:14px;"/>
                    <input class="field" id="wire-password" type="password" placeholder="Password" style="background:var(--surface-2);border-radius:14px;margin-top:10px;"/>
                    <input class="field" id="wire-password2" type="password" placeholder="Confirm password" style="background:var(--surface-2);border-radius:14px;margin-top:10px;"/>
                    <input class="field" id="wire-pfp" placeholder="Profile picture URL (optional)" style="background:var(--surface-2);border-radius:14px;margin-top:10px;"/>
                </div>
                <div id="wire-pfp-preview" style="margin-top:12px;"></div>
                <button class="btn-primary" style="margin-top:18px;width:100%;" id="wire-create">Create Account</button>
            </div>`;
        HD.bindBack(win);

        const pfpInput = win.querySelector('#wire-pfp');
        const preview = win.querySelector('#wire-pfp-preview');
        pfpInput.oninput = () => {
            const url = pfpInput.value.trim();
            preview.innerHTML = url ? `<img src="${url}" style="width:56px;height:56px;border-radius:50%;object-fit:cover;" onerror="this.remove()"/>` : '';
        };

        win.querySelector('#wire-create').onclick = () => {
            const username = win.querySelector('#wire-username').value.trim();
            const password = win.querySelector('#wire-password').value;
            const password2 = win.querySelector('#wire-password2').value;
            const pfpUrl = win.querySelector('#wire-pfp').value.trim();
            if (username.length < 3) { HD.toast('Username must be at least 3 characters.'); return; }
            if (password.length < 4) { HD.toast('Password must be at least 4 characters.'); return; }
            if (password !== password2) { HD.toast("Passwords don't match."); return; }
            HD.post('createWireAccount', { username, password, pfpUrl });
        };
    }
    function wireLogoSvg() {
        return `<svg width="30" height="30" viewBox="0 0 32 32"><path d="M27 9.5c-.9.4-1.8.7-2.8.8a4.8 4.8 0 0 0 2.1-2.6c-.9.6-2 1-3.1 1.3a4.9 4.9 0 0 0-8.3 4.4A13.8 13.8 0 0 1 5 8.2a4.8 4.8 0 0 0 1.5 6.5c-.8 0-1.5-.2-2.2-.6v.1c0 2.4 1.7 4.4 3.9 4.8-.7.2-1.4.2-2.1.1a4.9 4.9 0 0 0 4.6 3.4A9.8 9.8 0 0 1 3 24.7a13.8 13.8 0 0 0 7.5 2.2c9 0 13.9-7.5 13.9-13.9v-.6c1-.7 1.8-1.6 2.6-2.9Z" fill="#38bdf8"/></svg>`;
    }

    function makeApp(appId) {
        return {
            open(win) { activeWin = win; renderFeed(win, appId); HD.post('getFeed', { app: appId }); },
        };
    }

    window.HDApps.wire = {
        open(win) {
            activeApp = 'wire';
            activeWin = win;
            win.innerHTML = `${HD.backBar('Wire')}<div class="app-body"></div>`;
            HD.bindBack(win);
            HD.post('getWireAccount', {});
        },
    };
    window.HDApps.picta = makeApp('picta');
    window.HDApps.loopz = makeApp('loopz');
})();
