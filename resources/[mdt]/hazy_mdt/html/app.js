/* ═══════════════════════════════════════════════════════════════
   HAZY DEVELOPMENT | ADVANCED MDT | NUI LOGIC
   ═══════════════════════════════════════════════════════════════ */

const RES = () => (window.GetParentResourceName ? GetParentResourceName() : 'hazy_mdt');

const S = {
  open: false,
  dept: null,          // 'police' | 'uhs'
  prefix: null,
  isBoss: false,
  deptTheme: null,     // department base theme from config
  savedTheme: null,    // { mode, header, background } or null
  callsign: '',
  reportTypes: [],
  vehicleMarkers: [],
  bloodTypes: [],
  repInvolved: [],     // [{citizenid, name}]
  patSelected: null,
  cmdSelected: null,
  onDuty: false,
  dutyEnabled: true
};

/* ─────────────────── NUI bridge ─────────────────── */
function post(cbName, data) {
  return fetch(`https://${RES()}/${cbName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {})
  }).then(r => r.json()).catch(() => ({}));
}
function request(endpoint, data) {
  return post('request', { prefix: S.prefix, endpoint, data });
}

/* ─────────────────── Utilities ─────────────────── */
const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function msg(id, text, ok) {
  const el = $(id);
  el.textContent = text;
  el.className = 'form-msg ' + (ok ? 'ok' : 'err');
  setTimeout(() => { el.textContent = ''; }, 4000);
}

/* ─────────────────── Theme engine ───────────────────
   Text colour is derived from luminance so writing stays
   visible on light, dark and any custom colour.          */
function hexToRgb(h) {
  h = h.replace('#', '');
  if (h.length === 3) h = h.split('').map(c => c + c).join('');
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}
function luminance(hex) {
  const [r, g, b] = hexToRgb(hex).map(v => {
    v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
const textOn = hex => luminance(hex) > 0.45 ? '#15181D' : '#FFFFFF';
function shade(hex, amt) { // amt -1..1
  const [r, g, b] = hexToRgb(hex);
  const f = v => Math.max(0, Math.min(255, Math.round(amt > 0 ? v + (255 - v) * amt : v * (1 + amt))));
  return '#' + [f(r), f(g), f(b)].map(v => v.toString(16).padStart(2, '0')).join('');
}

function resolveTheme() {
  const t = S.savedTheme;
  const d = S.deptTheme;
  if (!t || t.mode === 'default') {
    return { header: d.header, bg: d.background, surface: d.surface, accent: d.accent };
  }
  if (t.mode === 'light') {
    return { header: d.header, bg: '#F2F4F7', surface: '#FFFFFF', accent: d.accent };
  }
  if (t.mode === 'dark') {
    return { header: '#101318', bg: '#171B21', surface: '#20252D', accent: d.accent };
  }
  // custom
  const header = t.header || d.header;
  const bg = t.background || d.background;
  const light = luminance(bg) > 0.45;
  return {
    header, bg,
    surface: light ? shade(bg, -0.06) : shade(bg, 0.10),
    accent: shade(header, light ? -0.1 : 0.25)
  };
}

function applyTheme() {
  const th = resolveTheme();
  const r = document.documentElement.style;
  const text = textOn(th.bg);
  const headerText = textOn(th.header);
  const dark = text === '#FFFFFF';
  r.setProperty('--header', th.header);
  r.setProperty('--bg', th.bg);
  r.setProperty('--surface', th.surface);
  r.setProperty('--surface-2', dark ? shade(th.surface, -0.18) : shade(th.surface, -0.04));
  r.setProperty('--accent', th.accent);
  r.setProperty('--accent-text', textOn(th.accent));
  r.setProperty('--text', text);
  r.setProperty('--text-muted', dark ? 'rgba(255,255,255,0.62)' : 'rgba(20,24,30,0.62)');
  r.setProperty('--header-text', headerText);
  r.setProperty('--border', dark ? 'rgba(255,255,255,0.14)' : 'rgba(20,24,30,0.16)');
}

/* ─────────────────── Open / close ─────────────────── */
window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') openMdt(data);
  else if (data.action === 'close') closeMdt();
  else if (data.action === 'broadcast') onBroadcast(data.payload);
});

function openMdt(cfg) {
  S.open = true;
  S.dept = cfg.department;
  S.prefix = cfg.prefix;
  S.isBoss = cfg.isBoss;
  S.deptTheme = cfg.theme;
  S.reportTypes = cfg.reportTypes || [];
  S.vehicleMarkers = cfg.vehicleMarkers || [];
  S.bloodTypes = cfg.bloodTypes || [];

  $('brandName').textContent = cfg.brand;
  $('brandSub').textContent = cfg.brandSub || '';
  $('crestBadge').textContent = S.dept === 'uhs' ? 'UHS' : 'MDT';

  const isPolice = S.dept === 'police';
  const tabs = cfg.tabs || {};
  $('navVehicles').classList.toggle('hidden', !isPolice || tabs.vehicles === false);
  $('navPatients').classList.toggle('hidden', isPolice || tabs.patients === false);
  $('navCommand').classList.toggle('hidden', !S.isBoss || tabs.command === false);
  $('newReportLabel').textContent = isPolice ? 'New Report' : 'New Medical Report';
  $('reportsLabel').textContent = isPolice ? 'Reports' : 'Medical Reports';
  $('newReportHeading').textContent = isPolice ? 'New Report' : 'New Medical Report';
  $('warrantPanel').classList.toggle('hidden', !isPolice);

  fillSelect('repType', S.reportTypes);
  fillSelect('patBlood', S.bloodTypes);

  applyTheme();
  document.getElementById('app').classList.remove('hidden');
  switchPage('dashboard');
  loadDashboard();
}

function closeMdt() {
  S.open = false;
  $('app').classList.add('hidden');
  post('close');
}

document.addEventListener('keyup', e => { if (e.key === 'Escape' && S.open) closeMdt(); });
$('closeBtn').addEventListener('click', closeMdt);

function fillSelect(id, arr) {
  $(id).innerHTML = arr.map(v => `<option value="${esc(v)}">${esc(v)}</option>`).join('');
}

/* ─────────────────── Navigation ─────────────────── */
const PAGE_TITLES = {
  dashboard: 'Dashboard', civsearch: 'Civilian Search', vehicles: 'Vehicle Check',
  patients: 'Patient Records', newreport: 'New Report', reports: 'Reports',
  command: 'Command', settings: 'Settings'
};

document.querySelectorAll('.nav-btn').forEach(btn =>
  btn.addEventListener('click', () => switchPage(btn.dataset.page)));

function switchPage(page) {
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.page === page));
  document.querySelectorAll('.page').forEach(p => p.classList.toggle('active', p.id === 'page-' + page));
  let title = PAGE_TITLES[page] || page;
  if (S.dept === 'uhs' && page === 'newreport') title = 'New Medical Report';
  if (S.dept === 'uhs' && page === 'reports') title = 'Medical Reports';
  $('pageTitle').textContent = title;
  if (page === 'dashboard') loadDashboard();
  if (page === 'settings') loadSettingsPage();
}

/* ─────────────────── Clock ─────────────────── */
setInterval(() => {
  const d = new Date();
  $('clock').textContent = d.toTimeString().slice(0, 5);
}, 1000);

/* ─────────────────── Duty toggle ─────────────────── */
function renderDuty() {
  const btn = $('dutyBtn');
  btn.classList.toggle('hidden', !S.dutyEnabled);
  btn.classList.toggle('on', S.onDuty);
  btn.classList.toggle('off', !S.onDuty);
  $('dutyLabel').textContent = S.onDuty ? 'ON DUTY' : 'OFF DUTY';
}

$('dutyBtn').addEventListener('click', async () => {
  const r = await request('toggleDuty');
  if (r.ok) { S.onDuty = r.onDuty; renderDuty(); }
});

/* ─────────────────── Dashboard ─────────────────── */
async function loadDashboard() {
  const d = await request('dashboard');
  S.callsign = d.callsign || '';
  S.savedTheme = d.theme || null;
  S.dutyEnabled = d.dutyEnabled !== false;
  S.onDuty = d.onDuty === true;
  applyTheme();
  renderDuty();
  $('callsignChip').textContent = S.callsign || 'NO CALLSIGN';
  $('officerName').textContent = d.officer || '';
  const list = $('updatesList');
  const updates = d.updates || [];
  list.innerHTML = updates.length ? updates.map(u => `
    <div class="card static ${u.kind === 'training' ? 'training' : ''}">
      <div class="card-title">
        <span class="tag ${u.kind === 'training' ? 'ok' : ''}">${u.kind === 'training' ? 'Training' : 'Update'}</span>
        ${esc(u.title)}
      </div>
      <div class="card-sub">${esc(u.author)}${u.callsign ? ' · ' + esc(u.callsign) : ''} · ${esc(u.created || '')}</div>
      <div class="card-body">${esc(u.message)}</div>
    </div>`).join('') : '<div class="empty">No updates posted yet.</div>';
}

function onBroadcast(p) {
  if (!p) return;
  const list = $('liveFeedList');
  const empty = list.querySelector('.empty');
  if (empty) empty.remove();
  const el = document.createElement('div');
  el.className = 'card static';
  el.innerHTML = `
    <div class="card-title"><span class="tag warn">LIVE</span>${esc(p.time || '')}</div>
    <div class="card-sub">${esc(p.author || '')}${p.callsign ? ' · ' + esc(p.callsign) : ''}</div>
    <div class="card-body">${esc(p.message || '')}</div>`;
  list.prepend(el);
  while (list.children.length > 30) list.lastChild.remove();
}

/* ─────────────────── Civilian search ─────────────────── */
$('civSearchBtn').addEventListener('click', doCivSearch);
$('civSearchInput').addEventListener('keyup', e => { if (e.key === 'Enter') doCivSearch(); });

async function doCivSearch() {
  const term = $('civSearchInput').value.trim();
  if (!term) return;
  $('civProfile').classList.add('hidden');
  $('civResults').innerHTML = '<div class="empty">Searching…</div>';
  const d = await request('civSearch', { term });
  const res = d.results || [];
  $('civResults').innerHTML = res.length ? res.map(c => `
    <div class="card" data-cid="${esc(c.citizenid)}" data-name="${esc(c.name)}" data-dob="${esc(c.dob)}" data-lic="${esc((c.licenses || []).join(', '))}">
      <div class="card-title">${esc(c.name)}</div>
      <div class="card-sub">DOB ${esc(c.dob)} · ID ${esc(c.citizenid)}</div>
    </div>`).join('') : '<div class="empty">No civilians found matching that name.</div>';
  $('civResults').querySelectorAll('.card').forEach(el =>
    el.addEventListener('click', () => openCivProfile(el.dataset)));
}

async function openCivProfile(ds) {
  const box = $('civProfile');
  box.classList.remove('hidden');
  box.innerHTML = '<div class="empty">Loading profile…</div>';
  const d = await request('civProfile', { citizenid: ds.cid });
  const isPolice = S.dept === 'police';

  const warrants = (d.warrants || []).map(w => `
    <div class="card static"><div class="card-title"><span class="tag warn">Warrant</span>${esc(w.reason)}</div>
    <div class="card-sub">Issued by ${esc(w.issued_by)} · ${esc(w.created || '')}</div></div>`).join('');

  const history = (d.history || []).map(h => `
    <div class="card static"><div class="card-title"><span class="tag">${esc(h.rtype)}</span>${esc(h.title)}</div>
    <div class="card-sub">Filed by ${esc(h.author)} · ${esc(h.created || '')}</div></div>`).join('');

  const patients = (d.patientRecords || []).map(p => `
    <div class="card static"><div class="card-title"><span class="tag ok">Patient</span>Blood ${esc(p.blood_type || '—')}</div>
    <div class="card-sub">${esc(p.author)} · ${esc(p.created || '')}</div>
    <div class="card-body">Staff: ${esc(p.staff || '—')}\nMedications: ${esc(p.medications || '—')}\nFollow-up: ${esc(p.treatment || '—')}</div></div>`).join('');

  box.innerHTML = `
    <div class="panel">
      <div class="profile-head">
        <div class="mugshot" id="mugBox">${d.mugshot ? `<img src="${esc(d.mugshot)}" alt="Mugshot">` : 'No mugshot on file'}</div>
        <div class="profile-info">
          <h2>${esc(ds.name)}</h2>
          <div class="kv"><b>DOB</b>${esc(ds.dob)}</div>
          <div class="kv"><b>ID</b>${esc(ds.cid)}</div>
          <div class="kv"><b>Licenses</b>${esc(ds.lic || 'None on record')}</div>
          ${(d.warrants && d.warrants.length) ? '<div class="kv"><span class="tag warn">ACTIVE WARRANT</span></div>' : ''}
        </div>
      </div>
      ${isPolice ? `
        <div class="section-title">Mugshot Media Link</div>
        <div class="inline">
          <input id="mugUrl" type="text" placeholder="https://i.imgur.com/… (approved image hosts only)">
          <button class="btn" id="mugSaveBtn">Save</button>
        </div>
        <div class="form-msg" id="mugMsg"></div>
        <div class="section-title">Active Warrants</div>
        ${warrants || '<div class="empty">No active warrants.</div>'}` : ''}
      <div class="section-title">${isPolice ? 'Record History' : 'Report History'}</div>
      ${history || '<div class="empty">No filed reports involve this person.</div>'}
      ${!isPolice ? `<div class="section-title">Patient Records</div>${patients || '<div class="empty">No patient records on file.</div>'}` : ''}
    </div>`;

  const saveBtn = $('mugSaveBtn');
  if (saveBtn) saveBtn.addEventListener('click', async () => {
    const r = await request('setMugshot', { citizenid: ds.cid, url: $('mugUrl').value.trim() });
    if (r.ok) { msg('mugMsg', 'Mugshot saved.', true); openCivProfile(ds); }
    else msg('mugMsg', r.error || 'Could not save mugshot.', false);
  });
}

/* ─────────────────── Vehicle check ─────────────────── */
$('vehSearchBtn').addEventListener('click', doVehSearch);
$('vehSearchInput').addEventListener('keyup', e => { if (e.key === 'Enter') doVehSearch(); });

async function doVehSearch() {
  const term = $('vehSearchInput').value.trim();
  if (!term) return;
  $('vehResults').innerHTML = '<div class="empty">Running plate…</div>';
  const d = await request('vehicleSearch', { term });
  const res = d.results || [];
  $('vehResults').innerHTML = res.length ? res.map((v, i) => `
    <div class="card static">
      <div class="card-title"><span class="plate">${esc(v.plate)}</span></div>
      <div class="kv" style="margin-top:8px"><b>Registered owner</b>${esc(v.owner)}</div>
      <div class="kv"><b>Model</b>${esc(v.model || 'Unknown')}</div>
      ${v.motValid !== undefined ? `
      <div class="kv"><b>MOT</b>${v.motValid ? '<span class="tag ok">Valid</span>' : '<span class="tag warn">Expired/None</span>'}</div>
      <div class="kv"><b>Insurance</b>${v.insuranceValid ? '<span class="tag ok">Valid</span>' : '<span class="tag warn">Expired/None</span>'}</div>
      ${v.limpMode ? '<div class="kv"><b>Condition</b><span class="tag warn">Limp mode — hard impact damage</span></div>' : ''}
      ` : ''}
      <div class="kv"><b>Marker</b>${v.marker ? `<span class="tag warn">${esc(v.marker)}</span>${esc(v.markerNotes || '')} <span class="muted small">(set by ${esc(v.markerBy || '')})</span>` : 'None'}</div>
      <div class="inline" style="margin-top:10px">
        <select id="mk-sel-${i}"><option value="">— Clear marker —</option>${S.vehicleMarkers.map(m => `<option ${v.marker === m ? 'selected' : ''}>${esc(m)}</option>`).join('')}</select>
        <input id="mk-note-${i}" type="text" placeholder="Marker notes…" value="${esc(v.markerNotes || '')}">
        <button class="btn" data-plate="${esc(v.plate)}" data-i="${i}">Set Marker</button>
      </div>
    </div>`).join('') : '<div class="empty">No vehicles found for that plate.</div>';
  $('vehResults').querySelectorAll('button[data-plate]').forEach(btn =>
    btn.addEventListener('click', async () => {
      const i = btn.dataset.i;
      const r = await request('setVehicleMarker', {
        plate: btn.dataset.plate,
        marker: $(`mk-sel-${i}`).value,
        notes: $(`mk-note-${i}`).value
      });
      if (r.ok) doVehSearch();
    }));
}

/* ─────────────────── Civilian picker (shared) ─────────────────── */
function bindCivPicker(inputId, btnId, resultsId, onPick) {
  const run = async () => {
    const term = $(inputId).value.trim();
    if (!term) return;
    $(resultsId).innerHTML = '<div class="empty">Searching…</div>';
    const d = await request('civSearch', { term });
    const res = d.results || [];
    $(resultsId).innerHTML = res.length ? res.map(c => `
      <div class="card" data-cid="${esc(c.citizenid)}" data-name="${esc(c.name)}">
        <div class="card-title">${esc(c.name)}</div>
        <div class="card-sub">DOB ${esc(c.dob)} · ID ${esc(c.citizenid)}</div>
      </div>`).join('') : '<div class="empty">No match.</div>';
    $(resultsId).querySelectorAll('.card').forEach(el =>
      el.addEventListener('click', () => { onPick({ citizenid: el.dataset.cid, name: el.dataset.name }); $(resultsId).innerHTML = ''; }));
  };
  $(btnId).addEventListener('click', run);
  $(inputId).addEventListener('keyup', e => { if (e.key === 'Enter') run(); });
}

/* ─────────────────── New report ─────────────────── */
bindCivPicker('repCivSearch', 'repCivSearchBtn', 'repCivResults', c => {
  if (!S.repInvolved.find(x => x.citizenid === c.citizenid)) S.repInvolved.push(c);
  renderInvolved();
});

function renderInvolved() {
  $('repInvolved').innerHTML = S.repInvolved.map((c, i) =>
    `<span class="chip">${esc(c.name)}<button data-i="${i}">✕</button></span>`).join('');
  $('repInvolved').querySelectorAll('button').forEach(b =>
    b.addEventListener('click', () => { S.repInvolved.splice(+b.dataset.i, 1); renderInvolved(); }));
}

$('repSaveBtn').addEventListener('click', async () => {
  const title = $('repTitle').value.trim();
  const content = $('repContent').value.trim();
  if (!title || !content) return msg('repMsg', 'Title and report body are required.', false);
  const r = await request('createReport', {
    rtype: $('repType').value, title, content, involved: S.repInvolved
  });
  if (r.ok) {
    msg('repMsg', `Report #${r.id} filed.`, true);
    $('repTitle').value = ''; $('repContent').value = ''; S.repInvolved = []; renderInvolved();
  } else msg('repMsg', r.error || 'Could not file report.', false);
});

