(function () {
    'use strict';

    const $ = (id) => document.getElementById(id);

    function fmtCash(n) {
        return '£' + Math.floor(n).toLocaleString('en-GB');
    }

    function setVital(key, pct, lowThreshold) {
        const el = document.querySelector(`.vital[data-key="${key}"]`);
        if (!el) return;
        if (pct == null) {
            el.classList.add('hidden');
            return;
        }
        el.classList.remove('hidden');
        el.querySelector('.vital-ring').style.setProperty('--pct', Math.max(0, Math.min(100, pct)));
        el.classList.toggle('low', pct <= (lowThreshold || 25));
    }

    // ═══════════════════════════ /hudsettings ═══════════════════════════
    // Client-side only — same "no server table for this" pattern as the
    // loading screen's volume slider and the phone's Clock alarms.
    // Minimap is deliberately excluded: it's the native radar
    // repositioned via natives, not a DOM element, so dragging it here
    // wouldn't move the real thing.
    const DRAGGABLE = ['watermark', 'topRight', 'vitals', 'vehicleHud'];
    const POS_KEY = 'hd_hud_positions';
    const VIS_KEY = 'hd_hud_visibility';
    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_hud';

    function loadJSON(key) {
        try { return JSON.parse(localStorage.getItem(key)) || {}; } catch (e) { return {}; }
    }

    function applySavedPositions() {
        const pos = loadJSON(POS_KEY);
        DRAGGABLE.forEach((id) => {
            const saved = pos[id];
            if (!saved) return;
            const el = $(id);
            el.style.left = saved.left + 'px';
            el.style.top = saved.top + 'px';
            el.style.right = 'auto';
            el.style.bottom = 'auto';
        });
    }

    function applySavedVisibility() {
        const vis = loadJSON(VIS_KEY);
        DRAGGABLE.forEach((id) => {
            if (vis[id] === false) $(id).classList.add('hidden');
        });
    }

    let dragEl = null, dragOffsetX = 0, dragOffsetY = 0;
    function onSettingsMouseDown(e) {
        const el = e.target.closest('#watermark, #topRight, #vitals, #vehicleHud');
        if (!el) return;
        dragEl = el;
        const rect = el.getBoundingClientRect();
        dragOffsetX = e.clientX - rect.left;
        dragOffsetY = e.clientY - rect.top;
        e.preventDefault();
    }
    function onSettingsMouseMove(e) {
        if (!dragEl) return;
        dragEl.style.left = (e.clientX - dragOffsetX) + 'px';
        dragEl.style.top = (e.clientY - dragOffsetY) + 'px';
        dragEl.style.right = 'auto';
        dragEl.style.bottom = 'auto';
    }
    function onSettingsMouseUp() {
        if (!dragEl) return;
        const pos = loadJSON(POS_KEY);
        pos[dragEl.id] = { left: parseFloat(dragEl.style.left), top: parseFloat(dragEl.style.top) };
        localStorage.setItem(POS_KEY, JSON.stringify(pos));
        dragEl = null;
    }
    document.addEventListener('mousedown', onSettingsMouseDown);
    document.addEventListener('mousemove', onSettingsMouseMove);
    document.addEventListener('mouseup', onSettingsMouseUp);

    function setEditing(on) {
        document.getElementById('root').classList.toggle('hud-editing', on);
        $('hudSettings').classList.toggle('hidden', !on);
    }

    function closeSettings() {
        setEditing(false);
        fetch(`https://${resourceName}/closeHudSettings`, { method: 'POST', body: '{}' }).catch(() => {});
    }

    $('hsClose').addEventListener('click', closeSettings);
    $('hsReset').addEventListener('click', () => {
        localStorage.removeItem(POS_KEY);
        DRAGGABLE.forEach((id) => {
            const el = $(id);
            el.style.left = '';
            el.style.top = '';
            el.style.right = '';
            el.style.bottom = '';
        });
    });
    document.querySelectorAll('#hudSettings input[data-comp]').forEach((input) => {
        input.addEventListener('change', () => {
            const vis = loadJSON(VIS_KEY);
            vis[input.dataset.comp] = input.checked;
            localStorage.setItem(VIS_KEY, JSON.stringify(vis));
            $(input.dataset.comp).classList.toggle('hidden', !input.checked);
        });
    });
    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape' && !$('hudSettings').classList.contains('hidden')) closeSettings();
    });

    applySavedPositions();
    applySavedVisibility();

    window.addEventListener('message', (event) => {
        const d = event.data;
        switch (d.action) {
            case 'toggleSettings':
                setEditing(!!d.show);
                if (d.show) {
                    const vis = loadJSON(VIS_KEY);
                    document.querySelectorAll('#hudSettings input[data-comp]').forEach((input) => {
                        input.checked = vis[input.dataset.comp] !== false;
                    });
                }
                break;

            case 'watermark':
                $('watermark').textContent = d.text || 'Hazy Development';
                $('watermark').style.color = d.color || 'rgba(147, 51, 234, 0.35)';
                break;

            case 'vitals':
                setVital('health', d.health, d.lowThreshold);
                setVital('armor', d.armor, d.lowThreshold);
                setVital('hunger', d.hunger, d.lowThreshold);
                setVital('thirst', d.thirst, d.lowThreshold);
                $('cashValue').textContent = fmtCash(d.cash || 0);
                $('jobLabel').textContent = d.jobLabel || 'Unemployed';
                $('jobGrade').textContent = d.jobGrade || '';
                break;

            case 'vehicleShow': {
                // Respect a saved "hide Vehicle HUD" preference from
                // /hudsettings — don't let entering a vehicle force it
                // back on.
                const vehVisPref = loadJSON(VIS_KEY).vehicleHud !== false;
                $('vehicleHud').classList.toggle('hidden', !d.show || !vehVisPref);
                $('minimapCluster').classList.toggle('hidden', !d.show);
                break;
            }

            case 'compass':
                $('compassHeading').textContent = d.heading || 'N';
                $('streetName').textContent = d.street || ' ';
                break;

            case 'vehicleUpdate': {
                const arcPct = Math.max(0, Math.min(100, (d.speed / (d.maxSpeed || 150)) * 100));
                const trackFill = $('speedoTrackFill');
                trackFill.style.width = arcPct + '%';
                trackFill.classList.toggle('redline', arcPct >= 85);
                $('speedValue').textContent = d.speed;

                const fuelPct = d.tank > 0 ? (d.fuel / d.tank) * 100 : 0;
                const fuelFill = $('fuelFill');
                fuelFill.style.width = Math.max(0, Math.min(100, fuelPct)) + '%';
                fuelFill.classList.toggle('low', fuelPct <= 15);
                $('fuelValue').textContent = d.fuel + 'L';

                const gearEl = $('gearValue');
                gearEl.textContent = d.engineOn === false ? 'OFF' : (d.gear === 0 ? 'R' : d.gear);
                break;
            }

            case 'seatbelt': {
                const icon = $('seatbeltIcon');
                icon.classList.toggle('on', !!d.on);
                icon.classList.toggle('warn', !d.on);
                break;
            }
        }
    });
})();
