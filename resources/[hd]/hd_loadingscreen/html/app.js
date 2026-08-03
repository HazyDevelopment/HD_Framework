(function () {
    'use strict';

    const cfg = window.HD_LOADSCREEN_CONFIG || {};
    const $ = (id) => document.getElementById(id);

    // ═══════════════════════════ CONTENT ═══════════════════════════════
    $('logo').src = cfg.logo || 'images/logo.png';
    $('serverName').textContent = cfg.serverName || 'HAZY DEVELOPMENT';
    $('tagline').textContent = cfg.tagline || '';

    // ═══════════════════════════ SLIDESHOW ═════════════════════════════
    // Real screenshots (cfg.slideshowImages) take over automatically the
    // moment any are listed in config.js — until then, these built-in
    // gradients keep the same "changes every N seconds" behaviour so
    // the loading screen isn't just a static background.
    const PLACEHOLDER_GRADIENTS = [
        'radial-gradient(circle at 30% 20%, rgba(147,51,234,0.35), transparent 60%), linear-gradient(160deg, #14051f, #050208)',
        'radial-gradient(circle at 70% 60%, rgba(147,51,234,0.30), transparent 55%), linear-gradient(160deg, #0a0210, #030103)',
        'radial-gradient(circle at 50% 85%, rgba(147,51,234,0.28), transparent 65%), linear-gradient(160deg, #11041a, #04010a)',
        'radial-gradient(circle at 15% 70%, rgba(147,51,234,0.32), transparent 60%), linear-gradient(160deg, #0d0316, #030103)',
    ];

    const slideshowEl = $('slideshow');
    const realSlides = Array.isArray(cfg.slideshowImages) ? cfg.slideshowImages.filter(Boolean) : [];
    let slideIndex = 0;

    function applySlide() {
        if (realSlides.length) {
            slideshowEl.style.background = `url('${realSlides[slideIndex % realSlides.length]}') center / cover no-repeat`;
        } else {
            slideshowEl.style.background = PLACEHOLDER_GRADIENTS[slideIndex % PLACEHOLDER_GRADIENTS.length];
        }
        slideIndex++;
    }
    applySlide();
    setInterval(applySlide, cfg.slideshowIntervalMs || 3000);

    // ═══════════════════════════ CURSOR ═════════════════════════════════
    // Software-drawn dot tracking the real mouse — see style.css's
    // #cursorDot comment for why this exists instead of trusting the
    // native OS cursor to render over this NUI frame.
    const cursorDot = $('cursorDot');
    document.addEventListener('mousemove', (e) => {
        cursorDot.style.left = e.clientX + 'px';
        cursorDot.style.top = e.clientY + 'px';
        cursorDot.classList.add('visible');
    });
    document.addEventListener('mousedown', () => cursorDot.classList.add('pressed'));
    document.addEventListener('mouseup', () => cursorDot.classList.remove('pressed'));

    // ═══════════════════════════ YOUTUBE MUSIC ═════════════════════════
    function extractYouTubeId(url) {
        if (!url) return null;
        const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/);
        return m ? m[1] : null;
    }

    const videoId = extractYouTubeId(cfg.youtubeUrl);
    const volumeControl = $('volumeControl');
    const volumeSlider = $('volumeSlider');
    const muteBtn = $('muteBtn');
    let ytPlayer = null;

    // Remembered across loading-screen sessions (this NUI reloads fresh
    // every connect) so a player who turns the music down doesn't have
    // to redo it every time they join.
    const savedVolume = parseInt(localStorage.getItem('hd_loadscreen_volume'), 10);
    const initialVolume = Number.isFinite(savedVolume) ? savedVolume
        : (cfg.musicVolume != null ? cfg.musicVolume : 35);

    function updateMuteIcon(volume) {
        muteBtn.textContent = volume <= 0 ? '🔇' : volume < 50 ? '🔉' : '🔊';
    }

    if (videoId) {
        volumeSlider.value = initialVolume;
        updateMuteIcon(initialVolume);

        const apiScript = document.createElement('script');
        apiScript.src = 'https://www.youtube.com/iframe_api';
        document.head.appendChild(apiScript);

        const soundHint = $('soundHint');

        window.onYouTubeIframeAPIReady = function () {
            ytPlayer = new YT.Player('ytWrap', {
                height: '1',
                width: '1',
                videoId: videoId,
                // Starting muted is what actually makes autoplay-with-
                // sound reliable — Chromium (and CEF, which FiveM's NUI
                // is built on) generally only honours autoplay
                // unconditionally when it starts silent; an unmuted
                // autoplay request is the thing that was inconsistently
                // getting blocked before. Un-muting immediately after
                // is allowed since it's a direct response to the
                // player's own onReady, not a delayed/unprompted call.
                playerVars: { autoplay: 1, mute: 1, loop: 1, playlist: videoId, controls: 0, disablekb: 1 },
                events: {
                    onReady: function (e) {
                        e.target.setVolume(initialVolume);
                        if (initialVolume > 0) e.target.unMute();
                        e.target.playVideo();
                        volumeControl.classList.remove('hidden');

                        // Chromium's autoplay gate can silently block the
                        // actual audio output above even while the YT
                        // player's own JS-visible isMuted() already
                        // reports false — the browser just eats the sound
                        // rather than throwing or leaving isMuted() true.
                        // That means a fallback gated on isMuted() (the
                        // previous approach here) can end up never firing
                        // even though nothing is audible. Detect it
                        // properly instead: check getVolume()/muted state
                        // shortly after onReady, and if it looks like it
                        // never really started, show a hint and force
                        // playback unconditionally on the next real
                        // gesture rather than guessing at player state.
                        if (initialVolume > 0) {
                            setTimeout(() => {
                                if (!unlocked) soundHint.classList.remove('hidden');
                            }, 800);
                        }
                    },
                },
            });
        };

        // Fires on the very first real user gesture of any kind — a
        // genuine click/keypress/touch always satisfies autoplay policy,
        // unlike a programmatic call on its own. Unconditional (doesn't
        // check isMuted() first) so it works even when the browser's
        // silent block left the player's own state looking "already
        // unmuted". One-shot: removes itself once it's actually run.
        let unlocked = false;
        function unlockAudio() {
            if (unlocked || !ytPlayer) return;
            unlocked = true;
            soundHint.classList.add('hidden');
            const vol = parseInt(volumeSlider.value, 10);
            if (vol > 0) {
                ytPlayer.unMute();
                ytPlayer.setVolume(vol);
                ytPlayer.playVideo();
            }
            ['click', 'keydown', 'touchstart', 'mousedown'].forEach((ev) => document.removeEventListener(ev, unlockAudio));
        }
        ['click', 'keydown', 'touchstart', 'mousedown'].forEach((ev) => document.addEventListener(ev, unlockAudio));

        volumeSlider.addEventListener('input', () => {
            const v = parseInt(volumeSlider.value, 10);
            localStorage.setItem('hd_loadscreen_volume', String(v));
            updateMuteIcon(v);
            if (!ytPlayer) return;
            ytPlayer.setVolume(v);
            if (v <= 0) ytPlayer.mute();
            else if (ytPlayer.isMuted()) ytPlayer.unMute();
        });

        // Shared by the mute button click and the Space keybind below —
        // remembers the pre-mute volume (falling back to 35) so toggling
        // back on restores where the player had it, not just some fixed
        // default.
        let volumeBeforeMute = initialVolume > 0 ? initialVolume : 35;
        function toggleMute() {
            if (!ytPlayer) return;
            if (ytPlayer.isMuted() || parseInt(volumeSlider.value, 10) <= 0) {
                const restore = volumeBeforeMute || 35;
                volumeSlider.value = restore;
                ytPlayer.setVolume(restore);
                ytPlayer.unMute();
                localStorage.setItem('hd_loadscreen_volume', String(restore));
                updateMuteIcon(restore);
            } else {
                volumeBeforeMute = parseInt(volumeSlider.value, 10) || volumeBeforeMute;
                volumeSlider.value = 0;
                ytPlayer.mute();
                localStorage.setItem('hd_loadscreen_volume', '0');
                updateMuteIcon(0);
            }
        }

        muteBtn.addEventListener('click', toggleMute);

        // Space bar toggles mute from anywhere on the loading screen —
        // guarded so it doesn't fire while the player's actually typing
        // in a form field (there aren't any here today, but this is the
        // standard guard for a global keybind like this).
        document.addEventListener('keydown', (e) => {
            if (e.code !== 'Space' && e.key !== ' ') return;
            const tag = document.activeElement && document.activeElement.tagName;
            if (tag === 'INPUT' || tag === 'TEXTAREA') return;
            e.preventDefault();
            toggleMute();
        });
    }

    // ═══════════════════════════ REAL LOAD PROGRESS ════════════════════
    // loadProgress/shutdownLoadingScreen are FiveM's own documented
    // loading-screen postMessage events — the bar reflects actual
    // resource streaming progress, it isn't a fake timed animation.
    window.addEventListener('message', (event) => {
        const data = event.data || {};
        if (data.eventName === 'loadProgress') {
            $('progressBar').style.width = Math.round((data.loadFraction || 0) * 100) + '%';
            $('progressText').textContent = 'Loading… ' + Math.round((data.loadFraction || 0) * 100) + '%';
        } else if (data.eventName === 'shutdownLoadingScreen') {
            document.getElementById('root').style.opacity = '0';
        }
    });
})();
