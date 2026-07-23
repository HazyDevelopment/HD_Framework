(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_phone';

    // ═══════════════════════════ STATE ═══════════════════════════════
    let myNumber = null;
    let garagesCfg = [];
    let socialAppsCfg = {};
    let screen = 'home';
    let contacts = [];
    let currentConvNumber = null;
    let currentConvName = null;
    let activeCall = null; // { id, number, name, direction: 'incoming'|'outgoing', status: 'ringing'|'active', startTs }
    let callTimer = null;
    let currentFeedApp = null;
    let feeds = { wire: [], picta: [], loopz: [] };
    let vehicles = [];
    let installedApps = new Set();

    const $ = (id) => document.getElementById(id);
    const screenParent = {
        home: null, contacts: 'home', dialer: 'home', messages: 'home', conversation: 'messages',
        feed: 'home', garages: 'home', incall: null, appstore: 'home', airdrop: 'home',
        facetime: 'home', 'facetime-incall': null,
        bank: 'home', mail: 'home', marketplace: 'home', notes: 'home', crypto: 'home', gallery: 'home', settings: 'home',
    };

    function post(action, data) {
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function escapeHtml(str) {
        const d = document.createElement('div');
        d.textContent = str == null ? '' : String(str);
        return d.innerHTML;
    }

    function timeAgo(unixSeconds) {
        const diff = Math.max(0, Math.floor(Date.now() / 1000) - unixSeconds);
        if (diff < 60) return `${diff}s`;
        if (diff < 3600) return `${Math.floor(diff / 60)}m`;
        if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
        return `${Math.floor(diff / 86400)}d`;
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

    // Classic UK dual-ring cadence: 400ms ring / 200ms gap / 400ms ring / 2000ms silence, repeating.
    let ringtoneInterval = null;
    function playRingtone() {
        if (ringtoneInterval) return;
        const burst = (startAt) => {
            try {
                audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = 'sine';
                osc.frequency.value = 400;
                gain.gain.setValueAtTime(0.001, startAt);
                gain.gain.exponentialRampToValueAtTime(0.18, startAt + 0.02);
                gain.gain.setValueAtTime(0.18, startAt + 0.38);
                gain.gain.exponentialRampToValueAtTime(0.001, startAt + 0.4);
                osc.connect(gain).connect(audioCtx.destination);
                osc.start(startAt);
                osc.stop(startAt + 0.4);
            } catch (e) { /* audio unavailable, ignore */ }
        };
        const cycle = () => {
            if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            const now = audioCtx.currentTime;
            burst(now);
            burst(now + 0.6);
        };
        cycle();
        ringtoneInterval = setInterval(cycle, 3000);
    }
    function stopRingtone() {
        if (ringtoneInterval) { clearInterval(ringtoneInterval); ringtoneInterval = null; }
    }

    // ═══════════════════════════ SCREEN ROUTER ════════════════════════
    function showScreen(name, title) {
        document.querySelectorAll('.screen').forEach((el) => el.classList.add('hidden'));
        $(`screen-${name}`).classList.remove('hidden');
        screen = name;
        $('screenTitle').textContent = title || '';
        $('navbar').classList.toggle('hidden', name === 'home');
        $('backBtn').classList.toggle('hidden', screenParent[name] === undefined ? false : screenParent[name] === null);
    }

    function goBack() {
        const parent = screenParent[screen];
        if (parent === null || parent === undefined) return;
        if (parent === 'home') openHome();
        else if (parent === 'messages') openMessages();
    }

    function openHome() { showScreen('home', ''); }
    $('homeBtn').addEventListener('click', openHome);
    $('backBtn').addEventListener('click', goBack);

    // ═══════════════════════════ APP GRID (data-driven) ═══════════════
    // Single source of truth for the home screen — add an app by adding
    // an entry here, nothing else needs touching structurally. `open`
    // references are resolved lazily inside the click handler (not
    // captured at array-construction time) so declaration order in this
    // file doesn't matter. `core: true` apps are always on the home
    // screen and can't be uninstalled (mirrors iOS system apps); every
    // other app only shows once installedApps has its id, via the App
    // Store — see openAppStore() below.
    const APPS = [
        { id: 'phone', label: 'Phone', color: '#2E7D4F', glyph: '☎', core: true, dock: true },
        { id: 'messages', label: 'Messages', color: '#3E7CB1', glyph: '✉', core: true, dock: true },
        { id: 'contacts', label: 'Contacts', color: '#6D7480', glyph: '☰', core: true, dock: true },
        { id: 'appstore', label: 'App Store', color: '#0FA8E0', glyph: '⬇', core: true },
        { id: 'airdrop', label: 'AirDrop', color: '#1B8CD1', glyph: '⤢' },
        { id: 'facetime', label: 'FaceTime', color: '#2ECC71', glyph: '🎥' },
        { id: 'wire', label: 'Wire', color: '#1B8CD1', glyph: 'W' },
        { id: 'picta', label: 'Picta', color: '#C0388D', glyph: 'P' },
        { id: 'loopz', label: 'Loopz', color: '#B03A3A', glyph: 'L' },
        { id: 'garages', label: 'Garages', color: '#D8892B', glyph: 'G' },
        { id: 'bank', label: 'Bank', color: '#2E8B57', glyph: '£' },
        { id: 'mail', label: 'Mail', color: '#5B6EE1', glyph: '@' },
        { id: 'marketplace', label: 'Market', color: '#CC8A1E', glyph: '$' },
        { id: 'notes', label: 'Notes', color: '#B8A13E', glyph: '✎' },
        { id: 'crypto', label: 'Crypto', color: '#7A4FD1', glyph: '◈' },
        { id: 'gallery', label: 'Gallery', color: '#3E9C9C', glyph: '▦' },
        { id: 'settings', label: 'Settings', color: '#5A5F66', glyph: '⚙', core: true, dock: true },
    ];

    function openApp(id) {
        if (id === 'phone') openDialer();
        else if (id === 'messages') openMessages();
        else if (id === 'contacts') openContacts();
        else if (id === 'appstore') openAppStore();
        else if (id === 'airdrop') showScreen('airdrop', 'AirDrop');
        else if (id === 'facetime') openFacetime();
        else if (id === 'garages') openGarages();
        else if (id === 'bank') openBank();
        else if (id === 'mail') openMail();
        else if (id === 'marketplace') openMarketplace();
        else if (id === 'notes') openNotes();
        else if (id === 'crypto') openCrypto();
        else if (id === 'gallery') openGallery();
        else if (id === 'settings') openSettings();
        else if (id === 'wire' || id === 'picta' || id === 'loopz') openFeed(id);
    }

    function makeAppIcon(app) {
        const btn = document.createElement('button');
        btn.className = 'app-icon';
        btn.innerHTML = `<span class="icon-tile" style="--c:${app.color}">${app.glyph}</span><span class="icon-label">${app.label}</span>`;
        btn.addEventListener('click', () => openApp(app.id));
        return btn;
    }

    function renderAppGrid() {
        const grid = $('appGrid');
        grid.innerHTML = '';
        APPS.filter((app) => app.core || installedApps.has(app.id)).forEach((app) => grid.appendChild(makeAppIcon(app)));

        const dock = $('dock');
        dock.innerHTML = '';
        APPS.filter((app) => app.dock).forEach((app) => dock.appendChild(makeAppIcon(app)));
    }
    renderAppGrid(); // built once here (dock/core apps need nothing from the server), re-run once installedApps arrives

    // ═══════════════════════════ APP STORE ═════════════════════════════
    function openAppStore() {
        showScreen('appstore', 'App Store');
        renderAppStore();
    }

    function renderAppStore() {
        const list = $('appstoreList');
        list.innerHTML = '';
        const downloadable = APPS.filter((app) => !app.core);
        if (!downloadable.length) { list.innerHTML = '<div class="empty-state">No apps available.</div>'; return; }
        downloadable.forEach((app) => {
            const installed = installedApps.has(app.id);
            const row = document.createElement('div');
            row.className = 'row-card no-hover';
            row.innerHTML = `
                <div class="row-main" style="flex-direction:row; align-items:center; gap:10px;">
                    <span class="icon-tile" style="--c:${app.color}; width:38px; height:38px; font-size:15px; border-radius:11px;">${app.glyph}</span>
                    <span class="row-title">${app.label}</span>
                </div>
                <div class="row-actions">
                    <button class="store-btn ${installed ? 'installed' : ''}" data-id="${app.id}">${installed ? 'Remove' : 'Get'}</button>
                </div>`;
            row.querySelector('.store-btn').addEventListener('click', () => {
                post(installed ? 'uninstallApp' : 'installApp', { id: app.id });
            });
            list.appendChild(row);
        });
    }

    // ═══════════════════════════ AIRDROP ════════════════════════════════
    $('airdropShareBtn').addEventListener('click', () => post('airdropShare'));

    function showAirdropPrompt(data) {
        $('airdropFrom').textContent = `${data.name} wants to share their contact`;
        $('airdropPrompt').classList.remove('hidden');

        const cleanup = () => $('airdropPrompt').classList.add('hidden');
        $('airdropAccept').onclick = () => { post('saveContact', { name: data.name, number: data.number }); cleanup(); };
        $('airdropDecline').onclick = cleanup;
    }

    // ═══════════════════════════ CLOCK ════════════════════════════════
    setInterval(() => {
        const d = new Date();
        $('clock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }, 1000);

    // ═══════════════════════════ CONTACTS ═════════════════════════════
    let contactFormOpen = false;
    function openContacts() {
        contactFormOpen = false;
        showScreen('contacts', 'Contacts');
        post('getContacts');
    }

    function renderContacts() {
        const list = $('contactsList');
        list.innerHTML = '';
        if (!contacts.length) {
            list.innerHTML = '<div class="empty-state">No contacts saved.</div>';
        }
        contacts.forEach((c) => {
            const row = document.createElement('div');
            row.className = 'row-card';
            row.innerHTML = `
                <div class="row-main">
                    <span class="row-title">${escapeHtml(c.name)}</span>
                    <span class="row-sub">${escapeHtml(c.number)}</span>
                </div>
                <div class="row-actions">
                    <button data-act="call" title="Call">☎</button>
                    <button data-act="msg" title="Message">✉</button>
                    <button data-act="del" title="Delete">✕</button>
                </div>`;
            row.querySelector('[data-act="call"]').addEventListener('click', () => startCall(c.number));
            row.querySelector('[data-act="msg"]').addEventListener('click', () => openConversation(c.number, c.name));
            row.querySelector('[data-act="del"]').addEventListener('click', () => post('deleteContact', { id: c.id }));
            list.appendChild(row);
        });
    }

    $('addContactBtn').addEventListener('click', () => {
        if (contactFormOpen) return;
        contactFormOpen = true;
        const form = document.createElement('div');
        form.className = 'inline-form';
        form.innerHTML = `
            <input type="text" class="field-input" id="newContactName" placeholder="Name" maxlength="60">
            <input type="text" class="field-input" id="newContactNumber" placeholder="Number" maxlength="15">
            <div class="form-actions">
                <button class="wide-btn" id="newContactCancel">Cancel</button>
                <button class="wide-btn call-btn" id="newContactSave">Save</button>
            </div>`;
        $('contactsList').prepend(form);
        $('newContactCancel').addEventListener('click', () => { contactFormOpen = false; renderContacts(); });
        $('newContactSave').addEventListener('click', () => {
            const name = $('newContactName').value.trim();
            const number = $('newContactNumber').value.trim();
            if (!name || !number) return;
            post('saveContact', { name, number });
            contactFormOpen = false;
        });
    });

    // ═══════════════════════════ DIALER ═══════════════════════════════
    let dialpadBuilt = false;
    function openDialer() {
        showScreen('dialer', 'Phone');
        if (!dialpadBuilt) {
            dialpadBuilt = true;
            const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
            const pad = $('dialpad');
            keys.forEach((k) => {
                const b = document.createElement('button');
                b.textContent = k;
                b.addEventListener('click', () => { $('dialInput').value += k; });
                pad.appendChild(b);
            });
        }
    }
    $('dialCallBtn').addEventListener('click', () => {
        const number = $('dialInput').value.trim();
        if (!number) return;
        startCall(number);
        $('dialInput').value = '';
    });

    // ═══════════════════════════ CALLS ════════════════════════════════
    function startCall(number) {
        activeCall = { id: null, number, name: number, direction: 'outgoing', status: 'ringing' };
        showScreen('incall', 'Call');
        renderIncall();
        post('startCall', { number });
    }

    function renderIncall() {
        if (!activeCall) return;
        $('incallName').textContent = activeCall.name || activeCall.number;
        $('backBtn').classList.add('hidden');
        const actions = $('incallActions');
        actions.innerHTML = '';

        if (activeCall.status === 'ringing' && activeCall.direction === 'incoming') {
            $('incallStatus').textContent = 'Incoming call...';
            actions.innerHTML = `<button class="btn-answer" id="btnAnswer">☎</button><button class="btn-decline" id="btnDecline">✕</button>`;
            $('btnAnswer').addEventListener('click', () => post('answerCall', { id: activeCall.id }));
            $('btnDecline').addEventListener('click', () => post('declineCall', { id: activeCall.id }));
        } else if (activeCall.status === 'ringing') {
            $('incallStatus').textContent = 'Ringing...';
            actions.innerHTML = `<button class="btn-hangup" id="btnHangup">✕</button>`;
            $('btnHangup').addEventListener('click', () => post('endCall', { id: activeCall.id }));
        } else if (activeCall.status === 'active') {
            actions.innerHTML = `<button class="btn-hangup" id="btnHangup">✕</button>`;
            $('btnHangup').addEventListener('click', () => post('endCall', { id: activeCall.id }));
        }
    }

    function endCallUI(message) {
        stopRingtone();
        if (callTimer) { clearInterval(callTimer); callTimer = null; }
        activeCall = null;
        if (message) $('incallStatus').textContent = message;
        setTimeout(() => { if (screen === 'incall') openHome(); }, 1200);
    }

    // ═══════════════════════════ FACETIME ══════════════════════════════
    // Real two-way video/audio over WebRTC. The server (server/facetime.lua)
    // only ever relays SDP offers/answers and ICE candidates between the
    // two RTCPeerConnections below — media itself is peer-to-peer, never
    // touches FXServer. A public STUN server handles NAT traversal; there's
    // no TURN fallback, so a call between two very restrictive NATs (rare
    // for two players on the same game server, but possible) may fail to
    // connect even though signaling succeeds.
    const FT_ICE_SERVERS = [{ urls: 'stun:stun.l.google.com:19302' }];
    let activeFacetime = null; // { id, number, name, direction, status }
    let ftPeerConnection = null;
    let ftLocalStream = null;
    let ftIsOfferer = false;
    let ftPendingIce = [];
    let ftTimer = null;

    function openFacetime() {
        showScreen('facetime', 'FaceTime');
    }
    $('ftCallBtn').addEventListener('click', () => {
        const number = $('ftDialInput').value.trim();
        if (!number) return;
        startFacetime(number);
        $('ftDialInput').value = '';
    });

    function startFacetime(number) {
        activeFacetime = { id: null, number, name: number, direction: 'outgoing', status: 'ringing' };
        showScreen('facetime-incall', 'FaceTime');
        renderFacetime();
        post('facetimeStart', { number });
    }

    function renderFacetime() {
        if (!activeFacetime) return;
        $('ftName').textContent = activeFacetime.name || activeFacetime.number;
        $('backBtn').classList.add('hidden');
        const actions = $('ftActions');
        actions.innerHTML = '';

        if (activeFacetime.status === 'ringing' && activeFacetime.direction === 'incoming') {
            $('ftStatus').textContent = 'Incoming FaceTime...';
            actions.innerHTML = `<button class="btn-answer" id="ftAnswer">☎</button><button class="btn-decline" id="ftDecline">✕</button>`;
            $('ftAnswer').addEventListener('click', () => post('facetimeAnswer', { id: activeFacetime.id }));
            $('ftDecline').addEventListener('click', () => post('facetimeDecline', { id: activeFacetime.id }));
        } else if (activeFacetime.status === 'ringing') {
            $('ftStatus').textContent = 'Calling...';
            actions.innerHTML = `<button class="btn-hangup" id="ftHangup">✕</button>`;
            $('ftHangup').addEventListener('click', () => post('facetimeEnd', { id: activeFacetime.id }));
        } else if (activeFacetime.status === 'active') {
            actions.innerHTML = `<button class="btn-hangup" id="ftHangup">✕</button>`;
            $('ftHangup').addEventListener('click', () => post('facetimeEnd', { id: activeFacetime.id }));
        }
    }

    async function ftSetupLocalMedia() {
        if (ftLocalStream) return true;
        try {
            ftLocalStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
            $('ftLocalVideo').srcObject = ftLocalStream;
            return true;
        } catch (e) {
            $('ftStatus').textContent = 'Camera/mic unavailable — check FiveM has permission.';
            return false;
        }
    }

    function ftCreatePeerConnection() {
        const pc = new RTCPeerConnection({ iceServers: FT_ICE_SERVERS });
        ftLocalStream.getTracks().forEach((track) => pc.addTrack(track, ftLocalStream));
        pc.ontrack = (e) => { $('ftRemoteVideo').srcObject = e.streams[0]; };
        pc.onicecandidate = (e) => {
            if (e.candidate && activeFacetime) post('facetimeSignal', { id: activeFacetime.id, signal: { type: 'ice', candidate: e.candidate } });
        };
        return pc;
    }

    // Both sides receive 'facetimeAnswered' independently and each calls
    // ftBeginNegotiation() on its own — the offer can arrive over the wire
    // before a side's own setup finishes. Sharing one promise means
    // whichever path (own negotiation vs. an incoming offer) gets there
    // first does the actual setup, and the other just awaits the same
    // result instead of racing to create a second peer connection.
    let ftNegotiationPromise = null;
    function ftEnsurePeerConnection() {
        if (!ftNegotiationPromise) {
            ftNegotiationPromise = (async () => {
                const ok = await ftSetupLocalMedia();
                if (!ok) { ftNegotiationPromise = null; return false; }
                ftPeerConnection = ftCreatePeerConnection();
                return true;
            })();
        }
        return ftNegotiationPromise;
    }

    async function ftBeginNegotiation() {
        const ok = await ftEnsurePeerConnection();
        if (!ok) return;
        if (ftIsOfferer) {
            const offer = await ftPeerConnection.createOffer();
            await ftPeerConnection.setLocalDescription(offer);
            post('facetimeSignal', { id: activeFacetime.id, signal: { type: 'offer', sdp: offer } });
        }
    }

    async function ftHandleSignal(signal) {
        if (!signal) return;
        if (signal.type === 'offer') {
            const ok = await ftEnsurePeerConnection();
            if (!ok) return;
            await ftPeerConnection.setRemoteDescription(new RTCSessionDescription(signal.sdp));
            ftPendingIce.splice(0).forEach((c) => ftPeerConnection.addIceCandidate(c).catch(() => {}));
            const answer = await ftPeerConnection.createAnswer();
            await ftPeerConnection.setLocalDescription(answer);
            post('facetimeSignal', { id: activeFacetime.id, signal: { type: 'answer', sdp: answer } });
        } else if (signal.type === 'answer') {
            if (ftPeerConnection) await ftPeerConnection.setRemoteDescription(new RTCSessionDescription(signal.sdp));
        } else if (signal.type === 'ice') {
            if (ftPeerConnection && ftPeerConnection.remoteDescription) {
                ftPeerConnection.addIceCandidate(signal.candidate).catch(() => {});
            } else {
                ftPendingIce.push(signal.candidate);
            }
        }
    }

    function ftCleanup() {
        if (ftPeerConnection) { ftPeerConnection.close(); ftPeerConnection = null; }
        if (ftLocalStream) { ftLocalStream.getTracks().forEach((t) => t.stop()); ftLocalStream = null; }
        $('ftLocalVideo').srcObject = null;
        $('ftRemoteVideo').srcObject = null;
        ftIsOfferer = false;
        ftPendingIce = [];
        ftNegotiationPromise = null;
        if (ftTimer) { clearInterval(ftTimer); ftTimer = null; }
    }

    function endFacetimeUI(message) {
        stopRingtone();
        ftCleanup();
        activeFacetime = null;
        if (message) $('ftStatus').textContent = message;
        setTimeout(() => { if (screen === 'facetime-incall') openHome(); }, 1200);
    }

    // ═══════════════════════════ MESSAGES ═════════════════════════════
    let messageFormOpen = false;
    function openMessages() {
        messageFormOpen = false;
        showScreen('messages', 'Messages');
        post('getThreads');
    }

    function renderThreads(rows) {
        const list = $('threadsList');
        list.innerHTML = '';
        if (!rows.length) {
            list.innerHTML = '<div class="empty-state">No messages yet.</div>';
        }
        rows.forEach((t) => {
            const row = document.createElement('div');
            row.className = 'row-card';
            row.innerHTML = `
                <div class="row-main">
                    <span class="row-title">${escapeHtml(t.name || t.number)}</span>
                    <span class="row-sub">${t.fromMe ? 'You: ' : ''}${escapeHtml(t.lastMessage)}</span>
                </div>
                ${t.unread ? `<span class="unread-badge">${t.unread}</span>` : ''}`;
            row.addEventListener('click', () => openConversation(t.number, t.name));
            list.appendChild(row);
        });
    }

    $('newMessageBtn').addEventListener('click', () => {
        if (messageFormOpen) return;
        messageFormOpen = true;
        const form = document.createElement('div');
        form.className = 'inline-form';
        form.innerHTML = `
            <input type="text" class="field-input" id="newMsgNumber" placeholder="Number" maxlength="15">
            <div class="form-actions">
                <button class="wide-btn" id="newMsgCancel">Cancel</button>
                <button class="wide-btn call-btn" id="newMsgGo">Next</button>
            </div>`;
        $('threadsList').prepend(form);
        $('newMsgCancel').addEventListener('click', () => { messageFormOpen = false; renderThreads([]); post('getThreads'); });
        $('newMsgGo').addEventListener('click', () => {
            const number = $('newMsgNumber').value.trim();
            if (!number) return;
            messageFormOpen = false;
            openConversation(number, null);
        });
    });

    function openConversation(number, name) {
        currentConvNumber = number;
        currentConvName = name;
        showScreen('conversation', name || number);
        $('conversationThread').innerHTML = '';
        post('getConversation', { number });
    }

    function renderConversation(number, rows) {
        if (number !== currentConvNumber) return;
        const thread = $('conversationThread');
        thread.innerHTML = '';
        rows.forEach((m) => appendBubble(m, false));
        thread.scrollTop = thread.scrollHeight;
    }

    function appendBubble(m, scroll) {
        const thread = $('conversationThread');
        const bubble = document.createElement('div');
        bubble.className = 'msg-bubble ' + (m.sender === myNumber ? 'msg-mine' : 'msg-theirs');
        bubble.textContent = m.message;
        thread.appendChild(bubble);
        if (scroll) thread.scrollTop = thread.scrollHeight;
    }

    function sendCurrentMessage() {
        const input = $('messageInput');
        const value = input.value.trim();
        if (!value || !currentConvNumber) return;
        post('sendMessage', { to: currentConvNumber, message: value });
        input.value = '';
    }
    $('sendMessageBtn').addEventListener('click', sendCurrentMessage);
    $('messageInput').addEventListener('keyup', (e) => { if (e.key === 'Enter') sendCurrentMessage(); });

    // ═══════════════════════════ SOCIAL FEEDS ═════════════════════════
    function openFeed(app) {
        currentFeedApp = app;
        const cfg = socialAppsCfg[app] || { label: app, allowImage: false, maxLength: 280 };
        showScreen('feed', cfg.label);
        $('postContent').setAttribute('maxlength', cfg.maxLength || 280);
        $('postContent').placeholder = `Post to ${cfg.label}...`;
        $('postImage').classList.toggle('hidden', !cfg.allowImage);
        $('postContent').value = '';
        $('postImage').value = '';
        $('feedList').innerHTML = '';
        post('getFeed', { app });
    }

    function renderFeed(app, posts) {
        if (app !== currentFeedApp) return;
        feeds[app] = posts;
        drawFeed();
    }

    function drawFeed() {
        const list = $('feedList');
        list.innerHTML = '';
        const posts = feeds[currentFeedApp] || [];
        if (!posts.length) {
            list.innerHTML = '<div class="empty-state">Nothing posted yet.</div>';
            return;
        }
        posts.forEach((p) => {
            const card = document.createElement('div');
            card.className = 'post-card';
            card.innerHTML = `
                <div class="post-author">${escapeHtml(p.author_name)}</div>
                ${p.content ? `<div class="post-content">${escapeHtml(p.content)}</div>` : ''}
                ${p.image_url ? `<img class="post-image" src="${escapeHtml(p.image_url)}">` : ''}
                <div class="post-meta">
                    <span>${timeAgo(typeof p.created === 'number' ? p.created : Math.floor(Date.now() / 1000))}</span>
                    <span>
                        <button class="post-like ${p.liked ? 'liked' : ''}" data-id="${p.id}">♥ ${p.likeCount || 0}</button>
                        ${p.mine ? `<button class="post-delete" data-id="${p.id}">Delete</button>` : ''}
                    </span>
                </div>`;
            card.querySelector('.post-like').addEventListener('click', () => post('likePost', { id: p.id }));
            const del = card.querySelector('.post-delete');
            if (del) del.addEventListener('click', () => post('deletePost', { id: p.id }));
            list.appendChild(card);
        });
    }

    $('postSubmitBtn').addEventListener('click', () => {
        const content = $('postContent').value.trim();
        const imageUrl = $('postImage').classList.contains('hidden') ? '' : $('postImage').value.trim();
        if (!content && !imageUrl) return;
        post('createPost', { app: currentFeedApp, content, imageUrl });
        $('postContent').value = '';
        $('postImage').value = '';
    });

    // ═══════════════════════════ GARAGES ══════════════════════════════
    function openGarages() {
        showScreen('garages', 'Garages');
        post('getVehicles');
    }

    function renderVehicles(rows) {
        vehicles = rows;
        const list = $('garagesList');
        list.innerHTML = '';
        if (!rows.length) {
            list.innerHTML = '<div class="empty-state">No vehicles registered to you.</div>';
            return;
        }
        rows.forEach((v) => {
            const card = document.createElement('div');
            card.className = 'vehicle-card';
            const stored = v.state === 1;
            card.innerHTML = `
                <div class="vehicle-top">
                    <span class="vehicle-plate">${escapeHtml(v.plate)}</span>
                    <span class="vehicle-state">${stored ? `Stored — ${escapeHtml(garageLabel(v.garage))}` : 'Out'}</span>
                </div>
                <div class="row-sub">${escapeHtml(v.vehicle)}</div>
                <div class="vehicle-actions">
                    ${stored
                    ? `<button data-act="retrieve">Retrieve</button>`
                    : `<select class="field-input" id="garageSelect-${v.plate}">${garagesCfg.map((g) => `<option value="${g.key}">${escapeHtml(g.label)}</option>`).join('')}</select> <button data-act="store">Store</button>`}
                </div>`;
            const btn = card.querySelector('button[data-act]');
            if (btn.dataset.act === 'retrieve') {
                btn.addEventListener('click', () => post('retrieveVehicle', { plate: v.plate, garageKey: v.garage }));
            } else {
                btn.addEventListener('click', () => {
                    const sel = $(`garageSelect-${v.plate}`);
                    post('storeVehicle', { plate: v.plate, garageKey: sel.value });
                });
            }
            list.appendChild(card);
        });
    }

    function garageLabel(key) {
        const g = garagesCfg.find((x) => x.key === key);
        return g ? g.label : (key || 'Unknown');
    }

    function money(n) { return `£${Number(n || 0).toLocaleString()}`; }

    // ═══════════════════════════ BANK ═══════════════════════════════════
    let bankFormOpen = false;
    function openBank() {
        bankFormOpen = false;
        showScreen('bank', 'Bank');
        post('getBankAccount');
        post('getBankLog');
    }

    function renderBankAccount(account) {
        $('bankCash').textContent = money(account.cash);
        $('bankBalance').textContent = money(account.bank);
    }

    function renderBankLog(rows) {
        const list = $('bankLogList');
        list.innerHTML = '';
        if (!rows.length) {
            list.innerHTML = '<div class="empty-state">No activity yet.</div>';
            return;
        }
        const labels = { deposit: 'Deposit', withdraw: 'Withdraw', transfer_out: 'Sent', transfer_in: 'Received' };
        rows.forEach((r) => {
            const row = document.createElement('div');
            row.className = 'row-card no-hover';
            row.innerHTML = `
                <div class="row-main">
                    <span class="row-title">${labels[r.type] || r.type}${r.other_party ? ` — ${escapeHtml(r.other_party)}` : ''}</span>
                    <span class="row-sub">${timeAgo(Math.floor(new Date(r.created).getTime() / 1000) || Math.floor(Date.now() / 1000))} ago</span>
                </div>
                <span class="${r.type === 'deposit' || r.type === 'transfer_in' ? 'amount-in' : 'amount-out'}">
                    ${r.type === 'deposit' || r.type === 'transfer_in' ? '+' : '-'}${money(r.amount)}
                </span>`;
            list.appendChild(row);
        });
    }

    function bankPrompt(title, onConfirm, withNumber) {
        if (bankFormOpen) return;
        bankFormOpen = true;
        const form = document.createElement('div');
        form.className = 'inline-form';
        form.innerHTML = `
            ${withNumber ? '<input type="text" class="field-input" id="bankToNumber" placeholder="Recipient number" maxlength="15">' : ''}
            <input type="text" class="field-input" id="bankAmountInput" placeholder="Amount" inputmode="numeric">
            <div class="form-actions">
                <button class="wide-btn" id="bankFormCancel">Cancel</button>
                <button class="wide-btn call-btn" id="bankFormGo">${title}</button>
            </div>`;
        $('bankLogList').prepend(form);
        $('bankFormCancel').addEventListener('click', () => { bankFormOpen = false; renderBankLog([]); post('getBankLog'); });
        $('bankFormGo').addEventListener('click', () => {
            const amount = parseInt($('bankAmountInput').value, 10);
            if (!amount || amount <= 0) return;
            const toNumber = withNumber ? $('bankToNumber').value.trim() : null;
            bankFormOpen = false;
            onConfirm(amount, toNumber);
        });
    }

    $('bankDepositBtn').addEventListener('click', () => bankPrompt('Deposit', (amount) => post('bankDeposit', { amount })));
    $('bankWithdrawBtn').addEventListener('click', () => bankPrompt('Withdraw', (amount) => post('bankWithdraw', { amount })));
    $('bankTransferBtn').addEventListener('click', () => bankPrompt('Send', (amount, toNumber) => {
        if (!toNumber) return;
        post('bankTransfer', { amount, toNumber });
    }, true));

    // ═══════════════════════════ MAIL ═════════════════════════════════
    let mailItems = [];
    function openMail() {
        showScreen('mail', 'Mail');
        post('getMail');
    }

    function renderMail(rows) {
        mailItems = rows;
        drawMail();
    }

    function drawMail() {
        const list = $('mailList');
        list.innerHTML = '';
        if (!mailItems.length) {
            list.innerHTML = '<div class="empty-state">No mail.</div>';
            return;
        }
        mailItems.forEach((m) => {
            const card = document.createElement('div');
            card.className = 'mail-card' + (m.is_read ? '' : ' mail-unread');
            card.innerHTML = `
                <div class="mail-top">
                    <span class="row-title">${escapeHtml(m.subject)}</span>
                    <button class="post-delete" data-act="del">✕</button>
                </div>
                <div class="row-sub">${escapeHtml(m.sender_label)}</div>
                <div class="mail-body hidden">${escapeHtml(m.body)}</div>`;
            card.addEventListener('click', (e) => {
                if (e.target.dataset.act === 'del') return;
                card.querySelector('.mail-body').classList.toggle('hidden');
                if (!m.is_read) { m.is_read = 1; card.classList.remove('mail-unread'); post('readMail', { id: m.id }); }
            });
            card.querySelector('[data-act="del"]').addEventListener('click', (e) => {
                e.stopPropagation();
                post('deleteMail', { id: m.id });
            });
            list.appendChild(card);
        });
    }

    // ═══════════════════════════ MARKETPLACE ══════════════════════════
    let listings = [];
    let listingFormOpen = false;
    function openMarketplace() {
        listingFormOpen = false;
        showScreen('marketplace', 'Marketplace');
        post('getMarketplace');
    }

    function renderMarketplace(rows) {
        listings = rows;
        drawMarketplace();
    }

    function drawMarketplace() {
        const list = $('marketplaceList');
        list.innerHTML = '';
        if (!listings.length) {
            list.innerHTML = '<div class="empty-state">No listings yet.</div>';
            return;
        }
        listings.forEach((l) => {
            const card = document.createElement('div');
            card.className = 'post-card';
            card.innerHTML = `
                <div class="post-author">${escapeHtml(l.title)} — <span class="amount-in">${money(l.price)}</span></div>
                ${l.description ? `<div class="post-content">${escapeHtml(l.description)}</div>` : ''}
                ${l.image_url ? `<img class="post-image" src="${escapeHtml(l.image_url)}">` : ''}
                <div class="post-meta">
                    <span>${escapeHtml(l.seller_name)}</span>
                    <span>
                        ${l.mine ? `<button class="post-delete" data-act="del">Delete</button>` : `<button class="post-like" data-act="msg">Message Seller</button>`}
                    </span>
                </div>`;
            const delBtn = card.querySelector('[data-act="del"]');
            if (delBtn) delBtn.addEventListener('click', () => post('deleteListing', { id: l.id }));
            const msgBtn = card.querySelector('[data-act="msg"]');
            if (msgBtn) msgBtn.addEventListener('click', () => openConversation(l.seller_number, l.seller_name));
            list.appendChild(card);
        });
    }

    $('newListingBtn').addEventListener('click', () => {
        if (listingFormOpen) return;
        listingFormOpen = true;
        const form = document.createElement('div');
        form.className = 'inline-form';
        form.innerHTML = `
            <input type="text" class="field-input" id="listingTitle" placeholder="Title" maxlength="80">
            <input type="text" class="field-input" id="listingPrice" placeholder="Price" inputmode="numeric">
            <input type="text" class="field-input" id="listingDesc" placeholder="Description (optional)">
            <input type="text" class="field-input" id="listingImage" placeholder="Image URL (optional)">
            <div class="form-actions">
                <button class="wide-btn" id="listingCancel">Cancel</button>
                <button class="wide-btn call-btn" id="listingSave">Post</button>
            </div>`;
        $('marketplaceList').prepend(form);
        $('listingCancel').addEventListener('click', () => { listingFormOpen = false; drawMarketplace(); });
        $('listingSave').addEventListener('click', () => {
            const title = $('listingTitle').value.trim();
            const price = parseInt($('listingPrice').value, 10);
            if (!title || !price) return;
            post('createListing', {
                title, price,
                description: $('listingDesc').value.trim(),
                imageUrl: $('listingImage').value.trim(),
            });
            listingFormOpen = false;
        });
    });

    // ═══════════════════════════ NOTES ═════════════════════════════════
    let notes = [];
    function openNotes() {
        showScreen('notes', 'Notes');
        post('getNotes');
    }

    function renderNotes(rows) {
        notes = rows;
        drawNotes();
    }

    function drawNotes() {
        const list = $('notesList');
        list.innerHTML = '';
        if (!notes.length) {
            list.innerHTML = '<div class="empty-state">No notes saved.</div>';
            return;
        }
        notes.forEach((n) => {
            const card = document.createElement('div');
            card.className = 'row-card note-card';
            card.innerHTML = `
                <div class="row-main"><span class="row-sub note-text">${escapeHtml(n.content)}</span></div>
                <div class="row-actions"><button data-act="edit">✎</button><button data-act="del">✕</button></div>`;
            card.querySelector('[data-act="del"]').addEventListener('click', (e) => {
                e.stopPropagation();
                post('deleteNote', { id: n.id });
            });
            card.querySelector('[data-act="edit"]').addEventListener('click', (e) => {
                e.stopPropagation();
                const form = document.createElement('div');
                form.className = 'inline-form';
                form.innerHTML = `
                    <textarea class="field-input note-textarea" id="editNoteContent" maxlength="2000">${escapeHtml(n.content)}</textarea>
                    <div class="form-actions">
                        <button class="wide-btn" id="editNoteCancel">Cancel</button>
                        <button class="wide-btn call-btn" id="editNoteSave">Save</button>
                    </div>`;
                card.replaceWith(form);
                $('editNoteCancel').addEventListener('click', drawNotes);
                $('editNoteSave').addEventListener('click', () => {
                    const content = $('editNoteContent').value.trim();
                    if (!content) return;
                    post('saveNote', { id: n.id, content });
                });
            });
            list.appendChild(card);
        });
    }

    $('newNoteBtn').addEventListener('click', () => {
        const form = document.createElement('div');
        form.className = 'inline-form';
        form.innerHTML = `
            <textarea class="field-input note-textarea" id="newNoteContent" placeholder="Write a note..." maxlength="2000"></textarea>
            <div class="form-actions">
                <button class="wide-btn" id="newNoteCancel">Cancel</button>
                <button class="wide-btn call-btn" id="newNoteSave">Save</button>
            </div>`;
        $('notesList').prepend(form);
        $('newNoteCancel').addEventListener('click', drawNotes);
        $('newNoteSave').addEventListener('click', () => {
            const content = $('newNoteContent').value.trim();
            if (!content) return;
            post('saveNote', { content });
        });
    });

    // ═══════════════════════════ CRYPTO ═════════════════════════════════
    let cryptoData = null;
    let cryptoPollTimer = null;
    function openCrypto() {
        showScreen('crypto', 'Crypto');
        post('getCrypto');
        if (cryptoPollTimer) clearInterval(cryptoPollTimer);
        cryptoPollTimer = setInterval(() => { if (screen === 'crypto') post('getCrypto'); }, 10000);
    }

    function renderCrypto(data) {
        cryptoData = data;
        $('cryptoName').textContent = `${data.coinName} (${data.ticker})`;
        $('cryptoPrice').textContent = `£${Number(data.price).toFixed(2)}`;
        $('cryptoHoldings').textContent = `You hold ${Number(data.holdings).toFixed(4)} ${data.ticker}`;
        drawSparkline(data.history || []);
    }

    function drawSparkline(history) {
        const svg = $('cryptoSpark');
        if (!history.length) { svg.innerHTML = ''; return; }
        const min = Math.min(...history), max = Math.max(...history);
        const range = (max - min) || 1;
        const step = 280 / Math.max(1, history.length - 1);
        const points = history.map((p, i) => `${(i * step).toFixed(1)},${(60 - ((p - min) / range) * 56 - 2).toFixed(1)}`).join(' ');
        const rising = history[history.length - 1] >= history[0];
        svg.innerHTML = `<polyline points="${points}" fill="none" stroke="${rising ? '#2E8B57' : '#C4453A'}" stroke-width="2"/>`;
    }

    $('cryptoBuyBtn').addEventListener('click', () => {
        const amount = parseFloat($('cryptoAmount').value);
        if (!amount || amount <= 0) return;
        post('cryptoBuy', { amount });
        $('cryptoAmount').value = '';
    });
    $('cryptoSellBtn').addEventListener('click', () => {
        const amount = parseFloat($('cryptoAmount').value);
        if (!amount || amount <= 0) return;
        post('cryptoSell', { amount });
        $('cryptoAmount').value = '';
    });

    // ═══════════════════════════ GALLERY ═════════════════════════════════
    function openGallery() {
        showScreen('gallery', 'Gallery');
        post('getGallery');
    }

    function renderGallery(rows) {
        const grid = $('galleryGrid');
        grid.innerHTML = '';
        if (!rows.length) {
            grid.innerHTML = '<div class="empty-state">Nothing saved yet.</div>';
            return;
        }
        rows.forEach((g) => {
            const tile = document.createElement('div');
            tile.className = 'gallery-tile';
            tile.innerHTML = `<img src="${escapeHtml(g.image_url)}"><button class="gallery-del" data-id="${g.id}">✕</button>${g.caption ? `<span class="gallery-caption">${escapeHtml(g.caption)}</span>` : ''}`;
            tile.querySelector('.gallery-del').addEventListener('click', () => post('deleteGalleryItem', { id: g.id }));
            grid.appendChild(tile);
        });
    }

    let galleryFormOpen = false;
    $('newGalleryBtn').addEventListener('click', () => {
        if (galleryFormOpen) return;
        galleryFormOpen = true;
        const form = document.createElement('div');
        form.className = 'inline-form gallery-form';
        form.innerHTML = `
            <input type="text" class="field-input" id="galleryUrl" placeholder="Image URL" maxlength="255">
            <input type="text" class="field-input" id="galleryCaption" placeholder="Caption (optional)" maxlength="150">
            <div class="form-actions">
                <button class="wide-btn" id="galleryCancel">Cancel</button>
                <button class="wide-btn call-btn" id="gallerySave">Save</button>
            </div>`;
        $('galleryGrid').prepend(form);
        $('galleryCancel').addEventListener('click', () => { galleryFormOpen = false; form.remove(); });
        $('gallerySave').addEventListener('click', () => {
            const url = $('galleryUrl').value.trim();
            if (!url) return;
            post('saveToGallery', { imageUrl: url, caption: $('galleryCaption').value.trim() });
            galleryFormOpen = false;
        });
    });

    // ═══════════════════════════ SETTINGS ════════════════════════════════
    let currentWallpaper = 'default';
    function applyWallpaper(key, customUrl) {
        currentWallpaper = key || 'default';
        $('phone').className = $('phone').className.replace(/\bwallpaper-\S+/g, '').trim();
        const home = $('screen-home');
        if (currentWallpaper === 'custom' && customUrl) {
            home.style.backgroundImage = `linear-gradient(180deg, rgba(0,0,0,0.35), rgba(0,0,0,0.1) 40%), url("${customUrl.replace(/"/g, '')}")`;
            home.style.backgroundSize = 'cover';
            home.style.backgroundPosition = 'center';
        } else {
            home.style.backgroundImage = '';
            $('phone').classList.add(`wallpaper-${currentWallpaper}`);
        }
    }

    function openSettings() {
        showScreen('settings', 'Settings');
        post('getSettings');
    }

    function renderSettings(data) {
        applyWallpaper(data.wallpaper, data.customWallpaperUrl);
        $('settingsMyNumber').textContent = myNumber || '—';
        $('noCallerIdToggle').checked = !!data.noCallerId;

        const grid = $('wallpaperGrid');
        grid.innerHTML = '';
        (data.wallpapers || []).forEach((w) => {
            const tile = document.createElement('button');
            tile.className = 'wallpaper-tile wallpaper-' + w.key + (w.key === currentWallpaper ? ' selected' : '');
            tile.innerHTML = `<span>${escapeHtml(w.label)}</span>`;
            tile.addEventListener('click', () => post('saveSettings', { wallpaper: w.key }));
            grid.appendChild(tile);
        });
    }

    $('copyNumberBtn').addEventListener('click', () => {
        if (!myNumber || !navigator.clipboard) return;
        navigator.clipboard.writeText(myNumber).catch(() => {});
    });

    $('noCallerIdToggle').addEventListener('change', (e) => {
        post('saveSettings', { noCallerId: e.target.checked });
    });

    $('customWallpaperSave').addEventListener('click', () => {
        const url = $('customWallpaperUrl').value.trim();
        if (!url) return;
        post('saveSettings', { customWallpaperUrl: url });
    });

    // ═══════════════════════════ NUI MESSAGE ROUTER ═══════════════════
    window.addEventListener('message', (event) => {
        const d = event.data;
        switch (d.action) {
            case 'open':
                myNumber = d.number;
                garagesCfg = d.garages || [];
                socialAppsCfg = d.socialApps || {};
                $('myNumberTag').textContent = myNumber || '—';
                $('phone').classList.remove('hidden');
                openHome();
                post('getSettings'); // applies the saved wallpaper immediately
                post('getInstalledApps');
                break;

            case 'close':
                $('phone').classList.add('hidden');
                break;

            case 'contacts':
                contacts = d.rows || [];
                renderContacts();
                break;

            case 'threads':
                renderThreads(d.rows || []);
                break;

            case 'conversation':
                renderConversation(d.number, d.rows || []);
                break;

            case 'newMessage':
                if (screen === 'conversation' && (d.msg.sender === currentConvNumber || d.msg.recipient === currentConvNumber)) {
                    appendBubble(d.msg, true);
                } else if (screen === 'messages') {
                    post('getThreads');
                }
                break;

            case 'callRinging':
                if (activeCall) { activeCall.id = d.id; renderIncall(); }
                break;

            case 'incomingCall':
                activeCall = { id: d.id, number: d.fromNumber, name: d.fromName || d.fromNumber, direction: 'incoming', status: 'ringing' };
                showScreen('incall', 'Call');
                renderIncall();
                playRingtone();
                break;

            case 'callAnswered':
                stopRingtone();
                if (activeCall && activeCall.id === d.id) {
                    activeCall.status = 'active';
                    activeCall.startTs = Date.now();
                    renderIncall();
                    callTimer = setInterval(() => {
                        if (!activeCall) return;
                        const secs = Math.floor((Date.now() - activeCall.startTs) / 1000);
                        $('incallStatus').textContent = `${String(Math.floor(secs / 60)).padStart(2, '0')}:${String(secs % 60).padStart(2, '0')}`;
                    }, 1000);
                }
                break;

            case 'callEnded': {
                if (!activeCall || activeCall.id !== d.id) break;
                const messages = { 'no-answer': 'No answer', declined: 'Call declined', ended: 'Call ended', disconnected: 'Call disconnected' };
                endCallUI(messages[d.reason] || 'Call ended');
                break;
            }

            case 'callFailed':
                if (screen === 'incall') endCallUI(d.reason || 'Call failed');
                break;

            case 'facetimeRinging':
                if (activeFacetime) { activeFacetime.id = d.id; renderFacetime(); }
                break;

            case 'facetimeIncoming':
                activeFacetime = { id: d.id, number: d.fromNumber, name: d.fromName || d.fromNumber, direction: 'incoming', status: 'ringing' };
                showScreen('facetime-incall', 'FaceTime');
                renderFacetime();
                playRingtone();
                break;

            case 'facetimeAnswered':
                stopRingtone();
                if (activeFacetime && activeFacetime.id === d.id) {
                    activeFacetime.status = 'active';
                    ftIsOfferer = !!d.isOfferer;
                    renderFacetime();
                    ftBeginNegotiation();
                }
                break;

            case 'facetimeSignal':
                if (activeFacetime && activeFacetime.id === d.id) ftHandleSignal(d.signal);
                break;

            case 'facetimeEnded': {
                if (!activeFacetime || activeFacetime.id !== d.id) break;
                const ftMessages = { 'no-answer': 'No answer', declined: 'Declined', ended: 'Call ended', disconnected: 'Call disconnected' };
                endFacetimeUI(ftMessages[d.reason] || 'Call ended');
                break;
            }

            case 'facetimeFailed':
                if (screen === 'facetime-incall') endFacetimeUI(d.reason || 'Call failed');
                break;

            case 'feed':
                renderFeed(d.app, d.posts || []);
                break;

            case 'postCreated':
                if (d.post.app === currentFeedApp) { feeds[currentFeedApp].unshift(d.post); drawFeed(); }
                break;

            case 'postLikeUpdated': {
                const arr = feeds[currentFeedApp] || [];
                const p = arr.find((x) => x.id === d.id);
                if (p) { p.likeCount = d.likeCount; p.liked = d.liked; drawFeed(); }
                break;
            }

            case 'postDeleted': {
                feeds[currentFeedApp] = (feeds[currentFeedApp] || []).filter((x) => x.id !== d.id);
                drawFeed();
                break;
            }

            case 'vehicles':
                renderVehicles(d.rows || []);
                break;

            case 'alertSound':
                playAlert();
                break;

            case 'bankAccount':
                renderBankAccount(d.account || { cash: 0, bank: 0 });
                break;

            case 'bankLog':
                renderBankLog(d.rows || []);
                break;

            case 'mail':
                renderMail(d.rows || []);
                break;

            case 'mailDeleted':
                mailItems = mailItems.filter((m) => m.id !== d.id);
                drawMail();
                break;

            case 'newMail':
                if (screen === 'mail') post('getMail');
                break;

            case 'marketplace':
                renderMarketplace(d.rows || []);
                break;

            case 'listingCreated':
                listings.unshift(d.listing);
                drawMarketplace();
                break;

            case 'listingDeleted':
                listings = listings.filter((l) => l.id !== d.id);
                drawMarketplace();
                break;

            case 'notes':
                renderNotes(d.rows || []);
                break;

            case 'noteSaved':
                { const i = notes.findIndex((n) => n.id === d.note.id);
                if (i >= 0) notes[i] = d.note; else notes.unshift(d.note);
                drawNotes(); }
                break;

            case 'noteDeleted':
                notes = notes.filter((n) => n.id !== d.id);
                drawNotes();
                break;

            case 'crypto':
                renderCrypto(d.data);
                break;

            case 'gallery':
                renderGallery(d.rows || []);
                break;

            case 'galleryItemAdded':
                post('getGallery'); // simplest correct refresh, list is small
                break;

            case 'galleryItemDeleted':
                post('getGallery');
                break;

            case 'settings':
                renderSettings(d.data);
                break;

            case 'settingsSaved':
                applyWallpaper(d.wallpaper, d.customWallpaperUrl);
                if (screen === 'settings') post('getSettings');
                break;

            case 'installedApps':
                installedApps = new Set(d.ids || []);
                renderAppGrid();
                if (screen === 'appstore') renderAppStore();
                break;

            case 'airdropIncoming':
                showAirdropPrompt(d.data);
                break;
        }
    });

    document.addEventListener('keyup', (e) => {
        if (e.key !== 'Escape') return;
        if ($('phone').classList.contains('hidden')) return;
        if (screen === 'incall') return; // must answer/decline/hang up, not dismiss
        $('phone').classList.add('hidden');
        post('close');
    });
})();
