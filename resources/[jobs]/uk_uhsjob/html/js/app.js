function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function GetParentResourceNameSafe() {
  try { return GetParentResourceName(); } catch (e) { return 'ukhs_job'; }
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
    document.getElementById('brand-title').textContent = data.department || 'UKHS Terminal';
    switchView(data.tab || 'armoury');
    if (data.tab === 'armoury') loadArmoury();
    if (data.tab === 'garage') loadGarage();
    if (data.tab === 'gps') loadGps();
  } else if (data.action === 'close') {
    app.classList.add('hidden');
  }
});

// ===================================================================
// Equipment store (armoury)
// ===================================================================

async function loadArmoury() {
  const res = await nuiFetch('getLoadout', {});
  if (!res) return;

  document.getElementById('armoury-rank').textContent = `Rank: ${res.rankLabel}`;

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
