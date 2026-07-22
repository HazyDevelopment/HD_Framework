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

    const $ = (id) => document.getElementById(id);
    const screenParent = { home: null, contacts: 'home', dialer: 'home', messages: 'home', conversation: 'messages', feed: 'home', garages: 'home', incall: null };

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

    // ═══════════════════════════ SCREEN ROUTER ════════════════════════
    function showScreen(name, title) {
        document.querySelectorAll('.screen').forEach((el) => el.classList.add('hidden'));
        $(`screen-${name}`).classList.remove('hidden');
        screen = name;
        $('screenTitle').textContent = title;
        $('backBtn').classList.toggle('hidden', screenParent[name] === undefined ? false : screenParent[name] === null);
    }

    function goBack() {
        const parent = screenParent[screen];
        if (parent === null || parent === undefined) return;
        if (parent === 'home') openHome();
        else if (parent === 'messages') openMessages();
    }

    function openHome() { showScreen('home', 'HD Phone'); }
    $('homeBtn').addEventListener('click', openHome);
    $('backBtn').addEventListener('click', goBack);

    document.querySelectorAll('.app-icon').forEach((btn) => {
        btn.addEventListener('click', () => {
            const app = btn.dataset.app;
            if (app === 'phone') openDialer();
            else if (app === 'messages') openMessages();
            else if (app === 'contacts') openContacts();
            else if (app === 'garages') openGarages();
            else openFeed(app);
        });
    });

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
        if (callTimer) { clearInterval(callTimer); callTimer = null; }
        activeCall = null;
        if (message) $('incallStatus').textContent = message;
        setTimeout(() => { if (screen === 'incall') openHome(); }, 1200);
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
                break;

            case 'callAnswered':
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
