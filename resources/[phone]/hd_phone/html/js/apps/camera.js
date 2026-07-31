// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | CAMERA
//  No live viewfinder feed inside the NUI itself (screenshot-basic
//  captures the real screen behind the phone at shutter time, it
//  doesn't stream a preview into an iframe) — the shutter is what's
//  real here, not a faked video feed.
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};

    function render(win) {
        win.style.background = 'rgba(0,0,0,0.05)';
        win.innerHTML = `
            <div style="position:absolute;top:54px;left:0;right:0;display:flex;justify-content:space-between;padding:0 18px;z-index:2;">
                <div class="lock-quick-btn" id="cam-close" style="background:rgba(0,0,0,0.4);">${closeSvg()}</div>
            </div>
            <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,0.6);font-size:13px;text-align:center;padding:0 40px;">
                Point your character where you want, then tap the shutter.
            </div>
            <div style="position:absolute;bottom:30px;left:0;right:0;display:flex;justify-content:center;align-items:center;z-index:2;">
                <div id="cam-shutter" style="width:70px;height:70px;border-radius:50%;background:#fff;border:4px solid rgba(255,255,255,0.4);"></div>
            </div>`;
        win.querySelector('#cam-close').onclick = () => HD.closeApp();
        win.querySelector('#cam-shutter').onclick = takePhoto;
    }

    function closeSvg() { return `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4"><path d="M6 6l12 12M18 6 6 18"/></svg>`; }

    function takePhoto() {
        HD.toast('Taking photo…');
        HD.post('takePhoto', {}).then((res) => {
            if (!res || !res.ok) {
                HD.toast((res && res.reason) || 'Could not take photo.');
                return;
            }
            HD.post('saveFromCamera', { imageUrl: res.url });
            HD.toast('Photo saved to Photos.');
        });
    }

    window.HDApps.camera = { open(win) { render(win); } };
})();
