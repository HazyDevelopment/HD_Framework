// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | FACETIME
//  Real two-way video/audio, peer-to-peer over WebRTC. server/facetime.lua
//  is a pure signalling relay — media itself never touches the server.
//  Needs the player to grant FiveM camera/mic permission (Windows
//  camera privacy settings must allow FiveM.exe too).
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};

    const ICE_SERVERS = [{ urls: 'stun:stun.l.google.com:19302' }];
    let pc = null;
    let localStream = null;
    let callId = null;
    let isCaller = false;
    let overlay = null;

    function svgHangup() { return `<svg width="26" height="26" viewBox="0 0 24 24" fill="#fff" style="transform:rotate(135deg)"><path d="M12 5c-4.5 0-8.4 1.5-11.3 4a1.5 1.5 0 0 0-.2 2l2 2.5a1.5 1.5 0 0 0 2 .3l2.5-1.7a1.2 1.2 0 0 0 .5-1.3l-.6-2.2A14 14 0 0 1 12 8c1.9 0 3.7.3 5.4.9l-.6 2a1.2 1.2 0 0 0 .5 1.3l2.5 1.8a1.5 1.5 0 0 0 2-.3l2-2.6a1.5 1.5 0 0 0-.2-2C20.4 6.5 16.5 5 12 5Z"/></svg>`; }
    function svgAnswer() { return `<svg width="26" height="26" viewBox="0 0 24 24" fill="#fff"><path d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2a1.5 1.5 0 0 1 1.5-.4c1.2.4 2.5.6 3.9.6a1.5 1.5 0 0 1 1.5 1.5v3.6a1.5 1.5 0 0 1-1.5 1.5C10.5 22 2 13.5 2 3.7A1.5 1.5 0 0 1 3.5 2.2h3.6A1.5 1.5 0 0 1 8.6 3.7c0 1.4.2 2.7.6 3.9.1.5 0 1.1-.4 1.5Z"/></svg>`; }

    function showCallScreen(name, connecting) {
        const el = document.getElementById('call-overlay');
        overlay = el;
        el.classList.remove('hidden');
        el.style.background = '#000';
        el.innerHTML = `
            <video id="ft-remote" autoplay playsinline style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;"></video>
            <video id="ft-local" autoplay playsinline muted style="position:absolute;top:64px;right:14px;width:90px;height:130px;border-radius:12px;object-fit:cover;box-shadow:var(--shadow-md);"></video>
            <div style="position:absolute;top:64px;left:0;right:0;text-align:center;color:#fff;text-shadow:0 2px 8px rgba(0,0,0,0.6);">
                <div style="font-size:18px;font-weight:700;">${name || 'FaceTime'}</div>
                <div id="ft-status" style="font-size:13px;opacity:0.8;">${connecting ? 'Connecting…' : ''}</div>
            </div>
            <div style="position:absolute;bottom:36px;left:0;right:0;display:flex;justify-content:center;gap:24px;">
                <div class="call-btn end" id="ft-hangup">${svgHangup()}</div>
            </div>`;
        document.getElementById('ft-hangup').onclick = endCall;
    }

    function showIncoming(call) {
        callId = call.callId;
        isCaller = false;
        const el = document.getElementById('call-overlay');
        overlay = el;
        el.classList.remove('hidden');
        el.style.background = 'linear-gradient(160deg,#111827,#1f2937)';
        el.innerHTML = `
            <div class="call-avatar">${(call.name || '?').charAt(0)}</div>
            <div class="call-name">${call.name || 'Unknown'}</div>
            <div class="call-status">Incoming FaceTime…</div>
            <div class="call-actions">
                <div class="call-action"><div class="circle decline" id="ft-decline">${svgHangup()}</div>Decline</div>
                <div class="call-action"><div class="circle answer" id="ft-accept">${svgAnswer()}</div>Accept</div>
            </div>`;
        document.getElementById('ft-decline').onclick = () => { HD.post('declineFacetime', { callId }); reset(); };
        document.getElementById('ft-accept').onclick = () => HD.post('acceptFacetime', { callId });
    }

    async function setupMedia() {
        localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
        const localEl = document.getElementById('ft-local');
        if (localEl) localEl.srcObject = localStream;
    }

    async function setupPeerConnection() {
        pc = new RTCPeerConnection({ iceServers: ICE_SERVERS });
        localStream.getTracks().forEach((t) => pc.addTrack(t, localStream));
        pc.ontrack = (e) => {
            const remoteEl = document.getElementById('ft-remote');
            if (remoteEl) remoteEl.srcObject = e.streams[0];
            const status = document.getElementById('ft-status');
            if (status) status.textContent = '';
        };
        pc.onicecandidate = (e) => {
            if (e.candidate) HD.post('facetimeSignal', { callId, kind: 'ice', payload: JSON.stringify(e.candidate) });
        };
    }

    function reset() {
        if (pc) { pc.close(); pc = null; }
        if (localStream) { localStream.getTracks().forEach((t) => t.stop()); localStream = null; }
        callId = null;
        if (overlay) { overlay.classList.add('hidden'); overlay.style.background = ''; overlay = null; }
    }
    function endCall() { if (callId) HD.post('endFacetime', { callId }); reset(); }

    HD.on('incomingFacetime', (call) => showIncoming(call));
    HD.on('facetimeRinging', (data) => { callId = data.callId; isCaller = true; });
    HD.on('facetimeEnded', () => reset());

    HD.on('facetimeAccepted', async () => {
        showCallScreen(null, true);
        await setupMedia();
        await setupPeerConnection();
        if (isCaller) {
            const offer = await pc.createOffer();
            await pc.setLocalDescription(offer);
            HD.post('facetimeSignal', { callId, kind: 'offer', payload: JSON.stringify(offer) });
        }
    });

    HD.on('facetimeSignal', async (kind, payload) => {
        if (!pc && kind === 'offer') {
            // Callee may not have set up media/PC yet if accept raced ahead of us.
            if (!localStream) await setupMedia();
            if (!pc) await setupPeerConnection();
        }
        if (!pc) return;
        if (kind === 'offer') {
            await pc.setRemoteDescription(new RTCSessionDescription(JSON.parse(payload)));
            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            HD.post('facetimeSignal', { callId, kind: 'answer', payload: JSON.stringify(answer) });
        } else if (kind === 'answer') {
            await pc.setRemoteDescription(new RTCSessionDescription(JSON.parse(payload)));
        } else if (kind === 'ice') {
            try { await pc.addIceCandidate(new RTCIceCandidate(JSON.parse(payload))); } catch (e) { /* candidate arrived before remote description — safe to drop */ }
        }
    });

    window.HDApps.facetime = {
        open(win) {
            win.innerHTML = `
                ${HD.backBar('FaceTime')}
                <div class="app-body">
                    <div class="field-group">
                        <input class="field" id="ft-number" placeholder="Phone number" style="background:var(--surface-2);" />
                    </div>
                    <button class="btn-primary" style="margin-top:16px;" id="ft-call">Call</button>
                </div>`;
            HD.bindBack(win);
            win.querySelector('#ft-call').onclick = () => {
                const to = win.querySelector('#ft-number').value.trim();
                if (!to) return;
                isCaller = true;
                HD.post('startFacetime', { to });
                HD.closeApp();
            };
        },
    };
})();
