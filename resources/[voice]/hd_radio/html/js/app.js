(function () {
    'use strict';

    const chip = document.getElementById('channelChip');

    // Real bundled .wav audio files (html/audio/), not live-generated
    // Web Audio oscillators — generated with Python's stdlib `wave`
    // module (see the main README's Voice & Radio section for exactly
    // how). The tones themselves are still synthesised — a short
    // two-tone pip inspired by the UK Airwave-style confirmation beep
    // — this isn't a field recording of real Airwave/TETRA equipment,
    // just an actual audio file instead of runtime-generated sound.
    const pttOn = new Audio('audio/ptt_on.wav');
    const pttOff = new Audio('audio/ptt_off.wav');
    pttOn.volume = 0.5;
    pttOff.volume = 0.5;

    function playPip(rising) {
        const audio = rising ? pttOn : pttOff;
        audio.currentTime = 0;
        audio.play().catch(() => {}); // ignored — browser autoplay policy before any user gesture, extremely rare in an always-loaded game NUI
    }

    window.addEventListener('message', (event) => {
        const d = event.data;
        if (d.action === 'channel') {
            if (d.channel > 0) {
                chip.textContent = `CH ${d.channel}`;
                chip.classList.add('on');
            } else {
                chip.classList.remove('on');
            }
        } else if (d.action === 'tone') {
            chip.classList.toggle('talking', !!d.on);
            playPip(!!d.on);
        }
    });
})();