/* ─────────────────── Reports search / view ─────────────────── */
$('repSearchBtn').addEventListener('click', doRepSearch);
$('repSearchInput').addEventListener('keyup', e => { if (e.key === 'Enter') doRepSearch(); });

async function doRepSearch() {
  $('repView').classList.add('hidden');
  $('repResults').innerHTML = '<div class="empty">Searching…</div>';
  const d = await request('searchReports', { term: $('repSearchInput').value.trim() });
  const res = d.results || [];
  $('repResults').innerHTML = res.length ? res.map(r => `
    <div class="card" data-id="${r.id}">
      <div class="card-title"><span class="tag">${esc(r.rtype)}</span>#${r.id} — ${esc(r.title)}</div>
      <div class="card-sub">Filed by ${esc(r.author)}${r.author_callsign ? ' · ' + esc(r.author_callsign) : ''} · ${esc(r.created || '')}</div>
    </div>`).join('') : '<div class="empty">No reports found.</div>';
  $('repResults').querySelectorAll('.card').forEach(el =>
    el.addEventListener('click', () => openReport(el.dataset.id)));
}

async function openReport(id) {
  const box = $('repView');
  box.classList.remove('hidden');
  box.innerHTML = '<div class="empty">Loading…</div>';
  const d = await request('getReport', { id });
  const r = d.report;
  if (!r) { box.innerHTML = '<div class="empty">Report not found.</div>'; return; }
  box.innerHTML = `
    <div class="panel">
      <h3><span class="tag">${esc(r.rtype)}</span>#${r.id} — ${esc(r.title)}</h3>
      <div class="card-sub">Filed by ${esc(r.author)}${r.author_callsign ? ' · ' + esc(r.author_callsign) : ''} · ${esc(r.created || '')}</div>
      <div class="section-title">Involved</div>
      <div class="chiprow">${(r.involved || []).map(c => `<span class="chip">${esc(c.name)}</span>`).join('') || '<span class="muted small">No persons attached.</span>'}</div>
      <div class="section-title">Report</div>
      <div class="card-body" style="white-space:pre-wrap">${esc(r.content)}</div>
    </div>`;
}

