function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function GetParentResourceNameSafe() {
  try { return GetParentResourceName(); } catch (e) { return 'ukp_job'; }
}

async function nuiFetch(name, payload) {
  const resp = await fetch(`https://${GetParentResourceNameSafe()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload || {})
  });
  return resp.json();
}

const app = document.getElementById('app');

function switchView(view) {
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  document.getElementById('view-' + view).classList.add('active');
  document.querySelector(`.nav-btn[data-view="${view}"]`).classList.add('active');
}

document.querySelectorAll('.nav-btn').forEach(btn => {
  btn.addEventListener('click', () => switchView(btn.dataset.view));
});

document.getElementById('close-btn').addEventListener('click', () => {
  nuiFetch('close', {});
  app.classList.add('hidden');
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    nuiFetch('close', {});
    app.classList.add('hidden');
  }
});

window.addEventListener('message', (event) => {
  const data = event.data;
  if (data.action === 'open') {
    app.classList.remove('hidden');
    document.getElementById('brand-title').textContent = data.department || 'UKP Terminal';
    switchView(data.tab || 'armoury');
    if (data.tab === 'armoury') loadArmoury();
    if (data.tab === 'garage') loadGarage();
    if (data.tab === 'gps') loadGps();
  } else if (data.action === 'close') {
    app.classList.add('hidden');
  }
});

// ===================================================================
// Armoury
// ===================================================================

async function loadArmoury() {
  const res = await nuiFetch('getLoadout', {});
  if (!res) return;

  document.getElementById('armoury-rank').textContent = `Rank: ${res.rankLabel}`;

  document.getElementById('armoury-weapons').innerHTML = (res.weapons || []).map(w => `
    <div class="result-row"><span class="rr-name">${escapeHtml(w.name)}</span><span class="rr-meta">${escapeHtml(w.ammo)} rounds</span></div>
  `).join('') || '<p class="muted">No weapons issued at this rank.</p>';

  document.getElementById('armoury-items').innerHTML = (res.items || []).map(i => `
    <div class="result-row"><span class="rr-name">${escapeHtml(i.name)}</span><span class="rr-meta">x${escapeHtml(i.count)}</span></div>
  `).join('') || '<p class="muted">No equipment issued at this rank.</p>';
}

document.getElementById('draw-loadout-btn').addEventListener('click', async () => {
  await nuiFetch('drawLoadout', {});
});

// ===================================================================
// Garage
// ===================================================================

async function loadGarage() {
  const list = await nuiFetch('getGarageVehicles', {});
  const box = document.getElementById('garage-list');
  box.innerHTML = (list || []).map(v => `
    <div class="result-row">
      <span class="rr-name">${escapeHtml(v.label)}</span>
      <button class="small" data-model="${escapeHtml(v.model)}">Pull vehicle</button>
    </div>
  `).join('') || '<p class="muted">No vehicles available at your rank.</p>';

  box.querySelectorAll('button.small').forEach(btn => {
    btn.addEventListener('click', async () => {
      await nuiFetch('spawnVehicle', { model: btn.dataset.model });
    });
  });
}

document.getElementById('return-vehicle-btn').addEventListener('click', async () => {
  await nuiFetch('returnVehicle', {});
});

// ===================================================================
// Evidence locker
// ===================================================================

document.getElementById('ev-add-btn').addEventListener('click', async () => {
  const case_number = document.getElementById('ev-case').value.trim();
  const item_name = document.getElementById('ev-item').value.trim();
  const description = document.getElementById('ev-desc').value.trim();
  const status = document.getElementById('ev-status');

  if (!case_number || !item_name) {
    status.textContent = 'Case number and item are required.';
    return;
  }

  const res = await nuiFetch('addEvidence', { case_number, item_name, description });
  if (res && res.ok) {
    status.textContent = 'Evidence logged.';
    document.getElementById('ev-item').value = '';
    document.getElementById('ev-desc').value = '';
  } else {
    status.textContent = 'Failed to log evidence.';
  }
});

document.getElementById('ev-search-btn').addEventListener('click', async () => {
  const case_number = document.getElementById('ev-search-input').value.trim();
  const rows = await nuiFetch('searchEvidence', { case_number });
  const box = document.getElementById('ev-results');
  box.innerHTML = (rows || []).map(r => `
    <div class="result-row" style="flex-direction:column;align-items:flex-start;">
      <span class="rr-name">${escapeHtml(r.item_name)} — Case ${escapeHtml(r.case_number)}</span>
      <span class="muted">${escapeHtml(r.description || '')}</span>
      <span class="rr-meta">Logged by ${escapeHtml(r.logged_by)} · ${escapeHtml(r.created_at)}</span>
    </div>
  `).join('') || '<p class="muted">No evidence found for that case number.</p>';
});

// ===================================================================
// GPS
// ===================================================================

async function loadGps() {
  const units = await nuiFetch('getGpsUnits', {});
  const box = document.getElementById('gps-list');
  box.innerHTML = (units || []).map(u => `
    <div class="result-row">
      <span class="rr-name">${escapeHtml(u.name)}</span>
      <span class="rr-meta">${escapeHtml(u.jobName)}</span>
      <button class="small" data-source="${escapeHtml(u.source)}">Waypoint</button>
    </div>
  `).join('') || '<p class="muted">No on-duty units currently tracked.</p>';

  box.querySelectorAll('button.small').forEach(btn => {
    btn.addEventListener('click', async () => {
      await nuiFetch('gpsWaypoint', { source: btn.dataset.source });
    });
  });
}
