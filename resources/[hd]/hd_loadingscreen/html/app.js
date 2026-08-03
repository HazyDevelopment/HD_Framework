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

    // console.log throughout this section on purpose — FiveM's NUI has
    // its own dev tools (Alt+F5 in-game, or F8 console for resource
    // errors), and since none of this can be tested against a real
    // FiveM client from outside the game, these are the breadcrumbs
    // needed to diagnose it from a report of what actually printed.
    const LOG = (...args) => console.log('[hd_loadingscreen]', ...args);

    if (videoId) {
        volumeSlider.value = initialVolume;
        updateMuteIcon(initialVolume);

        const soundHint = $('soundHint');
        let unlocked = false;

        // Plain embed URL, autoplay/loop/mute all as query params — this
        // is what actually starts playing with NO JavaScript API call
        // required at all, since those params take effect the moment
        // the iframe itself loads. The JS IFrame Player API (added
        // below) is used only for *convenience* afterwards (volume
        // slider, mute toggle) — if its postMessage-based remote-control
        // channel doesn't work correctly in FiveM's NUI origin for
        // whatever reason, the music still starts, it just means the
        // slider/button might not, which is the better failure mode.
        function embedUrl(muted) {
            const params = new URLSearchParams({
                autoplay: '1',
                mute: muted ? '1' : '0',
                loop: '1',
                playlist: videoId,
                controls: '0',
                disablekb: '1',
                enablejsapi: '1',
                playsinline: '1',
                origin: window.location.origin,
            });
            return `https://www.youtube.com/embed/${videoId}?${params.toString()}`;
        }

        const ytFrame = document.createElement('iframe');
        ytFrame.id = 'ytFrame';
        ytFrame.width = '1';
        ytFrame.height = '1';
        ytFrame.allow = 'autoplay; encrypted-media';
        ytFrame.src = embedUrl(true);
        $('ytWrap').appendChild(ytFrame);
        LOG('embed created, muted start:', ytFrame.src);

        // Best-effort JS API layer on top of the same iframe — gives the
        // volume slider/mute button real control when the postMessage
        // channel works. `videoId`/`events` are irrelevant here since the
        // iframe already has its own real src; this just attaches to it.
        const apiScript = document.createElement('script');
        apiScript.src = 'https://www.youtube.com/iframe_api';
        document.head.appendChild(apiScript);

        window.onYouTubeIframeAPIReady = function () {
            LOG('iframe_api ready, attaching controller');
            ytPlayer = new YT.Player(ytFrame, {
                events: {
                    onReady: function (e) {
                        LOG('onReady — player state:', e.target.getPlayerState());
                        volumeControl.classList.remove('hidden');
                        e.target.setVolume(initialVolume);
                        // Try unmuting via the API too, in case this
                        // client's autoplay policy is fine with it —
                        // harmless if it's silently ignored.
                        if (initialVolume > 0 && !unlocked) e.target.unMute();
                    },
                    onError: function (e) {
                        // 2=bad param, 5=HTML5 error, 100=video removed/private,
                        // 101/150=embedding disabled by the uploader — the
                        // last one is the single most common real-world
                        // reason a specific video plays everywhere else but
                        // not here, worth calling out explicitly.
                        LOG('YouTube player error code', e.data, e.data === 101 || e.data === 150
                            ? '— this video has embedding disabled by its uploader, pick a different one'
                            : '');
                    },
                },
            });
        };

        // Fires on the very first real user gesture of any kind. Forces
        // a fresh, DIRECTLY-gesture-triggered unmuted load of the same
        // embed (bypassing the JS API/postMessage entirely) — a brand
        // new navigation with autoplay+unmuted params, made synchronously
        // inside a real click/key/touch handler, is honoured far more
        // reliably by autoplay policy than an async postMessage command
        // is, regardless of whatever's going on with the API channel.
        // Also nudges the API-based player in parallel, best-effort.
        function unlockAudio() {
            if (unlocked) return;
            unlocked = true;
            soundHint.classList.add('hidden');
            const vol = parseInt(volumeSlider.value, 10);
            LOG('user gesture received, forcing playback at volume', vol);
            if (vol > 0) {
                ytFrame.src = embedUrl(false);
                if (ytPlayer && typeof ytPlayer.unMute === 'function') {
                    try { ytPlayer.unMute(); ytPlayer.setVolume(vol); ytPlayer.playVideo(); } catch (err) { LOG('API nudge failed', err); }
                }
            }
            ['click', 'keydown', 'touchstart', 'mousedown'].forEach((ev) => document.removeEventListener(ev, unlockAudio));
        }
        ['click', 'keydown', 'touchstart', 'mousedown'].forEach((ev) => document.addEventListener(ev, unlockAudio));

        // If nothing has unlocked it within a couple seconds, show the
        // hint — a passive player who never clicks anything otherwise
        // has no idea sound is one keypress away.
        if (initialVolume > 0) {
            setTimeout(() => {
                if (!unlocked) soundHint.classList.remove('hidden');
            }, 1500);
        }

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
