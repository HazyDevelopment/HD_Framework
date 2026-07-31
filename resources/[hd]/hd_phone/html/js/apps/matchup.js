// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | MATCHUP (dating)
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let queue = [];
    let myProfile = { bio: '', photo_url: '', active: 0 };
    let activeWin = null;

    HD.on('swipeQueue', (rows) => { queue = rows || []; if (activeWin) renderQueue(activeWin); });
    HD.on('myProfile', (p) => { myProfile = p; });
    HD.on('newMatch', (name) => HD.toast(`It's a match with ${name}!`));

    function renderQueue(win) {
        const card = queue[0];
        win.innerHTML = `
            ${HD.backBar('Matchup')}
            <div style="position:absolute;top:54px;right:16px;z-index:2;">
                <button class="btn-ghost" id="mu-profile" style="color:var(--accent);">Profile</button>
            </div>
            <div class="app-body" style="display:flex;align-items:center;justify-content:center;">
                ${card ? `
                    <div class="card" style="width:100%;overflow:hidden;">
                        <div style="width:100%;aspect-ratio:0.85;background:${card.photoUrl ? `url('${card.photoUrl}') center/cover` : 'linear-gradient(160deg,#fb7185,#e11d48)'};display:flex;align-items:flex-end;">
                            <div style="background:linear-gradient(0deg,rgba(0,0,0,0.6),transparent);width:100%;padding:16px;color:#fff;">
                                <div style="font-size:20px;font-weight:700;">${card.name}</div>
                                <div style="font-size:13.5px;opacity:0.9;">${card.bio || ''}</div>
                            </div>
                        </div>
                    </div>
                ` : `<div class="empty-state">No one new nearby right now.</div>`}
            </div>
            ${card ? `
                <div style="display:flex;justify-content:center;gap:40px;padding:18px;">
                    <div class="call-btn end" style="width:56px;height:56px;" id="mu-pass">${xSvg()}</div>
                    <div class="call-btn" style="width:56px;height:56px;background:linear-gradient(160deg,#fb7185,#e11d48);" id="mu-like">${heartSvg()}</div>
                </div>` : ''}`;
        HD.bindBack(win);
        win.querySelector('#mu-profile').onclick = () => renderProfileEdit(win);
        if (card) {
            win.querySelector('#mu-pass').onclick = () => { HD.post('swipe', { targetCitizenId: card.citizenid, liked: false }); queue.shift(); renderQueue(win); };
            win.querySelector('#mu-like').onclick = () => { HD.post('swipe', { targetCitizenId: card.citizenid, liked: true }); queue.shift(); renderQueue(win); };
        }
    }
    function xSvg() { return `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5"><path d="M5 5l14 14M19 5 5 19"/></svg>`; }
    function heartSvg() { return `<svg width="22" height="22" viewBox="0 0 24 24" fill="#fff"><path d="M12 21s-7-4.5-9.3-9A5.3 5.3 0 0 1 12 6.6 5.3 5.3 0 0 1 21.3 12c-2.3 4.5-9.3 9-9.3 9Z"/></svg>`; }

    function renderProfileEdit(win) {
        win.innerHTML = `
            ${HD.backBar('My Profile')}
            <div class="app-body">
                <div class="field-group">
                    <textarea class="field" id="mu-bio" placeholder="Bio" style="background:var(--surface-2);min-height:80px;resize:none;">${myProfile.bio || ''}</textarea>
                    <input class="field" id="mu-photo" placeholder="Photo URL" value="${myProfile.photo_url || ''}" style="background:var(--surface-2);" />
                </div>
                <div class="toggle-row" style="margin-top:14px;">
                    <div><div class="label">Visible</div><div class="desc">Show my profile to others</div></div>
                    <div class="switch ${myProfile.active ? 'on' : ''}" id="mu-active"><div class="knob"></div></div>
                </div>
                <button class="btn-primary" style="margin-top:20px;" id="mu-save">Save</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderQueue(win);
        win.querySelector('#mu-active').onclick = (e) => { myProfile.active = myProfile.active ? 0 : 1; e.target.closest('.switch').classList.toggle('on'); };
        win.querySelector('#mu-save').onclick = () => {
            myProfile.bio = win.querySelector('#mu-bio').value.trim();
            myProfile.photo_url = win.querySelector('#mu-photo').value.trim();
            HD.post('saveProfile', { bio: myProfile.bio, photoUrl: myProfile.photo_url, active: myProfile.active });
            renderQueue(win);
        };
    }

    window.HDApps.matchup = {
        open(win) {
            activeWin = win;
            renderQueue(win);
            HD.post('getMyProfile', {});
            HD.post('getSwipeQueue', {});
        },
    };
})();
