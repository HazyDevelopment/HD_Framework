// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | PHONE (dialer + calls)
//  Call state itself (ring/answer/decline/connect) is owned by the
//  shared overlay in app.js — this file is just the dial pad and
//  kicking a call off.
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let entry = '';
    let activeWin = null;

    function render(win) {
        win.innerHTML = `
            ${HD.backBar('Phone')}
            <div class="app-body no-pad" style="display:flex;flex-direction:column;">
                <div class="dialpad-display">${entry || '&nbsp;'}</div>
                <div class="dialpad">
                    ${keys().map((k) => `<button data-digit="${k.d}">${k.d}${k.sub ? `<span class="sub">${k.sub}</span>` : ''}</button>`).join('')}
                </div>
                <div class="call-btn-row">
                    <div class="call-btn" id="dial-call">${callSvg()}</div>
                </div>
            </div>`;
        HD.bindBack(win);
        win.querySelectorAll('[data-digit]').forEach((btn) => {
            btn.onclick = () => { entry += btn.dataset.digit; paintDisplay(win); };
        });
        win.querySelector('#dial-call').onclick = () => dial(entry);
    }
    function paintDisplay(win) {
        const disp = win.querySelector('.dialpad-display');
        if (disp) disp.textContent = entry;
    }
    function keys() {
        return [
            { d: '1' }, { d: '2', sub: 'ABC' }, { d: '3', sub: 'DEF' },
            { d: '4', sub: 'GHI' }, { d: '5', sub: 'JKL' }, { d: '6', sub: 'MNO' },
            { d: '7', sub: 'PQRS' }, { d: '8', sub: 'TUV' }, { d: '9', sub: 'WXYZ' },
            { d: '*' }, { d: '0', sub: '+' }, { d: '#' },
        ];
    }
    function callSvg() { return `<svg width="26" height="26" viewBox="0 0 24 24" fill="#fff"><path d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2a1.5 1.5 0 0 1 1.5-.4c1.2.4 2.5.6 3.9.6a1.5 1.5 0 0 1 1.5 1.5v3.6a1.5 1.5 0 0 1-1.5 1.5C10.5 22 2 13.5 2 3.7A1.5 1.5 0 0 1 3.5 2.2h3.6A1.5 1.5 0 0 1 8.6 3.7c0 1.4.2 2.7.6 3.9.1.5 0 1.1-.4 1.5Z"/></svg>`; }

    function dial(number) {
        number = (number || '').trim();
        if (!number) return;
        const contact = (window.HDApps.contacts && window.HDApps.contacts.getCache().find((c) => c.number === number));
        HD.showOutgoingCall(contact ? contact.name : number, null);
        HD.post('startCall', { to: number });
        entry = '';
    }

    window.HDApps.phone = {
        open(win) { activeWin = win; entry = ''; render(win); },
        dial,
    };
})();
