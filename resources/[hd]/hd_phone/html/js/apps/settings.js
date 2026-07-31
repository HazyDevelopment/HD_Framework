// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | SETTINGS
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};

    function render(win) {
        const s = HD.state.settings;
        win.innerHTML = `
            ${HD.backBar('Settings')}
            <div class="app-body">
                <div class="card" style="padding:14px;display:flex;align-items:center;gap:12px;">
                    <div class="list-avatar" style="width:48px;height:48px;font-size:18px;">${(HD.state.name || '?').charAt(0)}</div>
                    <div>
                        <div style="font-weight:700;font-size:15.5px;">${HD.state.name || 'HD Phone User'}</div>
                        <div style="font-size:12.5px;color:var(--text-dim);">${HD.state.number || 'No number'}</div>
                        <div style="font-size:12.5px;color:var(--text-dim);">${s.email || 'No HD ID linked'}</div>
                    </div>
                </div>

                <div class="section-title">Appearance</div>
                <div class="toggle-row">
                    <div class="label">Dark Mode</div>
                    <div class="switch ${s.darkMode ? 'on' : ''}" data-toggle="dark"><div class="knob"></div></div>
                </div>
                <div class="toggle-row" style="margin-top:8px;">
                    <div><div class="label">Dynamic</div><div class="desc">Follows in-game time of day</div></div>
                    <div class="switch ${s.dynamicMode ? 'on' : ''}" data-toggle="dynamic"><div class="knob"></div></div>
                </div>

                <div class="section-title">Wallpaper</div>
                <div style="display:flex;gap:10px;overflow-x:auto;padding-bottom:4px;">
                    ${HD.state.wallpapers.map((w) => `
                        <div data-wallpaper="${w.id}" style="flex-shrink:0;width:60px;height:100px;border-radius:12px;cursor:pointer;border:2px solid ${s.wallpaper === w.id ? 'var(--accent)' : 'transparent'};background:${wallpaperPreview(w.id)};background-size:cover;"></div>
                    `).join('')}
                </div>

                <div class="section-title">Privacy</div>
                <div class="toggle-row">
                    <div><div class="label">Hide Number</div><div class="desc">Show "Unknown" on outgoing calls</div></div>
                    <div class="switch ${s.noCallerId ? 'on' : ''}" data-toggle="noCallerId"><div class="knob"></div></div>
                </div>
                <div class="toggle-row" style="margin-top:8px;">
                    <div><div class="label">Receive Drop</div><div class="desc">Allow nearby AirDrop offers</div></div>
                    <div class="switch ${s.receiveDrop ? 'on' : ''}" data-toggle="receiveDrop"><div class="knob"></div></div>
                </div>

                <div class="section-title">Security</div>
                <div class="option-list">
                    <button class="option-row" id="settings-passcode">${s.hasPasscode ? 'Change Passcode' : 'Set Passcode'} <span style="color:var(--text-dim);">›</span></button>
                    ${s.hasPasscode ? '<button class="option-row" id="settings-remove-passcode" style="color:var(--danger);">Remove Passcode</button>' : ''}
                </div>
            </div>`;
        HD.bindBack(win);
        bind(win);
    }

    function wallpaperPreview(id) {
        const map = {
            aurora: 'radial-gradient(circle at 30% 20%, #6d5bd0, #1e293b 60%)',
            sunset: 'linear-gradient(160deg,#f97316,#db2777 55%,#4c1d95)',
            midnight: 'linear-gradient(160deg,#0f172a,#1e293b 60%,#000)',
            mono: 'linear-gradient(160deg,#4b5563,#111827)',
        };
        return map[id] || map.aurora;
    }

    function bind(win) {
        win.querySelectorAll('[data-toggle]').forEach((el) => {
            el.onclick = () => {
                const key = el.dataset.toggle;
                const s = HD.state.settings;
                if (key === 'dark') { s.darkMode = !s.darkMode; HD.post('setAppearance', { darkMode: s.darkMode, dynamicMode: s.dynamicMode }); }
                if (key === 'dynamic') { s.dynamicMode = !s.dynamicMode; HD.post('setAppearance', { darkMode: s.darkMode, dynamicMode: s.dynamicMode }); }
                if (key === 'noCallerId') { s.noCallerId = !s.noCallerId; HD.post('setNoCallerId', { enabled: s.noCallerId }); }
                if (key === 'receiveDrop') { s.receiveDrop = !s.receiveDrop; HD.post('setReceiveDrop', { enabled: s.receiveDrop }); }
                HD.applyTheme();
                render(win);
            };
        });
        win.querySelectorAll('[data-wallpaper]').forEach((el) => {
            el.onclick = () => {
                HD.state.settings.wallpaper = el.dataset.wallpaper;
                HD.post('setWallpaper', { wallpaperId: el.dataset.wallpaper, customUrl: '' });
                HD.applyTheme();
                render(win);
            };
        });
        const passcodeBtn = win.querySelector('#settings-passcode');
        if (passcodeBtn) passcodeBtn.onclick = () => renderPasscodeCapture(win);
        const removeBtn = win.querySelector('#settings-remove-passcode');
        if (removeBtn) removeBtn.onclick = () => {
            HD.post('setPasscode', { passcode: null });
            HD.state.settings.hasPasscode = false;
            render(win);
        };
    }

    function renderPasscodeCapture(win) {
        let entry = '';
        function paint() {
            win.innerHTML = `
                ${HD.backBar('New Passcode')}
                <div class="app-body" style="display:flex;flex-direction:column;align-items:center;gap:20px;padding-top:40px;">
                    <div class="passcode-dots">${[0,1,2,3].map((i) => `<div class="dot ${i < entry.length ? 'filled' : ''}"></div>`).join('')}</div>
                    <div class="keypad">
                        ${[1,2,3,4,5,6,7,8,9].map((n) => `<button data-key="${n}">${n}</button>`).join('')}
                        <div class="keypad-empty"></div>
                        <button data-key="0">0</button>
                        <button data-key="back">⌫</button>
                    </div>
                </div>`;
            HD.bindBack(win);
            win.querySelectorAll('[data-key]').forEach((btn) => {
                btn.onclick = () => {
                    const key = btn.dataset.key;
                    if (key === 'back') entry = entry.slice(0, -1);
                    else if (entry.length < 4) entry += key;
                    if (entry.length === 4) {
                        HD.post('setPasscode', { passcode: entry });
                        HD.state.settings.hasPasscode = true;
                        HD.toast('Passcode updated.');
                        render(win);
                    } else {
                        paint();
                    }
                };
            });
        }
        paint();
    }

    window.HDApps.settings = {
        open(win) { render(win); },
    };
})();
