// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | BANK
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let data = { cash: 0, bank: 0, log: [] };
    let activeWin = null;

    HD.on('bank', (payload) => { data = payload; if (activeWin) renderMain(activeWin); });

    function describeLine(l) {
        const map = { deposit: 'Deposit', withdraw: 'Withdrawal', transfer_out: `To ${l.other_party}`, transfer_in: `From ${l.other_party}` };
        return map[l.type] || l.type;
    }

    function renderMain(win) {
        win.innerHTML = `
            ${HD.backBar('Bank')}
            <div class="app-body">
                <div class="card" style="padding:18px;text-align:center;margin-bottom:14px;">
                    <div style="font-size:12px;color:var(--text-dim);text-transform:uppercase;">Bank Balance</div>
                    <div style="font-size:32px;font-weight:700;margin:4px 0;">£${data.bank.toLocaleString()}</div>
                    <div style="font-size:13px;color:var(--text-dim);">Cash: £${data.cash.toLocaleString()}</div>
                </div>
                <div style="display:flex;gap:10px;margin-bottom:18px;">
                    <button class="btn-primary" style="padding:12px;" id="bank-deposit">Deposit</button>
                    <button class="btn-primary" style="padding:12px;background:linear-gradient(160deg,#34c759,#16a34a);box-shadow:none;" id="bank-withdraw">Withdraw</button>
                    <button class="btn-primary" style="padding:12px;background:linear-gradient(160deg,#f59e0b,#b45309);box-shadow:none;" id="bank-transfer">Transfer</button>
                </div>
                <div class="section-title">Activity</div>
                ${data.log.length ? data.log.map((l) => `
                    <div class="list-row">
                        <div class="list-main"><div class="title">${describeLine(l)}</div><div class="subtitle">${l.created}</div></div>
                        <div class="list-meta" style="color:${l.type.includes('in') || l.type === 'deposit' ? 'var(--accent-2)' : 'var(--danger)'};font-weight:600;">
                            ${l.type.includes('in') || l.type === 'deposit' ? '+' : '-'}£${l.amount}
                        </div>
                    </div>`).join('') : `<div class="empty-state">No activity yet.</div>`}
            </div>`;
        HD.bindBack(win);
        win.querySelector('#bank-deposit').onclick = () => renderAmountPrompt(win, 'Deposit', (amt) => HD.post('bankDeposit', { amount: amt }));
        win.querySelector('#bank-withdraw').onclick = () => renderAmountPrompt(win, 'Withdraw', (amt) => HD.post('bankWithdraw', { amount: amt }));
        win.querySelector('#bank-transfer').onclick = () => renderTransfer(win);
    }

    function renderAmountPrompt(win, title, onSubmit) {
        win.innerHTML = `
            ${HD.backBar(title)}
            <div class="app-body">
                <input class="field" id="amount-input" type="number" placeholder="Amount (£)" style="background:var(--surface-2);" />
                <button class="btn-primary" style="margin-top:16px;" id="amount-submit">${title}</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderMain(win);
        win.querySelector('#amount-submit').onclick = () => {
            const amt = parseInt(win.querySelector('#amount-input').value, 10);
            if (!amt || amt <= 0) { HD.toast('Enter a valid amount.'); return; }
            onSubmit(amt);
            renderMain(win);
        };
    }

    function renderTransfer(win) {
        win.innerHTML = `
            ${HD.backBar('Transfer')}
            <div class="app-body">
                <div class="field-group">
                    <input class="field" id="transfer-to" placeholder="Recipient phone number" style="background:var(--surface-2);" />
                    <input class="field" id="transfer-amount" type="number" placeholder="Amount (£)" style="background:var(--surface-2);" />
                </div>
                <button class="btn-primary" style="margin-top:16px;" id="transfer-submit">Send</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderMain(win);
        win.querySelector('#transfer-submit').onclick = () => {
            const to = win.querySelector('#transfer-to').value.trim();
            const amt = parseInt(win.querySelector('#transfer-amount').value, 10);
            if (!to || !amt || amt <= 0) { HD.toast('Enter a number and amount.'); return; }
            HD.post('bankTransfer', { to, amount: amt });
            renderMain(win);
        };
    }

    window.HDApps.bank = { open(win) { activeWin = win; renderMain(win); HD.post('getBank', {}); } };
})();
