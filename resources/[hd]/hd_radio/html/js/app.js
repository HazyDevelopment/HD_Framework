(function () {
    'use strict';

    const chip = document.getElementById('channelChip');
    const chipFreq = document.getElementById('chipFreq');
    const radio = document.getElementById('radio');
    const freqDigits = document.getElementById('freqDigits');
    const channelLabel = document.getElementById('channelLabel');
    const powerState = document.getElementById('powerState');
    const volSlider = document.getElementById('volSlider');
    const volValue = document.getElementById('volValue');
    const panicBtn = document.getElementById('panicBtn');
    const p2pBtn = document.getElementById('p2pBtn');
    const endBtn = document.getElementById('endBtn');

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_radio';

    function post(endpoint, body) {
        fetch(`https://${resourceName}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => {});
    }

    // Real bundled .ogg files (html/audio/) — self-confirmation/alert
    // tones played on the LOCAL player's own handheld, same as a real
    // Airwave/TETRA set's built-in sounds. Never the other side's
    // actual voice audio — that's pma-voice/mumble entirely.
    const sounds = {
        ptt: new Audio('audio/PTT.ogg'),
        bleep: new Audio('audio/SingleBleep.ogg'),
        panic: new Audio('audio/Panic.ogg'),
        p2p: new Audio('audio/P2P.ogg'),
    };

    let volume = 65;
    function applyVolumeToSounds() {
        const v = Math.max(0, Math.min(1, volume / 100));
        for (const key in sounds) sounds[key].volume = v;
    }
    applyVolumeToSounds();

    function play(name) {
        const audio = sounds[name];
        audio.currentTime = 0;
        audio.play().catch(() => {}); // ignored — browser autoplay policy before any user gesture, extremely rare in an always-loaded game NUI
    }

    let radioOn = false;
    let currentChannel = 0; // integer channel, freq * 100 — see config.lua
    let typedBuffer = '';

    function formatBuffer(buf) {
        if (buf.length <= 2) return buf;
        return buf.slice(0, buf.length - 2) + '.' + buf.slice(buf.length - 2);
    }

    function bufferToFreq(buf) {
        if (buf.length <= 2) return `${buf}.00`;
        return buf.slice(0, buf.length - 2) + '.' + buf.slice(buf.length - 2);
    }

    function channelToFreqText(channel) {
        return (channel / 100).toFixed(2);
    }

    function renderDisplay() {
        if (typedBuffer.length > 0) {
            freqDigits.textContent = formatBuffer(typedBuffer);
        } else if (currentChannel > 0) {
            freqDigits.textContent = channelToFreqText(currentChannel);
        } else {
            freqDigits.textContent = '--.--';
        }
    }

    function updatePowerUI() {
        powerState.textContent = radioOn ? 'ON' : 'OFF';
        powerState.classList.toggle('on', radioOn);
        powerState.classList.toggle('off', !radioOn);
    }

    function updateChannelUI() {
        if (currentChannel > 0) {
            channelLabel.textContent = `CH ${channelToFreqText(currentChannel)}`;
            chipFreq.textContent = `${channelToFreqText(currentChannel)} MHz`;
            chip.classList.add('on');
        } else {
            channelLabel.textContent = radioOn ? 'Standby' : 'Off';
            chip.classList.remove('on', 'talking');
        }
        renderDisplay();
    }

    // ── Keypad: build a frequency in a scratch buffer, tune with # / OK ──
    document.querySelectorAll('.key[data-digit]').forEach((btn) => {
        btn.addEventListener('click', () => {
            if (typedBuffer.length >= 4) return;
            typedBuffer += btn.dataset.digit;
            renderDisplay();
        });
    });

    function submitTune() {
        if (typedBuffer.length === 0) return;
        post('tune', { freq: bufferToFreq(typedBuffer) });
        typedBuffer = '';
    }

    function clearBuffer() {
        typedBuffer = '';
        renderDisplay();
    }

    document.querySelectorAll('[data-action="tune"]').forEach((btn) => btn.addEventListener('click', submitTune));
    document.querySelectorAll('[data-action="clear"]').forEach((btn) => btn.addEventListener('click', clearBuffer));

    document.querySelector('[data-action="off"]').addEventListener('click', () => {
        typedBuffer = '';
        post('off');
    });

    document.querySelector('[data-action="close"]').addEventListener('click', () => post('close'));

    document.querySelector('[data-action="power"]').addEventListener('click', () => {
        post('power', { on: !radioOn });
    });

    // ── D-pad: nudge the currently tuned channel when not mid-entry ──
    document.querySelectorAll('.dpadBtn[data-nudge]').forEach((btn) => {
        btn.addEventListener('click', () => {
            if (typedBuffer.length > 0) return; // a digit entry in progress takes priority
            const delta = parseInt(btn.dataset.nudge, 10);
            const next = Math.max(0, Math.min(9999, currentChannel + delta));
            post('tune', { freq: channelToFreqText(next) });
        });
    });

    volSlider.addEventListener('input', () => {
        volume = parseInt(volSlider.value, 10);
        volValue.textContent = String(volume);
        applyVolumeToSounds();
    });
    volSlider.addEventListener('change', () => {
        post('volume', { volume });
    });

    panicBtn.addEventListener('click', () => post('panic'));
    p2pBtn.addEventListener('click', () => post('p2p'));
    endBtn.addEventListener('click', () => {
        panicBtn.classList.remove('flash');
        p2pBtn.classList.remove('ring');
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && radio.classList.contains('open')) post('close');
    });

    window.addEventListener('message', (event) => {
        const d = event.data;
        if (d.action === 'channel') {
            currentChannel = d.channel || 0;
            updateChannelUI();
        } else if (d.action === 'power') {
            radioOn = !!d.on;
            updatePowerUI();
            updateChannelUI();
            if (radioOn) play('bleep');
        } else if (d.action === 'tone') {
            chip.classList.toggle('talking', !!d.on);
            if (d.on) play('ptt');
        } else if (d.action === 'panicTone') {
            play('panic');
            panicBtn.classList.add('flash');
            setTimeout(() => panicBtn.classList.remove('flash'), 4000);
        } else if (d.action === 'p2pTone') {
            play('p2p');
            p2pBtn.classList.add('ring');
            setTimeout(() => p2pBtn.classList.remove('ring'), 2500);
        } else if (d.action === 'toggle') {
            radio.classList.toggle('open', !!d.open);
            if (d.open) {
                if (typeof d.volume === 'number') {
                    volume = d.volume;
                    volSlider.value = String(volume);
                    volValue.textContent = String(volume);
                    applyVolumeToSounds();
                }
                if (typeof d.on === 'boolean') {
                    radioOn = d.on;
                    updatePowerUI();
                }
                typedBuffer = '';
                renderDisplay();
            }
        }
    });
})();