/* ─────────────────── Command ─────────────────── */
$('cmdPostBtn').addEventListener('click', async () => {
  const r = await request('postUpdate', {
    kind: $('cmdKind').value, title: $('cmdTitle').value.trim(), message: $('cmdMsg').value.trim()
  });
  if (r.ok) { msg('cmdPostMsg', 'Posted to dashboard.', true); $('cmdTitle').value = ''; $('cmdMsg').value = ''; }
  else msg('cmdPostMsg', r.error || 'Failed to post.', false);
});

$('cmdFeedBtn').addEventListener('click', async () => {
  const message = $('cmdFeedMsg').value.trim();
  if (!message) return;
  const r = await request('liveFeed', { message });
  if (r.ok) { msg('cmdFeedMsg2', 'Broadcast sent to all on-duty staff.', true); $('cmdFeedMsg').value = ''; }
  else msg('cmdFeedMsg2', r.error || 'Failed to broadcast.', false);
});

bindCivPicker('cmdCivSearch', 'cmdCivSearchBtn', 'cmdCivResults', c => {
  S.cmdSelected = c;
  $('cmdCivSelected').innerHTML = `<span class="chip">${esc(c.name)}<button id="cmdCivClear">✕</button></span>`;
  $('cmdCivClear').addEventListener('click', () => { S.cmdSelected = null; $('cmdCivSelected').innerHTML = ''; });
});

