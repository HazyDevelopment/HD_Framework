// ═══════════════════════════════════════════════════════════════════
//  HD MECHANIC | NUI — Mechanic Terminal
//  Pure display + button relay. Every action button just fires a
//  server event that re-checks on-duty status, shop proximity, and
//  who's actually paying — nothing here is authoritative.
// ═══════════════════════════════════════════════════════════════════

const app = document.getElementById('app');

function post(name, body = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body),
    }).then((r) => r.json()).catch(() => ({}));
}

function toast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.remove('hidden');
    clearTimeout(toast._t);
    toast._t = setTimeout(() => el.classList.add('hidden'), 2500);
}

function closePanel() {
    app.classList.add('hidden');
    post('close');
}

document.getElementById('closeBtn').addEventListener('click', closePanel);
document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !app.classList.contains('hidden')) closePanel();
});

function setBar(barId, pctId, value) {
    const bar = document.getElementById(barId);
    const pct = document.getElementById(pctId);
    const clamped = Math.max(0, Math.min(100, value));
    bar.style.width = `${clamped}%`;
    pct.textContent = `${clamped}%`;
    bar.classList.remove('warn', 'bad');
    if (clamped < 30) bar.classList.add('bad');
    else if (clamped < 60) bar.classList.add('warn');
}

function fmtExpiry(iso) {
    if (!iso) return '';
    const d = new Date(iso.replace(' ', 'T'));
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}

function render(data) {
    document.getElementById('plate').textContent = data.diagnostics.plate;
    document.getElementById('model').textContent = data.diagnostics.model;

    document.getElementById('limpBanner').classList.toggle('hidden', !data.compliance.limpMode);

    setBar('barBody', 'pctBody', data.diagnostics.bodyPercent);
    setBar('barEngine', 'pctEngine', data.diagnostics.enginePercent);
    setBar('barTank', 'pctTank', data.diagnostics.tankPercent);
    // "Cleanliness" is the inverse of dirt — a fully dirty car reads 0% clean.
    const clean = 100 - data.diagnostics.dirtPercent;
    document.getElementById('barDirt').style.width = `${clean}%`;
    document.getElementById('pctDirt').textContent = `${clean}%`;

    const tyreGrid = document.getElementById('tyreGrid');
    tyreGrid.innerHTML = data.diagnostics.tyres.map((burst, i) => `
        <div class="tyre ${burst ? 'burst' : 'ok'}">Tyre ${i + 1}<br>${burst ? 'BURST' : 'OK'}</div>
    `).join('');

    const motEl = document.getElementById('motStatus');
    if (data.compliance.motValid) {
        motEl.textContent = `Valid until ${fmtExpiry(data.compliance.motExpiry)}`;
        motEl.className = 'compliance-status valid';
    } else {
        motEl.textContent = 'EXPIRED / NONE';
        motEl.className = 'compliance-status invalid';
    }

    const insEl = document.getElementById('insuranceStatus');
    if (data.compliance.insuranceValid) {
        insEl.textContent = `Valid until ${fmtExpiry(data.compliance.insuranceExpiry)}`;
        insEl.className = 'compliance-status valid';
    } else {
        insEl.textContent = 'EXPIRED / NONE';
        insEl.className = 'compliance-status invalid';
    }

    document.getElementById('actions').classList.toggle('hidden', !data.canService);
    document.getElementById('noServiceHint').classList.toggle('hidden', data.canService);

    if (data.canService && data.prices) {
        document.getElementById('btnRepair').textContent = `Full Repair (£${data.prices.repair})`;
        document.getElementById('btnMOT').textContent = `Issue MOT (£${data.prices.mot})`;
        document.getElementById('btnInsurance').textContent = `Issue Insurance (£${data.prices.insurance})`;
    }
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'open') {
        app.classList.remove('hidden');
        render(msg.data);
    }
});

document.getElementById('btnRepair').addEventListener('click', () => { post('fullRepair'); toast('Repair requested…'); });
document.getElementById('btnMOT').addEventListener('click', () => { post('issueMOT'); toast('MOT test requested…'); });
document.getElementById('btnInsurance').addEventListener('click', () => { post('issueInsurance'); toast('Insurance requested…'); });
