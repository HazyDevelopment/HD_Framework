// ═══════════════════════════════════════════════════════════════════
//  HD PHONE | CRYPTO
// ═══════════════════════════════════════════════════════════════════
(function () {
    window.HDApps = window.HDApps || {};
    let state = { price: 0, holdings: 0, coinName: 'HD Coin', coinTicker: 'HDC' };
    let activeWin = null;
    let history = [];

    HD.on('crypto', (payload) => { state = payload; history = [payload.price]; if (activeWin) renderMain(activeWin); });
    HD.on('cryptoPrice', (price) => {
        state.price = price;
        history.push(price);
        if (history.length > 30) history.shift();
        if (activeWin) renderMain(activeWin);
    });

    function sparkline() {
        if (history.length < 2) return '';
        const min = Math.min(...history), max = Math.max(...history);
        const range = max - min || 1;
        const pts = history.map((p, i) => `${(i / (history.length - 1)) * 100},${30 - ((p - min) / range) * 28}`).join(' ');
        return `<svg viewBox="0 0 100 30" style="width:100%;height:60px;"><polyline points="${pts}" fill="none" stroke="var(--accent-2)" stroke-width="2"/></svg>`;
    }

    function renderMain(win) {
        win.innerHTML = `
            ${HD.backBar(state.coinTicker)}
            <div class="app-body">
                <div class="card" style="padding:18px;margin-bottom:14px;">
                    <div style="font-size:12px;color:var(--text-dim);text-transform:uppercase;">${state.coinName}</div>
                    <div style="font-size:30px;font-weight:700;margin:4px 0;">£${state.price.toFixed(2)}</div>
                    ${sparkline()}
                </div>
                <div class="card" style="padding:14px;margin-bottom:14px;">
                    <div style="font-size:13px;color:var(--text-dim);">Your Holdings</div>
                    <div style="font-size:18px;font-weight:700;">${state.holdings.toFixed(4)} ${state.coinTicker}</div>
                    <div style="font-size:13px;color:var(--text-dim);">≈ £${(state.holdings * state.price).toFixed(2)}</div>
                </div>
                <div style="display:flex;gap:10px;">
                    <button class="btn-primary" style="padding:12px;" id="crypto-buy">Buy</button>
                    <button class="btn-primary" style="padding:12px;background:linear-gradient(160deg,#ef4444,#b91c1c);box-shadow:none;" id="crypto-sell">Sell</button>
                </div>
            </div>`;
        HD.bindBack(win);
        win.querySelector('#crypto-buy').onclick = () => renderPrompt(win, 'Buy', '£ to spend', (v) => HD.post('cryptoBuy', { amount: v }));
        win.querySelector('#crypto-sell').onclick = () => renderPrompt(win, 'Sell', `${state.coinTicker} to sell`, (v) => HD.post('cryptoSell', { amount: v }));
    }

    function renderPrompt(win, title, placeholder, onSubmit) {
        win.innerHTML = `
            ${HD.backBar(title)}
            <div class="app-body">
                <input class="field" id="crypto-amount" type="number" step="any" placeholder="${placeholder}" style="background:var(--surface-2);" />
                <button class="btn-primary" style="margin-top:16px;" id="crypto-submit">${title}</button>
            </div>`;
        win.querySelector('#app-back').onclick = () => renderMain(win);
        win.querySelector('#crypto-submit').onclick = () => {
            const v = parseFloat(win.querySelector('#crypto-amount').value);
            if (!v || v <= 0) { HD.toast('Enter a valid amount.'); return; }
            onSubmit(v);
            setTimeout(() => HD.post('getCrypto', {}), 200);
            renderMain(win);
        };
    }

    window.HDApps.crypto = { open(win) { activeWin = win; renderMain(win); HD.post('getCrypto', {}); } };
})();