$('cmdWarrantBtn').addEventListener('click', async () => {
  if (!S.cmdSelected) return msg('cmdWarrantMsg', 'Select a civilian first.', false);
  const reason = $('cmdWarrantReason').value.trim();
  if (!reason) return msg('cmdWarrantMsg', 'A reason is required.', false);
  const r = await request('setWarrant', { citizenid: S.cmdSelected.citizenid, name: S.cmdSelected.name, reason });
  if (r.ok) {
    msg('cmdWarrantMsg', 'Warrant issued and broadcast.', true);
    $('cmdWarrantReason').value = ''; S.cmdSelected = null; $('cmdCivSelected').innerHTML = '';
  } else msg('cmdWarrantMsg', r.error || 'Failed to issue warrant.', false);
});

/* ─────────────────── Patients (UHS) ─────────────────── */
bindCivPicker('patSearchInput', 'patSearchBtn', 'patSearchResults', c => {
  S.patSelected = c;
  $('patSelected').innerHTML = `<span class="chip">${esc(c.name)}<button id="patClear">✕</button></span>`;
  $('patClear').addEventListener('click', () => { S.patSelected = null; $('patSelected').innerHTML = ''; });
});

$('patSaveBtn').addEventListener('click', async () => {
  if (!S.patSelected) return msg('patMsg', 'Select a patient first.', false);
  const r = await request('createPatient', {
    citizenid: S.patSelected.citizenid, name: S.patSelected.name,
    bloodType: $('patBlood').value, staff: $('patStaff').value.trim(),
    medications: $('patMeds').value.trim(), treatment: $('patTreatment').value.trim(),
    notes: $('patNotes').value.trim()
  });
  if (r.ok) {
    msg('patMsg', `Patient record #${r.id} saved.`, true);
    ['patStaff', 'patMeds', 'patTreatment', 'patNotes'].forEach(id => $(id).value = '');
    S.patSelected = null; $('patSelected').innerHTML = '';
  } else msg('patMsg', r.error || 'Could not save record.', false);
});

