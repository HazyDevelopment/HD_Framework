// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | CORE OS
//  Boot → onboarding → lock screen → home screen. Everything an app
//  needs (post(), icon(), openApp(), toast(), state) is exposed on
//  `window.HD` so html/js/apps/*.js can stay small and focused.
// ═══════════════════════════════════════════════════════════════════

(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_phone';
    const $app = document.getElementById('app');
    const $screens = document.getElementById('screens');
    const $root = document.documentElement;

    function post(name, data) {
        return fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({}));
    }

    function toast(msg) {
        const el = document.getElementById('toast');
        el.textContent = msg;
        el.classList.remove('hidden');
        clearTimeout(toast._t);
        toast._t = setTimeout(() => el.classList.add('hidden'), 2200);
    }

    // ═══════════════════════════ ICON LIBRARY ════════════════════════
    // Every icon is a gradient-filled rounded-square tile + a simple
    // geometric glyph — same visual family as real iOS app icons
    // (flat glyph, soft highlight, drop shadow from .app-icon in CSS),
    // not a hand-drawn sticker.
    const GRADIENTS = {
        phone: ['#34d399', '#059669'], messages: ['#34d399', '#0ea5a3'], contacts: ['#94a3b8', '#475569'],
        settings: ['#9ca3af', '#4b5563'], camera: ['#374151', '#111827'], photos: ['#f472b6', '#a855f7', '#3b82f6'],
        facetime: ['#34d399', '#059669'], wire: ['#38bdf8', '#0ea5e9'], picta: ['#f472b6', '#a855f7', '#f59e0b'],
        loopz: ['#111827', '#ef4444'], matchup: ['#fb7185', '#e11d48'], darkchat: ['#4b5563', '#111827'],
        bank: ['#22c55e', '#15803d'], crypto: ['#f59e0b', '#b45309'], marketplace: ['#fb923c', '#ea580c'],
        mail: ['#60a5fa', '#2563eb'], notes: ['#fde68a', '#f3e8b0'], clock: ['#1f2937', '#111827'],
        maps: ['#4ade80', '#16a34a'], music: ['#fb7185', '#be123c'], voicememo: ['#f43f5e', '#7f1d1d'],
        garages: ['#818cf8', '#4338ca'], appstore: ['#38bdf8', '#1d4ed8'],
    };
    const GLYPHS = {
        phone: '<path d="M8 4c-1 0-2 .9-2 2 0 8 6 14 14 14 1.1 0 2-.9 2-2v-2.6c0-.5-.3-.9-.8-1L17 13.4c-.4-.1-.9 0-1.1.4l-1 1.4c-2-1-3.6-2.6-4.6-4.6l1.4-1c.4-.3.5-.7.4-1.1L10.6 4.8c-.1-.5-.5-.8-1-.8H8Z" fill="#fff"/>',
        messages: '<path d="M6 6h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H12l-5 4v-4H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z" fill="#fff"/>',
        contacts: '<circle cx="16" cy="12" r="4.2" fill="#fff"/><path d="M8 25c0-4.4 3.6-7 8-7s8 2.6 8 7Z" fill="#fff"/>',
        settings: '<path d="M16 11a5 5 0 1 0 0 10 5 5 0 0 0 0-10Zm10.4 3.4-1.8-.3a8.8 8.8 0 0 0-.9-2.1l1.1-1.5a1 1 0 0 0-.1-1.3l-1.7-1.7a1 1 0 0 0-1.3-.1l-1.5 1.1a8.8 8.8 0 0 0-2.1-.9l-.3-1.8a1 1 0 0 0-1-.8h-2.4a1 1 0 0 0-1 .8l-.3 1.8a8.8 8.8 0 0 0-2.1.9L8.8 7.4a1 1 0 0 0-1.3.1L5.8 9.2a1 1 0 0 0-.1 1.3l1.1 1.5a8.8 8.8 0 0 0-.9 2.1l-1.8.3a1 1 0 0 0-.8 1v2.4a1 1 0 0 0 .8 1l1.8.3a8.8 8.8 0 0 0 .9 2.1l-1.1 1.5a1 1 0 0 0 .1 1.3l1.7 1.7a1 1 0 0 0 1.3.1l1.5-1.1a8.8 8.8 0 0 0 2.1.9l.3 1.8a1 1 0 0 0 1 .8h2.4a1 1 0 0 0 1-.8l.3-1.8a8.8 8.8 0 0 0 2.1-.9l1.5 1.1a1 1 0 0 0 1.3-.1l1.7-1.7a1 1 0 0 0 .1-1.3l-1.1-1.5a8.8 8.8 0 0 0 .9-2.1l1.8-.3a1 1 0 0 0 .8-1v-2.4a1 1 0 0 0-.8-1Z" fill="#fff" opacity="0"/><circle cx="16" cy="16" r="5.2" fill="#fff"/>',
        camera: '<rect x="5" y="10" width="22" height="15" rx="3" fill="#fff"/><circle cx="16" cy="17.5" r="5" fill="#374151"/><rect x="12" y="6" width="8" height="4" rx="1.5" fill="#fff"/>',
        photos: '<circle cx="13" cy="13" r="6" fill="#fff"/><circle cx="20" cy="20" r="7" fill="#fff" opacity="0.85"/>',
        facetime: '<rect x="5" y="9" width="16" height="14" rx="3" fill="#fff"/><path d="M23 14.5 27.5 11v10L23 17.5Z" fill="#fff"/>',
        wire: '<path d="M27 9.5c-.9.4-1.8.7-2.8.8a4.8 4.8 0 0 0 2.1-2.6c-.9.6-2 1-3.1 1.3a4.9 4.9 0 0 0-8.3 4.4A13.8 13.8 0 0 1 5 8.2a4.8 4.8 0 0 0 1.5 6.5c-.8 0-1.5-.2-2.2-.6v.1c0 2.4 1.7 4.4 3.9 4.8-.7.2-1.4.2-2.1.1a4.9 4.9 0 0 0 4.6 3.4A9.8 9.8 0 0 1 3 24.7a13.8 13.8 0 0 0 7.5 2.2c9 0 13.9-7.5 13.9-13.9v-.6c1-.7 1.8-1.6 2.6-2.9Z" fill="#fff"/>',
        picta: '<rect x="6" y="6" width="20" height="20" rx="6" fill="none" stroke="#fff" stroke-width="2.2"/><circle cx="16" cy="16" r="5" fill="none" stroke="#fff" stroke-width="2.2"/><circle cx="22.3" cy="9.7" r="1.4" fill="#fff"/>',
        loopz: '<path d="M18 5v14.5a4.5 4.5 0 1 1-3.5-4.4V11a7.5 7.5 0 1 0 6.5 7.4V13a8 8 0 0 0 5 1.7v-3.2A5 5 0 0 1 21 8h-3Z" fill="#fff"/>',
        matchup: '<path d="M16 25s-9-5.6-9-12.2A5.3 5.3 0 0 1 16 9.4a5.3 5.3 0 0 1 9 3.4C25 19.4 16 25 16 25Z" fill="#fff"/>',
        darkchat: '<circle cx="16" cy="16" r="10" fill="#fff"/><circle cx="12.5" cy="14.5" r="1.6" fill="#1f2937"/><circle cx="19.5" cy="14.5" r="1.6" fill="#1f2937"/><path d="M11 20c1.5 1.3 3.2 2 5 2s3.5-.7 5-2" stroke="#1f2937" stroke-width="1.6" fill="none" stroke-linecap="round"/>',
        bank: '<path d="M16 5 27 11v2H5v-2Z" fill="#fff"/><rect x="6" y="14" width="4" height="10" fill="#fff"/><rect x="14" y="14" width="4" height="10" fill="#fff"/><rect x="22" y="14" width="4" height="10" fill="#fff"/><rect x="5" y="25" width="22" height="2.5" fill="#fff"/>',
        crypto: '<circle cx="16" cy="16" r="10.5" fill="none" stroke="#fff" stroke-width="2.4"/><path d="M14 10.5h3.2a2.9 2.9 0 0 1 0 5.8H14m0 0h3.6a3 3 0 0 1 0 6H14m0-11.8v11.8m0-11.8v-2m0 13.8v2" stroke="#fff" stroke-width="1.8" fill="none" stroke-linecap="round"/>',
        marketplace: '<path d="M6 11h20l-1.5 12a2 2 0 0 1-2 1.8H9.5a2 2 0 0 1-2-1.8Z" fill="#fff"/><path d="M11 11a5 5 0 0 1 10 0" stroke="#fff" stroke-width="2" fill="none"/>',
        mail: '<rect x="5" y="8" width="22" height="16" rx="3" fill="#fff"/><path d="M6 9.5 16 18l10-8.5" stroke="#2563eb" stroke-width="1.8" fill="none" stroke-linecap="round"/>',
        notes: '<rect x="6" y="5" width="20" height="22" rx="3" fill="#fff"/><rect x="9.5" y="11" width="13" height="2" fill="#e8d98a"/><rect x="9.5" y="15.5" width="13" height="2" fill="#e8d98a"/><rect x="9.5" y="20" width="8" height="2" fill="#e8d98a"/>',
        clock: '<circle cx="16" cy="16" r="10.5" fill="none" stroke="#fff" stroke-width="2.2"/><path d="M16 9.5V16l5 3" stroke="#fff" stroke-width="2" fill="none" stroke-linecap="round"/>',
        maps: '<path d="M16 6c-4 0-7 3-7 7 0 5.3 7 13 7 13s7-7.7 7-13c0-4-3-7-7-7Z" fill="#fff"/><circle cx="16" cy="13" r="2.6" fill="#16a34a"/>',
        music: '<circle cx="10.5" cy="22" r="3.2" fill="#fff"/><circle cx="21.5" cy="19" r="3.2" fill="#fff"/><path d="M13.7 22V9.5L24.7 7v11.5" stroke="#fff" stroke-width="2" fill="none" stroke-linecap="round"/>',
        voicememo: '<rect x="12.5" y="6" width="7" height="14" rx="3.5" fill="#fff"/><path d="M9 16a7 7 0 0 0 14 0" stroke="#fff" stroke-width="2" fill="none" stroke-linecap="round"/><line x1="16" y1="23" x2="16" y2="27" stroke="#fff" stroke-width="2" stroke-linecap="round"/>',
        garages: '<path d="M6 15 16 7l10 8v11H6Z" fill="#fff"/><rect x="10" y="17" width="12" height="7" fill="#818cf8"/>',
        appstore: '<path d="M16 6l3 6.5 7 1-5.2 4.9 1.3 7L16 22l-6.1 3.4 1.3-7L6 13.5l7-1Z" fill="#fff"/>',
    };
    function iconSvg(id, size) {
        size = size || 34;
        const g = GRADIENTS[id] || ['#9ca3af', '#4b5563'];
        const gid = 'g_' + id;
        const stops = g.map((c, i) => `<stop offset="${(i / (g.length - 1)) * 100}%" stop-color="${c}"/>`).join('');
        return `<svg viewBox="0 0 32 32" width="${size}" height="${size}"><defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1">${stops}</linearGradient></defs>` +
            `<rect width="32" height="32" rx="8" fill="url(#${gid})"/>${GLYPHS[id] || ''}</svg>`;
    }
    function appTile(app, opts) {
        opts = opts || {};
        const badge = opts.badge ? `<span class="badge">${opts.badge > 99 ? '99+' : opts.badge}</span>` : '';
        return `
            <div class="app-icon-wrap" data-open-app="${app.id}">
                <div class="app-icon">${iconSvg(app.icon)}${badge}</div>
                ${opts.noLabel ? '' : `<label>${app.label}</label>`}
            </div>`;
    }

    // ═══════════════════════════ STATE ═══════════════════════════════
    const HD = {
        state: {
            booted: false, onboarded: false, locked: true, ccOpen: false,
            number: null, name: null, apps: [], installedApps: [],
            settings: { darkMode: false, dynamicMode: false, wallpaper: 'aurora', noCallerId: false, receiveDrop: true, hasPasscode: false },
            wallpapers: [],
            homeOrder: { grid: [], dock: [] },
            unread: { messages: 0 },
            activeCall: null,
            brightness: 100, volume: 70, airplaneMode: false, dnd: false, flashlight: false,
        },
        post, toast, iconSvg, appTile,
    };
    window.HD = HD;

    // ═══════════════════════════ EVENT BUS ═══════════════════════════
    // App files subscribe with HD.on('contacts', fn) instead of adding
    // their own window.message listener, so several apps can each react
    // to their own slice of server pushes without stepping on others.
    const listeners = {};
    HD.on = function (action, fn) {
        (listeners[action] = listeners[action] || []).push(fn);
    };
    function emit(action, args) {
        (listeners[action] || []).forEach((fn) => fn.apply(null, args || []));
    }

    function wallpaperCss(id) {
        const map = {
            aurora: 'radial-gradient(circle at 30% 20%, #6d5bd0, #1e293b 60%), linear-gradient(160deg,#3b82f6,#1e1b4b)',
            sunset: 'linear-gradient(160deg,#f97316,#db2777 55%,#4c1d95)',
            midnight: 'linear-gradient(160deg,#0f172a,#1e293b 60%,#000)',
            mono: 'linear-gradient(160deg,#4b5563,#111827)',
        };
        return map[id] || map.aurora;
    }
    function applyTheme() {
        const s = HD.state.settings;
        let dark = s.darkMode;
        if (s.dynamicMode) {
            const h = new Date().getHours();
            dark = h < 7 || h >= 19;
        }
        $root.setAttribute('data-theme', dark ? 'dark' : 'light');
        document.getElementById('statusbar').classList.toggle('on-dark', HD.state.currentScreen === 'lock' || HD.state.currentScreen === 'home');
        const bg = HD.state.settings.customWallpaperUrl ? `url(${HD.state.settings.customWallpaperUrl})` : wallpaperCss(s.wallpaper);
        document.querySelectorAll('.wallpaper-target').forEach((el) => { el.style.background = bg; el.style.backgroundSize = 'cover'; el.style.backgroundPosition = 'center'; });
    }
    HD.applyTheme = applyTheme;

    // ═══════════════════════════ SCREEN ROUTER ════════════════════════
    function showScreen(name, html) {
        HD.state.currentScreen = name;
        $screens.innerHTML = `<div class="screen" id="screen-${name}">${html}</div>`;
        applyTheme();
    }
    HD.showScreen = showScreen;

    function renderBoot() {
        showScreen('boot', `<div class="boot-logo"></div>`);
        setTimeout(() => {
            if (HD.state.settings.onboarded) renderLock();
            else renderOnboarding();
        }, 900);
    }

    // ═══════════════════════════ ONBOARDING ═══════════════════════════
    const Onboard = {
        step: 0,
        data: { darkMode: false, dynamicMode: false, passcode: '', email: '', password: '', password2: '', securityAnswer: '' },
    };

    function renderOnboarding() {
        const steps = [welcomeStep, appearanceStep, passcodeStep, accountStep];
        showScreen('onboard', steps[Onboard.step]());
        bindOnboardEvents();
    }

    function welcomeStep() {
        return `
            <div class="onboard">
                <div class="spacer"></div>
                <div class="onboard-logo-mark"></div>
                <h1>Welcome to HD Phone</h1>
                <p class="sub">Let's get your phone set up. This only takes a minute.</p>
                <div class="spacer"></div>
                <button class="btn-primary" id="ob-next">Get Started</button>
            </div>`;
    }

    function appearanceStep() {
        return `
            <div class="onboard">
                <h1 style="font-size:22px;margin-top:20px;">Appearance</h1>
                <p class="sub">Choose light or dark, or let it follow the in-game time of day.</p>
                <div class="appearance-cards">
                    <div class="appearance-card">
                        <div class="appearance-preview ${!Onboard.data.darkMode ? 'selected' : ''}" data-mode="light"><span class="preview-clock">9:41</span></div>
                        <label>Light</label>
                    </div>
                    <div class="appearance-card">
                        <div class="appearance-preview dark ${Onboard.data.darkMode ? 'selected' : ''}" data-mode="dark"><span class="preview-clock">9:41</span></div>
                        <label>Dark</label>
                    </div>
                </div>
                <div class="toggle-row" style="margin-top:6px;">
                    <div><div class="label">Dynamic</div><div class="desc">Switch automatically with time of day</div></div>
                    <div class="switch ${Onboard.data.dynamicMode ? 'on' : ''}" id="ob-dynamic"><div class="knob"></div></div>
                </div>
                <div class="spacer"></div>
                <button class="btn-primary" id="ob-next">Continue</button>
            </div>`;
    }

    function passcodeStep() {
        const filled = Onboard.data.passcode.length;
        const dots = [0, 1, 2, 3].map((i) => `<div class="dot ${i < filled ? 'filled' : ''}"></div>`).join('');
        return `
            <div class="onboard">
                <div class="spacer"></div>
                <h1 style="font-size:22px;">Set a Passcode</h1>
                <p class="sub">Secure your phone with a 4-digit passcode.</p>
                <div class="passcode-dots">${dots}</div>
                <div class="keypad" id="ob-keypad">
                    ${[1,2,3,4,5,6,7,8,9].map((n) => `<button data-key="${n}">${n}</button>`).join('')}
                    <div class="keypad-empty"></div>
                    <button data-key="0">0</button>
                    <button data-key="back">⌫</button>
                </div>
                <div class="spacer"></div>
                <button class="btn-ghost" id="ob-skip">Skip</button>
            </div>`;
    }

    function accountStep() {
        return `
            <div class="onboard">
                <div class="onboard-logo-mark" style="margin-top:20px;"></div>
                <h1 style="font-size:21px;">Create Your HD ID</h1>
                <p class="sub">Use your HD ID to personalise your phone.</p>
                <div class="field-group">
                    <div style="display:flex;align-items:center;background:var(--surface-2);border-radius:14px;padding:2px 16px;">
                        <input class="field" style="padding-left:0;" id="ob-email" placeholder="Your username" />
                        <span style="color:var(--text-dim);font-size:14px;white-space:nowrap;">@hazydev.com</span>
                    </div>
                    <input class="field" id="ob-password" type="password" placeholder="Your password" />
                    <input class="field" id="ob-password2" type="password" placeholder="Your password again" />
                    <input class="field" id="ob-security" placeholder="The name of your first pet?" />
                </div>
                <div class="spacer"></div>
                <button class="btn-primary" id="ob-create">Create HD ID</button>
                <button class="btn-ghost" id="ob-skip2">Skip for now</button>
            </div>`;
    }

    function bindOnboardEvents() {
        const next = document.getElementById('ob-next');
        if (next) next.onclick = () => { Onboard.step++; renderOnboarding(); };

        document.querySelectorAll('[data-mode]').forEach((el) => {
            el.onclick = () => { Onboard.data.darkMode = el.dataset.mode === 'dark'; renderOnboarding(); };
        });
        const dyn = document.getElementById('ob-dynamic');
        if (dyn) dyn.onclick = () => { Onboard.data.dynamicMode = !Onboard.data.dynamicMode; renderOnboarding(); };

        const keypad = document.getElementById('ob-keypad');
        if (keypad) {
            keypad.querySelectorAll('button').forEach((btn) => {
                btn.onclick = () => {
                    const key = btn.dataset.key;
                    if (key === 'back') Onboard.data.passcode = Onboard.data.passcode.slice(0, -1);
                    else if (Onboard.data.passcode.length < 4) Onboard.data.passcode += key;
                    if (Onboard.data.passcode.length === 4) {
                        post('setPasscode', { passcode: Onboard.data.passcode });
                        Onboard.step++;
                        setTimeout(renderOnboarding, 150);
                    } else {
                        renderOnboarding();
                    }
                };
            });
        }
        const skip = document.getElementById('ob-skip');
        if (skip) skip.onclick = () => { Onboard.step++; renderOnboarding(); };

        const create = document.getElementById('ob-create');
        if (create) create.onclick = () => {
            const email = document.getElementById('ob-email').value.trim();
            const password = document.getElementById('ob-password').value;
            const password2 = document.getElementById('ob-password2').value;
            const securityAnswer = document.getElementById('ob-security').value.trim();
            if (!email || !password) { toast('Enter an email and password.'); return; }
            if (password !== password2) { toast("Passwords don't match."); return; }
            post('createAccount', { email, password, securityAnswer });
            // Same non-blocking pattern as Skip below: the HD ID is a
            // cosmetic flourish (see server/onboarding.lua's header
            // comment), so advance immediately rather than waiting on a
            // server round trip that could stall the whole wizard if it
            // never arrives.
            HD.state.settings.email = email + '@hazydev.com';
            finishOnboarding();
        };
        const skip2 = document.getElementById('ob-skip2');
        if (skip2) skip2.onclick = () => { post('skipOnboarding', {}); finishOnboarding(); };
    }

    function finishOnboarding() {
        HD.state.settings.onboarded = true;
        HD.state.settings.darkMode = Onboard.data.darkMode;
        HD.state.settings.dynamicMode = Onboard.data.dynamicMode;
        post('setAppearance', { darkMode: Onboard.data.darkMode, dynamicMode: Onboard.data.dynamicMode });
        renderLock();
    }

    // ═══════════════════════════ LOCK SCREEN ══════════════════════════
    let lockEntry = '';
    function renderLock() {
        lockEntry = '';
        const now = new Date();
        const time = now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit', hour12: false });
        const date = now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
        showScreen('lock', `
            <div class="wallpaper-target" style="position:absolute;inset:0;"></div>
            <div style="position:relative;z-index:2;display:flex;flex-direction:column;align-items:center;width:100%;flex:1;">
                <div class="lock-date">${date}</div>
                <div class="lock-time">${time}</div>
                <div id="lock-passcode-area"></div>
                <div style="flex:1;"></div>
                <div class="swipe-hint" id="lock-hint">Tap to open</div>
                <div class="lock-bottom">
                    <div class="lock-quick-btn" id="lock-flashlight">${flashlightSvg()}</div>
                    <div class="lock-quick-btn" id="lock-camera">${cameraQuickSvg()}</div>
                </div>
            </div>
        `);
        document.getElementById('screen-lock').addEventListener('click', onLockTap);
    }
    function flashlightSvg() { return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><path d="M9 2h6l-1 6h2l-7 12 1-8H8Z"/></svg>`; }
    function cameraQuickSvg() { return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><rect x="3" y="7" width="18" height="13" rx="2"/><circle cx="12" cy="13.5" r="3.5"/><path d="M9 7l1-2h4l1 2"/></svg>`; }

    function onLockTap(e) {
        if (e.target.closest('.lock-bottom')) return;
        if (HD.state.settings.hasPasscode) {
            showPasscodeEntry();
        } else {
            unlockToHome();
        }
    }

    function showPasscodeEntry() {
        document.getElementById('lock-hint').classList.add('hidden');
        const area = document.getElementById('lock-passcode-area');
        area.innerHTML = `
            <div class="passcode-entry">
                <div style="font-size:13px;opacity:0.85;">Enter your passcode</div>
                <div class="passcode-dots" id="lock-dots"></div>
                <div class="keypad" id="lock-keypad">
                    ${[1,2,3,4,5,6,7,8,9].map((n) => `<button data-key="${n}">${n}</button>`).join('')}
                    <div class="keypad-empty"></div>
                    <button data-key="0">0</button>
                    <button data-key="back">⌫</button>
                </div>
            </div>`;
        renderLockDots();
        document.getElementById('lock-keypad').querySelectorAll('button').forEach((btn) => {
            btn.onclick = (ev) => {
                ev.stopPropagation();
                const key = btn.dataset.key;
                if (key === 'back') lockEntry = lockEntry.slice(0, -1);
                else if (lockEntry.length < 4) lockEntry += key;
                renderLockDots();
                if (lockEntry.length === 4) {
                    post('verifyPasscode', { passcode: lockEntry }).then(() => {});
                }
            };
        });
    }
    function renderLockDots() {
        const dots = document.getElementById('lock-dots');
        if (!dots) return;
        dots.innerHTML = [0, 1, 2, 3].map((i) => `<div class="dot ${i < lockEntry.length ? 'filled' : ''}"></div>`).join('');
    }
    HD.onPasscodeResult = function (ok) {
        if (ok) { unlockToHome(); }
        else { lockEntry = ''; renderLockDots(); toast('Incorrect passcode'); }
    };

    function unlockToHome() {
        HD.state.locked = false;
        renderHome();
    }

    // ═══════════════════════════ HOME SCREEN ══════════════════════════
    // homeOrder remembers icon position per container ('grid'/'dock') as
    // an array of app ids, saved server-side (hd_phone_settings.home_order)
    // so a reorder survives closing/reopening the phone.
    function orderApps(list, order) {
        if (!order || !order.length) return list;
        const byId = new Map(list.map((a) => [a.id, a]));
        const ordered = [];
        order.forEach((id) => { if (byId.has(id)) { ordered.push(byId.get(id)); byId.delete(id); } });
        byId.forEach((a) => ordered.push(a)); // newly-installed apps not yet in the saved order go at the end
        return ordered;
    }

    function renderHome() {
        const installedSet = new Set(HD.state.installedApps);
        const homeApps = HD.state.apps.filter((a) => a.core || installedSet.has(a.id));
        const dockApps = orderApps(homeApps.filter((a) => a.dock), HD.state.homeOrder.dock);
        const gridApps = orderApps(homeApps.filter((a) => !a.dock), HD.state.homeOrder.grid);

        showScreen('home', `
            <div class="wallpaper-target" style="position:absolute;inset:0;z-index:-1;"></div>
            <div id="reorder-done" class="hidden">Done</div>
            <div class="app-grid" id="home-grid">
                ${gridApps.map((a) => appTile(a, { badge: a.id === 'messages' ? HD.state.unread.messages : 0 })).join('')}
            </div>
            <div id="dock">
                ${dockApps.map((a) => appTile(a, { noLabel: true, badge: a.id === 'messages' ? HD.state.unread.messages : 0 })).join('')}
            </div>
        `);
        bindHomeInteractions(document.getElementById('screen-home'));
    }
    HD.renderHome = renderHome;

    // ═══════════════════════════ ICON REORDER (long-press to jiggle) ═════
    let reorderMode = false;
    let dragInfo = null; // { wrap, containerEl }
    let suppressNextClick = false;

    function containerKey(containerEl) { return containerEl.id === 'dock' ? 'dock' : 'grid'; }

    function enterReorderMode(homeEl) {
        if (reorderMode) return;
        reorderMode = true;
        homeEl.querySelectorAll('.app-icon-wrap[data-open-app]').forEach((el) => el.classList.add('jiggle'));
        const done = homeEl.querySelector('#reorder-done');
        if (done) done.classList.remove('hidden');
    }

    function exitReorderMode(homeEl) {
        if (!reorderMode) return;
        reorderMode = false;
        homeEl.querySelectorAll('.app-icon-wrap').forEach((el) => el.classList.remove('jiggle', 'dragging'));
        const done = homeEl.querySelector('#reorder-done');
        if (done) done.classList.add('hidden');
        post('setHomeOrder', { grid: HD.state.homeOrder.grid, dock: HD.state.homeOrder.dock });
    }

    function startDrag(wrap, containerEl, pointerId) {
        dragInfo = { wrap, containerEl };
        wrap.classList.add('dragging');
        try { wrap.setPointerCapture(pointerId); } catch (e) {}
    }

    function updateDragPosition(clientX, clientY) {
        if (!dragInfo) return;
        const { wrap, containerEl } = dragInfo;
        const el = document.elementFromPoint(clientX, clientY);
        const overWrap = el && el.closest('.app-icon-wrap[data-open-app]');
        if (!overWrap || overWrap === wrap || overWrap.parentElement !== containerEl) return;
        const followingInDom = wrap.compareDocumentPosition(overWrap) & Node.DOCUMENT_POSITION_FOLLOWING;
        containerEl.insertBefore(wrap, followingInDom ? overWrap.nextSibling : overWrap);
    }

    function endDrag() {
        if (!dragInfo) return;
        const { wrap, containerEl } = dragInfo;
        wrap.classList.remove('dragging');
        const ids = Array.from(containerEl.querySelectorAll('[data-open-app]')).map((el) => el.dataset.openApp);
        HD.state.homeOrder[containerKey(containerEl)] = ids;
        dragInfo = null;
        suppressNextClick = true;
    }

    function bindHomeInteractions(homeEl) {
        let pressTimer = null;
        let pressStart = null;

        function cancelPress() { clearTimeout(pressTimer); pressTimer = null; }

        homeEl.addEventListener('pointerdown', (e) => {
            const wrap = e.target.closest('.app-icon-wrap[data-open-app]');
            if (!wrap) return;
            pressStart = { x: e.clientX, y: e.clientY };
            pressTimer = setTimeout(() => {
                pressTimer = null;
                enterReorderMode(homeEl);
                startDrag(wrap, wrap.parentElement, e.pointerId);
            }, 480);
        });

        homeEl.addEventListener('pointermove', (e) => {
            if (dragInfo) {
                updateDragPosition(e.clientX, e.clientY);
                return;
            }
            if (pressTimer && pressStart) {
                const dx = e.clientX - pressStart.x, dy = e.clientY - pressStart.y;
                if (Math.hypot(dx, dy) > 12) cancelPress();
            }
        });

        homeEl.addEventListener('pointerup', () => {
            cancelPress();
            if (dragInfo) endDrag();
        });
        homeEl.addEventListener('pointercancel', () => {
            cancelPress();
            if (dragInfo) endDrag();
        });

        homeEl.addEventListener('click', (e) => {
            if (suppressNextClick) { suppressNextClick = false; return; }
            if (reorderMode) { exitReorderMode(homeEl); return; }
            const wrap = e.target.closest('[data-open-app]');
            if (wrap) openApp(wrap.dataset.openApp);
        });

        const done = homeEl.querySelector('#reorder-done');
        if (done) done.onclick = (e) => { e.stopPropagation(); exitReorderMode(homeEl); };
    }

    // ═══════════════════════════ APP WINDOW ═══════════════════════════
    let currentAppWindow = null;
    function openApp(appId) {
        const app = HD.state.apps.find((a) => a.id === appId);
        if (!app) return;
        const handler = window.HDApps && window.HDApps[appId] ? window.HDApps[appId] : window.HDApps.placeholder;
        const win = document.createElement('div');
        win.className = 'app-window';
        win.id = 'app-window-' + appId;
        document.getElementById('screen-' + HD.state.currentScreen).appendChild(win);
        currentAppWindow = win;
        handler.open(win, app);
    }
    HD.openApp = openApp;
    HD.closeApp = function () {
        if (currentAppWindow) { currentAppWindow.remove(); currentAppWindow = null; }
        // Always land back on a freshly-rendered home screen — this is
        // also what makes a just-installed/removed app (App Store) or a
        // just-created HD ID (Settings) actually show up/take effect the
        // moment you back out, instead of only after a manual reopen.
        if (HD.state.currentScreen === 'home') renderHome();
    };
    HD.backBar = function (title, onBack) {
        return `<div class="app-topbar"><div class="back-btn" id="app-back">${chevronSvg()} Back</div><h2>${title}</h2><div style="width:50px;"></div></div>`;
    };
    function chevronSvg() { return `<svg width="10" height="16" viewBox="0 0 10 16" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M8 1 1.5 8 8 15"/></svg>`; }
    HD.bindBack = function (win) {
        const btn = win.querySelector('#app-back');
        if (btn) btn.onclick = () => HD.closeApp();
    };

    // ═══════════════════════════ CONTROL CENTER ═══════════════════════
    function renderControlCenter() {
        const cc = document.getElementById('control-center');
        cc.classList.remove('hidden');
        cc.innerHTML = `
            <div class="cc-panel" id="cc-panel">
                <div class="cc-row">
                    <div class="cc-toggle ${HD.state.airplaneMode ? 'active' : ''}" data-cc="airplane">${airplaneSvg()}<span>Airplane</span></div>
                    <div class="cc-toggle ${HD.state.dnd ? 'active' : ''}" data-cc="dnd">${dndSvg()}<span>Focus</span></div>
                    <div class="cc-toggle ${HD.state.settings.noCallerId ? 'active' : ''}" data-cc="hideid">${hideIdSvg()}<span>Hide Number</span></div>
                    <div class="cc-toggle ${HD.state.settings.receiveDrop ? 'active' : ''}" data-cc="drop">${dropSvg()}<span>Receive Drop</span></div>
                </div>
                <div class="cc-music">
                    <div style="width:34px;height:34px;border-radius:8px;background:var(--border);"></div>
                    <div class="info"><b>Not Playing</b><span>HD Music</span></div>
                    <div class="controls">${prevSvg()}${playSvg()}${nextSvg()}</div>
                </div>
                <div class="cc-slider-row">${brightnessSvg()}<input type="range" class="cc-slider" id="cc-brightness" min="30" max="100" value="${HD.state.brightness}"></div>
                <div class="cc-slider-row">${volumeSvg()}<input type="range" class="cc-slider" id="cc-volume" min="0" max="100" value="${HD.state.volume}"></div>
                <div class="cc-quick-row">
                    <div class="cc-quick-btn" data-open-app="camera">${cameraQuickSvg()}</div>
                    <div class="cc-quick-btn ${HD.state.flashlight ? 'active' : ''}" data-cc="flashlight">${flashlightSvgDark()}</div>
                </div>
            </div>`;
        cc.onclick = (e) => {
            if (e.target === cc) closeControlCenter();
            const toggle = e.target.closest('[data-cc]');
            if (toggle) handleCcToggle(toggle.dataset.cc);
            const appOpen = e.target.closest('[data-open-app]');
            if (appOpen) { closeControlCenter(); openApp(appOpen.dataset.openApp); }
        };
        document.getElementById('cc-brightness').oninput = (e) => {
            HD.state.brightness = +e.target.value;
            document.getElementById('screen').style.filter = `brightness(${0.55 + (HD.state.brightness / 100) * 0.45})`;
        };
        document.getElementById('cc-volume').oninput = (e) => { HD.state.volume = +e.target.value; };
    }
    function handleCcToggle(kind) {
        if (kind === 'airplane') HD.state.airplaneMode = !HD.state.airplaneMode;
        if (kind === 'dnd') HD.state.dnd = !HD.state.dnd;
        if (kind === 'flashlight') HD.state.flashlight = !HD.state.flashlight;
        if (kind === 'hideid') { HD.state.settings.noCallerId = !HD.state.settings.noCallerId; post('setNoCallerId', { enabled: HD.state.settings.noCallerId }); }
        if (kind === 'drop') { HD.state.settings.receiveDrop = !HD.state.settings.receiveDrop; post('setReceiveDrop', { enabled: HD.state.settings.receiveDrop }); }
        renderControlCenter();
    }
    function closeControlCenter() { document.getElementById('control-center').classList.add('hidden'); HD.state.ccOpen = false; }
    function airplaneSvg() { return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M21 16v-2l-8-5V4.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2.5 1.5V22l4-1 4 1v-1.5L13 19v-5.5Z"/></svg>`; }
    function dndSvg() { return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm5 11H7v-2h10Z"/></svg>`; }
    function hideIdSvg() { return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M3 3l18 18M10.6 5.1A10.9 10.9 0 0 1 12 5c5 0 9 3.5 10 7a12 12 0 0 1-2.2 3.9M6.6 6.6C4.5 8 3 10 2 12c1 3.5 5 7 10 7 1.3 0 2.5-.2 3.6-.6M9.9 9.9a3 3 0 0 0 4.2 4.2"/></svg>`; }
    function dropSvg() { return `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2 5 9a7 7 0 1 0 14 0Z"/></svg>`; }
    function prevSvg() { return `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6 10-6v12z"/></svg>`; }
    function playSvg() { return `<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7Z"/></svg>`; }
    function nextSvg() { return `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M16 6h2v12h-2zM4.5 6l10 6-10 6Z"/></svg>`; }
    function brightnessSvg() { return `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M2 12h2M20 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"/></svg>`; }
    function volumeSvg() { return `<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M3 10v4h4l5 5V5L7 10Z"/><path d="M16 8.5a5 5 0 0 1 0 7" stroke="currentColor" stroke-width="2" fill="none"/></svg>`; }
    function flashlightSvgDark() { return `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 2h6l-1 6h2l-7 12 1-8H8Z"/></svg>`; }

    document.getElementById('sb-toggle').addEventListener('click', () => {
        HD.state.ccOpen = !HD.state.ccOpen;
        if (HD.state.ccOpen) renderControlCenter(); else closeControlCenter();
    });

    // ═══════════════════════════ CLOSING THE PHONE ═══════════════════════
    // Tapping the transparent area around the device (i.e. NOT on #device
    // itself) closes the phone, same as tapping outside a real phone
    // overlay. #app covers the full viewport specifically so this has
    // somewhere to catch that click — see the CSS's PHONE FRAME comment.
    $app.addEventListener('click', (e) => {
        if (e.target === $app) post('close');
    });
    // Escape always closes, regardless of which screen/app is open —
    // NUI focus means the game's own keybind for this never reaches the
    // client script while the phone is up, so this has to live here.
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') post('close');
    });

    // ═══════════════════════════ CALL OVERLAY ═════════════════════════
    HD.showIncomingCall = function (call) {
        HD.state.activeCall = call;
        const overlay = document.getElementById('call-overlay');
        overlay.classList.remove('hidden');
        overlay.innerHTML = `
            <div class="call-avatar">${(call.name || '?').charAt(0)}</div>
            <div class="call-name">${call.name || 'Unknown'}</div>
            <div class="call-status">Incoming call…</div>
            <div class="call-actions">
                <div class="call-action"><div class="circle decline" id="call-decline">${hangupSvg()}</div>Decline</div>
                <div class="call-action"><div class="circle answer" id="call-answer">${answerSvg()}</div>Accept</div>
            </div>`;
        document.getElementById('call-decline').onclick = () => { post('declineCall', { callId: call.callId }); hideCallOverlay(); };
        document.getElementById('call-answer').onclick = () => { post('answerCall', { callId: call.callId }); };
    };
    HD.showOutgoingCall = function (name, callId) {
        HD.state.activeCall = { callId, name };
        const overlay = document.getElementById('call-overlay');
        overlay.classList.remove('hidden');
        overlay.innerHTML = `
            <div class="call-avatar">${(name || '?').charAt(0)}</div>
            <div class="call-name">${name || 'Unknown'}</div>
            <div class="call-status" id="call-status-text">Calling…</div>
            <div class="call-actions">
                <div class="call-action"><div class="circle decline" id="call-hangup">${hangupSvg()}</div>End</div>
            </div>`;
        document.getElementById('call-hangup').onclick = () => {
            post('endCall', { callId: HD.state.activeCall && HD.state.activeCall.callId });
            hideCallOverlay();
        };
    };
    HD.callConnected = function () {
        const statusText = document.getElementById('call-status-text');
        if (statusText) statusText.textContent = 'Connected';
        const status = document.querySelector('#call-overlay .call-status');
        if (status) status.textContent = 'Connected';
    };
    HD.hideCallOverlay = hideCallOverlay;
    function hideCallOverlay() {
        HD.state.activeCall = null;
        document.getElementById('call-overlay').classList.add('hidden');
    }
    function hangupSvg() { return `<svg width="26" height="26" viewBox="0 0 24 24" fill="#fff" style="transform:rotate(135deg)"><path d="M12 5c-4.5 0-8.4 1.5-11.3 4a1.5 1.5 0 0 0-.2 2l2 2.5a1.5 1.5 0 0 0 2 .3l2.5-1.7a1.2 1.2 0 0 0 .5-1.3l-.6-2.2A14 14 0 0 1 12 8c1.9 0 3.7.3 5.4.9l-.6 2a1.2 1.2 0 0 0 .5 1.3l2.5 1.8a1.5 1.5 0 0 0 2-.3l2-2.6a1.5 1.5 0 0 0-.2-2C20.4 6.5 16.5 5 12 5Z"/></svg>`; }
    function answerSvg() { return `<svg width="26" height="26" viewBox="0 0 24 24" fill="#fff"><path d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2a1.5 1.5 0 0 1 1.5-.4c1.2.4 2.5.6 3.9.6a1.5 1.5 0 0 1 1.5 1.5v3.6a1.5 1.5 0 0 1-1.5 1.5C10.5 22 2 13.5 2 3.7A1.5 1.5 0 0 1 3.5 2.2h3.6A1.5 1.5 0 0 1 8.6 3.7c0 1.4.2 2.7.6 3.9.1.5 0 1.1-.4 1.5Z"/></svg>`; }

    // ═══════════════════════════ AIRDROP OFFER ════════════════════════
    HD.showAirdropOffer = function (name, number) {
        const overlay = document.getElementById('call-overlay');
        overlay.classList.remove('hidden');
        overlay.style.background = 'linear-gradient(160deg, #0ea5e9, #1d4ed8 70%)';
        overlay.innerHTML = `
            <div class="call-avatar">${dropSvg()}</div>
            <div class="call-name">${name || 'Someone'}</div>
            <div class="call-status">wants to AirDrop their contact card</div>
            <div class="call-actions">
                <div class="call-action"><div class="circle decline" id="drop-decline">${hangupSvg()}</div>Decline</div>
                <div class="call-action"><div class="circle answer" id="drop-accept">${answerSvg()}</div>Accept</div>
            </div>`;
        const close = () => { overlay.classList.add('hidden'); overlay.style.background = ''; };
        document.getElementById('drop-decline').onclick = () => { post('airdropRespond', { accept: false }); close(); };
        document.getElementById('drop-accept').onclick = () => { post('airdropRespond', { accept: true }); close(); };
    };

    // ═══════════════════════════ NUI MESSAGE BUS ══════════════════════
    window.addEventListener('message', (event) => {
        const msg = event.data;
        switch (msg.action) {
            case 'open':
                $app.classList.remove('hidden');
                if (!HD.state.booted) { HD.state.booted = true; renderBoot(); }
                break;
            case 'close':
                $app.classList.add('hidden');
                break;
            case 'sync': {
                const data = msg.args[0];
                HD.state.number = data.number;
                HD.state.name = data.name;
                HD.state.settings = Object.assign(HD.state.settings, data.settings);
                HD.state.installedApps = data.installedApps || [];
                HD.state.apps = data.apps || [];
                HD.state.wallpapers = data.wallpapers || [];
                HD.state.homeOrder = data.homeOrder || { grid: [], dock: [] };
                applyTheme();
                break;
            }
            case 'onboarded':
                finishOnboarding();
                break;
            case 'passcodeResult':
                HD.onPasscodeResult(msg.args[0]);
                break;
            case 'appInstalled':
                if (!HD.state.installedApps.includes(msg.args[0])) HD.state.installedApps.push(msg.args[0]);
                if (window.HDApps && window.HDApps.appstore && window.HDApps.appstore.refresh) window.HDApps.appstore.refresh();
                break;
            case 'appRemoved':
                HD.state.installedApps = HD.state.installedApps.filter((id) => id !== msg.args[0]);
                if (window.HDApps && window.HDApps.appstore && window.HDApps.appstore.refresh) window.HDApps.appstore.refresh();
                // Home re-renders itself from current state the moment
                // HD.closeApp() lands back on it — no need (and it'd be
                // harmful) to force it while still inside the App Store.
                break;
            case 'ring':
                document.body.dataset.ringing = '1';
                break;
            case 'stopRing':
                delete document.body.dataset.ringing;
                break;
            case 'incomingCall':
                HD.showIncomingCall(msg.args[0]);
                break;
            case 'callRinging':
                // phone.js already shows the outgoing-call overlay with the
                // name it dialled the instant it posts startCall — this is
                // just the server confirming the callId, so only fall back
                // to a bare overlay if nothing's showing yet.
                if (!HD.state.activeCall) HD.showOutgoingCall(null, msg.args[0].callId);
                else HD.state.activeCall.callId = msg.args[0].callId;
                break;
            case 'callConnected':
                HD.callConnected();
                break;
            case 'callEnded':
                hideCallOverlay();
                break;
            case 'airdropOffer':
                HD.showAirdropOffer(msg.name, msg.number);
                break;
            default:
                emit(msg.action, msg.args || [msg]);
        }
    });

    document.getElementById('toast').addEventListener('transitionend', () => {});
})();
