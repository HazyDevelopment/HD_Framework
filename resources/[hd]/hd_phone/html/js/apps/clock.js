// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | CLOCK
//  Fully client-only — stopwatch/timer/alarms persist via localStorage
//  and keep ticking even while the phone is closed, since this NUI
//  page never actually unloads (only its visibility toggles).
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let tab = 'clock';
    let activeWin = null;
    let stopwatchRunning = false, stopwatchStart = 0, stopwatchElapsed = 0;
    let timerSeconds = 0, timerRunning = false;

    function loadAlarms() { try { return JSON.parse(localStorage.getItem('hd_phone_alarms') || '[]'); } catch (e) { return []; } }
    function saveAlarms(a) { localStorage.setItem('hd_phone_alarms', JSON.stringify(a)); }

    setInterval(() => {
        const now = new Date();
        loadAlarms().forEach((a) => {
            if (a.enabled && a.hour === now.getHours() && a.minute === now.getMinutes() && now.getSeconds() === 0) {
                HD.toast(`⏰ Alarm: ${a.label || 'Alarm'}`);
            }
        });
    }, 1000);

    function render(win) {
        win.innerHTML = `
            ${HD.backBar('Clock')}
            <div style="display:flex;padding:0 16px;gap:6px;">
                ${['clock', 'stopwatch', 'timer', 'alarms'].map((t) => `
                    <button data-tab="${t}" style="flex:1;padding:8px;border-radius:10px;background:${tab === t ? 'var(--accent)' : 'var(--surface-2)'};color:${tab === t ? '#fff' : 'var(--text)'};font-size:12.5px;text-transform:capitalize;">${t}</button>
                `).join('')}
            </div>
            <div class="app-body" id="clock-content"></div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-tab]').forEach((b) => { b.onclick = () => { tab = b.dataset.tab; render(win); }; });
        renderTab(win);
    }

    function renderTab(win) {
        const content = win.querySelector('#clock-content');
        if (tab === 'clock') {
            const now = new Date();
            content.innerHTML = `<div style="text-align:center;padding:60px 0;"><div style="font-size:52px;font-weight:700;">${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div><div style="color:var(--text-dim);margin-top:8px;">${now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' })}</div></div>`;
        } else if (tab === 'stopwatch') {
            const elapsed = stopwatchElapsed + (stopwatchRunning ? Date.now() - stopwatchStart : 0);
            content.innerHTML = `
                <div style="text-align:center;padding:50px 0;">
                    <div style="font-size:44px;font-weight:700;font-variant-numeric:tabular-nums;">${fmtStopwatch(elapsed)}</div>
                    <div style="display:flex;justify-content:center;gap:16px;margin-top:24px;">
                        <button class="btn-primary" style="width:auto;padding:12px 24px;" id="sw-toggle">${stopwatchRunning ? 'Stop' : 'Start'}</button>
                        <button class="btn-ghost" id="sw-reset">Reset</button>
                    </div>
                </div>`;
            content.querySelector('#sw-toggle').onclick = () => {
                if (stopwatchRunning) { stopwatchElapsed += Date.now() - stopwatchStart; stopwatchRunning = false; }
                else { stopwatchStart = Date.now(); stopwatchRunning = true; }
                renderTab(win);
            };
            content.querySelector('#sw-reset').onclick = () => { stopwatchElapsed = 0; stopwatchRunning = false; renderTab(win); };
        } else if (tab === 'timer') {
            content.innerHTML = `
                <div style="text-align:center;padding:50px 0;">
                    <div style="font-size:44px;font-weight:700;">${fmtTimer(timerSeconds)}</div>
                    <div style="display:flex;justify-content:center;gap:10px;margin-top:20px;">
                        ${[60, 300, 600].map((s) => `<button class="btn-ghost" data-add="${s}">+${s / 60}m</button>`).join('')}
                    </div>
                    <button class="btn-primary" style="width:auto;padding:12px 24px;margin-top:20px;" id="timer-toggle">${timerRunning ? 'Pause' : 'Start'}</button>
                </div>`;
            content.querySelectorAll('[data-add]').forEach((b) => { b.onclick = () => { timerSeconds += +b.dataset.add; renderTab(win); }; });
            content.querySelector('#timer-toggle').onclick = () => { timerRunning = !timerRunning; renderTab(win); tickTimer(win); };
        } else if (tab === 'alarms') {
            const alarms = loadAlarms();
            content.innerHTML = `
                ${alarms.map((a, i) => `
                    <div class="toggle-row" style="margin-bottom:8px;">
                        <div><div class="label">${String(a.hour).padStart(2, '0')}:${String(a.minute).padStart(2, '0')}</div><div class="desc">${a.label || ''}</div></div>
                        <div class="switch ${a.enabled ? 'on' : ''}" data-alarm-toggle="${i}"><div class="knob"></div></div>
                    </div>
                `).join('')}
                <button class="btn-primary" style="margin-top:10px;" id="alarm-add">Add Alarm</button>`;
            content.querySelectorAll('[data-alarm-toggle]').forEach((el) => {
                el.onclick = () => { const a = loadAlarms(); const i = +el.dataset.alarmToggle; a[i].enabled = !a[i].enabled; saveAlarms(a); renderTab(win); };
            });
            content.querySelector('#alarm-add').onclick = () => {
                // No native prompt() dialog in NUI's CEF context — default to
                // one minute from now and let the toggle/edit flow adjust it.
                const now = new Date();
                const a = loadAlarms();
                a.push({ hour: now.getHours(), minute: (now.getMinutes() + 1) % 60, enabled: true, label: 'New Alarm' });
                saveAlarms(a);
                renderTab(win);
            };
        }
    }

    let stopwatchTicker = null;
    function fmtStopwatch(ms) {
        const s = Math.floor(ms / 1000);
        return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
    }
    function fmtTimer(s) { return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; }
    function tickTimer(win) {
        if (!timerRunning) return;
        setTimeout(() => {
            if (!timerRunning) return;
            timerSeconds = Math.max(0, timerSeconds - 1);
            if (activeWin === win && tab === 'timer') renderTab(win);
            if (timerSeconds > 0) tickTimer(win); else { timerRunning = false; HD.toast('Timer done.'); }
        }, 1000);
    }
    setInterval(() => { if (activeWin && tab === 'stopwatch' && stopwatchRunning) renderTab(activeWin); }, 250);

    window.HDApps.clock = { open(win) { activeWin = win; render(win); } };
})();
