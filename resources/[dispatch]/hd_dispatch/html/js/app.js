(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_dispatch';

    let calls = {};
    let callTypesCfg = {};
    let grades = {};
    let mySrc = null;
    let activeTab = 'all';
    let selected999Type = null;
    let recoveryPlate = '';

    const $board = document.getElementById('board');
    const $boardSub = document.getElementById('boardSub');
    const $boardTabs = document.getElementById('boardTabs');
    const $boardList = document.getElementById('boardList');
    const $callMenu = document.getElementById('callMenu');
    const $menuTitle = document.getElementById('menuTitle');
    const $menu999 = document.getElementById('menu999');
    const $menuRecovery = document.getElementById('menuRecovery');
    const $toasts = document.getElementById('toasts');

    function post(action, data) {
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    // ═══════════════════════════ UTIL ═══════════════════════════════
    function timeAgo(unixSeconds) {
        const diff = Math.max(0, Math.floor(Date.now() / 1000) - unixSeconds);
        if (diff < 60) return `${diff}s ago`;
        if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
        return `${Math.floor(diff / 3600)}h ago`;
    }

    function statusLabel(status) {
        return { open: 'OPEN', enroute: 'EN ROUTE', onscene: 'ON SCENE', closed: 'CLOSED' }[status] || status.toUpperCase();
    }

    // ═══════════════════════════ AUDIO ALERT ══════════════════════════
    let audioCtx = null;
    function playAlert() {
        try {
            audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
            const now = audioCtx.currentTime;
            [[880, 0], [660, 0.14]].forEach(([freq, delay]) => {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'sine';
                osc.frequency.value = freq;
                gain.gain.setValueAtTime(0.0001, now + delay);
                gain.gain.exponentialRampToValueAtTime(0.22, now + delay + 0.02);
                gain.gain.exponentialRampToValueAtTime(0.0001, now + delay + 0.13);
                osc.connect(gain).connect(audioCtx.destination);
                osc.start(now + delay);
                osc.stop(now + delay + 0.15);
            });
        } catch (e) { /* audio unavailable, ignore */ }
    }

    // ═══════════════════════════ TOASTS ═══════════════════════════════
    function addToast(call) {
        const ct = callTypesCfg[call.kind];
        if (!ct) return;
        const el = document.createElement('div');
        el.className = 'toast';
        el.style.setProperty('--accent', ct.accent);
        el.innerHTML = `
            <div class="toast-code">${ct.code}</div>
            <div class="toast-title">${escapeHtml(call.title)}</div>
            <div class="toast-desc">${escapeHtml(call.description || '')}</div>
        `;
        $toasts.appendChild(el);
        setTimeout(() => el.remove(), 7000);
        while ($toasts.children.length > 4) $toasts.removeChild($toasts.firstChild);
    }

    function escapeHtml(str) {
        const d = document.createElement('div');
        d.textContent = str == null ? '' : String(str);
        return d.innerHTML;
    }

    // ═══════════════════════════ BOARD RENDER ═════════════════════════
    function buildTabs() {
        $boardTabs.innerHTML = '';
        const all = document.createElement('button');
        all.className = 'tab-btn' + (activeTab === 'all' ? ' active' : '');
        all.textContent = 'ALL';
        all.style.setProperty('--accent', '#3E7CB1');
        all.addEventListener('click', () => { activeTab = 'all'; renderBoard(); });
        $boardTabs.appendChild(all);

        Object.keys(callTypesCfg).forEach((kind) => {
            const ct = callTypesCfg[kind];
            const btn = document.createElement('button');
            btn.className = 'tab-btn' + (activeTab === kind ? ' active' : '');
            btn.textContent = ct.code;
            btn.style.setProperty('--accent', ct.accent);
            btn.addEventListener('click', () => { activeTab = kind; renderBoard(); });
            $boardTabs.appendChild(btn);
        });
    }

    function cardHtml(call) {
        const ct = callTypesCfg[call.kind] || { accent: '#3E7CB1', code: call.kind.toUpperCase() };
        const grade = grades[call.priority] || { name: `Priority ${call.priority}`, color: '#3E7CB1' };
        const isAssignedToMe = (call.assigned || []).some((u) => u.src === mySrc);
        const assignedText = (call.assigned || []).length
            ? call.assigned.map((u) => escapeHtml(u.name)).join(', ')
            : 'No units assigned';

        let actions = `<button class="btn-waypoint" data-action="waypoint" data-id="${call.id}">Waypoint</button>`;
        if (!isAssignedToMe && call.status !== 'closed') {
            actions += `<button class="btn-accept" data-action="accept" data-id="${call.id}">Accept</button>`;
        }
        if (isAssignedToMe) {
            if (call.status !== 'onscene') {
                actions += `<button class="btn-scene" data-action="onscene" data-id="${call.id}">On Scene</button>`;
            }
            actions += `<button class="btn-close" data-action="close" data-id="${call.id}">Close</button>`;
        }

        return `
        <div class="call-card" style="--accent:${ct.accent}; --priority:${grade.color}">
            <div class="call-top">
                <div>
                    <div class="call-code">${ct.code}</div>
                    <div class="call-title">${escapeHtml(call.title)}</div>
                </div>
                <span class="priority-pill">${escapeHtml(grade.name)}</span>
            </div>
            <div class="call-desc">${escapeHtml(call.description || '')}</div>
            <div class="assigned-row"><b>Units:</b> ${assignedText}</div>
            <div class="call-meta">
                <span>${timeAgo(call.created)}</span>
                <span class="status-pill">${statusLabel(call.status)}</span>
            </div>
            <div class="call-actions">${actions}</div>
        </div>`;
    }

    function renderBoard() {
        buildTabs();
        const list = Object.values(calls)
            .filter((c) => activeTab === 'all' || c.kind === activeTab)
            .sort((a, b) => (a.priority - b.priority) || (a.created - b.created));

        $boardList.innerHTML = list.length
            ? list.map(cardHtml).join('')
            : '<div class="empty-state">No active calls.</div>';
    }

    $boardList.addEventListener('click', (e) => {
        const btn = e.target.closest('button[data-action]');
        if (!btn) return;
        const id = Number(btn.dataset.id);
        const call = calls[id];
        switch (btn.dataset.action) {
            case 'accept': post('acceptCall', { id }); break;
            case 'onscene': post('setStatus', { id, status: 'onscene' }); break;
            case 'close': post('closeCall', { id }); break;
            case 'waypoint': if (call) post('setWaypoint', { coords: call.coords }); break;
        }
    });

    document.getElementById('boardClose').addEventListener('click', () => post('closeUI'));

    // ═══════════════════════════ CALL MENU ════════════════════════════
    function resetMenu() {
        selected999Type = null;
        document.getElementById('choicePolice').classList.remove('selected');
        document.getElementById('choiceEms').classList.remove('selected');
        document.getElementById('desc999').value = '';
        document.getElementById('descRecovery').value = '';
        document.getElementById('submit999').disabled = true;
    }

    document.getElementById('choicePolice').addEventListener('click', () => {
        selected999Type = 'police';
        document.getElementById('choicePolice').classList.add('selected');
        document.getElementById('choiceEms').classList.remove('selected');
        document.getElementById('submit999').disabled = false;
    });
    document.getElementById('choiceEms').addEventListener('click', () => {
        selected999Type = 'ems';
        document.getElementById('choiceEms').classList.add('selected');
        document.getElementById('choicePolice').classList.remove('selected');
        document.getElementById('submit999').disabled = false;
    });

    document.getElementById('submit999').addEventListener('click', () => {
        if (!selected999Type) return;
        post('submit999', { type: selected999Type, description: document.getElementById('desc999').value });
        closeMenu();
    });
    document.getElementById('cancel999').addEventListener('click', () => post('closeUI'));

    document.getElementById('submitRecovery').addEventListener('click', () => {
        post('submitRecovery', { plate: recoveryPlate, description: document.getElementById('descRecovery').value });
        closeMenu();
    });
    document.getElementById('cancelRecovery').addEventListener('click', () => post('closeUI'));
    document.getElementById('menuClose').addEventListener('click', () => post('closeUI'));

    function closeMenu() {
        $callMenu.classList.add('hidden');
        post('closeUI');
    }

    // ═══════════════════════════ NUI MESSAGE ROUTER ═══════════════════
    window.addEventListener('message', (event) => {
        const d = event.data;
        switch (d.action) {
            case 'openBoard':
                callTypesCfg = d.callTypes || {};
                grades = d.grades || {};
                mySrc = d.mySrc;
                activeTab = 'all';
                $boardSub.textContent = d.job ? `${d.job.label} — ${d.job.grade.name}` : '—';
                $board.classList.remove('hidden');
                renderBoard();
                break;

            case 'closeBoard':
                $board.classList.add('hidden');
                break;

            case 'openCallMenu':
                resetMenu();
                $callMenu.classList.remove('hidden');
                if (d.mode === '999') {
                    $menuTitle.textContent = 'Report an emergency — 999';
                    $menu999.classList.remove('hidden');
                    $menuRecovery.classList.add('hidden');
                    callTypesCfg = d.callTypes || callTypesCfg;
                } else {
                    recoveryPlate = d.plate || '';
                    $menuTitle.textContent = 'Request vehicle recovery';
                    document.getElementById('recoveryPlate').textContent = recoveryPlate;
                    $menuRecovery.classList.remove('hidden');
                    $menu999.classList.add('hidden');
                }
                break;

            case 'newCall':
                calls[d.call.id] = d.call;
                addToast(d.call);
                if (!$board.classList.contains('hidden')) renderBoard();
                break;

            case 'updateCall':
                calls[d.call.id] = d.call;
                if (!$board.classList.contains('hidden')) renderBoard();
                break;

            case 'removeCall':
                delete calls[d.id];
                if (!$board.classList.contains('hidden')) renderBoard();
                break;

            case 'sync':
                calls = {};
                (d.calls || []).forEach((c) => { calls[c.id] = c; });
                if (!$board.classList.contains('hidden')) renderBoard();
                break;

            case 'alertSound':
                playAlert();
                break;
        }
    });

    document.addEventListener('keyup', (e) => {
        if (e.key !== 'Escape') return;
        if (!$board.classList.contains('hidden')) { $board.classList.add('hidden'); post('closeUI'); }
        if (!$callMenu.classList.contains('hidden')) { $callMenu.classList.add('hidden'); post('closeUI'); }
    });
})();