const runPatRecSearch = async () => {
  $('patRecResults').innerHTML = '<div class="empty">Searching…</div>';
  const d = await request('searchPatients', { term: $('patRecSearch').value.trim() });
  const res = d.results || [];
  $('patRecResults').innerHTML = res.length ? res.map(p => `
    <div class="card static">
      <div class="card-title"><span class="tag ok">${esc(p.blood_type || '—')}</span>${esc(p.name)}</div>
      <div class="card-sub">Recorded by ${esc(p.author)} · ${esc(p.created || '')}</div>
      <div class="card-body">Staff: ${esc(p.staff || '—')}\nMedications: ${esc(p.medications || '—')}\nFollow-up: ${esc(p.treatment || '—')}\nNotes: ${esc(p.notes || '—')}</div>
    </div>`).join('') : '<div class="empty">No patient records found.</div>';
};
$('patRecSearchBtn').addEventListener('click', runPatRecSearch);
$('patRecSearch').addEventListener('keyup', e => { if (e.key === 'Enter') runPatRecSearch(); });

/* ─────────────────── Settings ─────────────────── */
let pickedMode = 'default';

function loadSettingsPage() {
  $('setCallsign').value = S.callsign || '';
  pickedMode = (S.savedTheme && S.savedTheme.mode) || 'default';
  if (S.savedTheme && S.savedTheme.header) $('setHeaderColor').value = S.savedTheme.header;
  if (S.savedTheme && S.savedTheme.background) $('setBgColor').value = S.savedTheme.background;
  syncThemeButtons();
}

