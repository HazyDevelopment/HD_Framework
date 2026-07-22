(function () {
    'use strict';

    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'hd_society';

    function post(action, data) {
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    const panel = document.getElementById('panel');
    const balanceEl = document.getElementById('balance');
    const amountInput = document.getElementById('amountInput');

    function formatMoney(n) {
        return `£${Number(n).toLocaleString()}`;
    }

    function close() {
        panel.classList.add('hidden');
        post('close');
    }

    document.getElementById('closeBtn').addEventListener('click', close);

    document.getElementById('depositBtn').addEventListener('click', () => {
        const amount = Number(amountInput.value);
        if (!amount || amount <= 0) return;
        post('deposit', { amount });
        amountInput.value = '';
    });

    document.getElementById('withdrawBtn').addEventListener('click', () => {
        const amount = Number(amountInput.value);
        if (!amount || amount <= 0) return;
        post('withdraw', { amount });
        amountInput.value = '';
    });

    window.addEventListener('message', (event) => {
        const d = event.data;
        if (d.action === 'open') {
            document.getElementById('label').textContent = `${d.label} Funds`;
            balanceEl.textContent = formatMoney(d.balance);
            panel.classList.remove('hidden');
        } else if (d.action === 'balance') {
            balanceEl.textContent = formatMoney(d.balance);
        }
    });

    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape' && !panel.classList.contains('hidden')) close();
    });
})();