function syncThemeButtons() {
  document.querySelectorAll('.theme-pick').forEach(b =>
    b.classList.toggle('selected', b.dataset.theme === pickedMode));
  $('customColors').classList.toggle('hidden', pickedMode !== 'custom');
}

document.querySelectorAll('.theme-pick').forEach(btn =>
  btn.addEventListener('click', () => {
    pickedMode = btn.dataset.theme;
    syncThemeButtons();
    previewTheme();
  }));

['setHeaderColor', 'setBgColor'].forEach(id =>
  $(id).addEventListener('input', previewTheme));

function currentThemeSelection() {
  if (pickedMode === 'default') return null;
  return {
    mode: pickedMode,
    header: $('setHeaderColor').value,
    background: $('setBgColor').value
  };
}

function previewTheme() {
  S.savedTheme = currentThemeSelection();
  applyTheme();
}

$('setSaveBtn').addEventListener('click', async () => {
  S.callsign = $('setCallsign').value.trim();
  S.savedTheme = currentThemeSelection();
  const r = await request('saveSettings', { callsign: S.callsign, theme: S.savedTheme });
  if (r.ok) {
    $('callsignChip').textContent = S.callsign || 'NO CALLSIGN';
    applyTheme();
    msg('setMsg', 'Settings saved.', true);
  } else msg('setMsg', r.error || 'Could not save settings.', false);
});

$('setResetBtn').addEventListener('click', async () => {
  pickedMode = 'default';
  S.savedTheme = null;
  syncThemeButtons();
  applyTheme();
  const r = await request('saveSettings', { callsign: $('setCallsign').value.trim(), theme: null });
  msg('setMsg', r.ok ? 'Reset to department default.' : 'Could not reset.', !!r.ok);
});
