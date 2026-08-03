const $ = id => document.getElementById(id);

function iconFile(item) { return `images/${item.icon || 'radio'}.svg`; }

function post(path, body) {
  fetch(`https://${GetParentResourceName()}/${path}`, { method: 'POST', body: JSON.stringify(body || {}) });
}

function renderGrid(catalog) {
  const grid = $('grid');
  grid.innerHTML = '';
  catalog.forEach(item => {
    const card = document.createElement('div');
    card.className = 'card' + (!item.unlocked ? ' locked' : '') + (item.owned ? ' owned' : '');

    const lock = !item.unlocked ? `<span class="lock">🔒</span>` : '';
    const req = !item.unlocked ? `<div class="req">Requires rank ${item.minGrade}+</div>` : '';

    let btn;
    if (!item.unlocked) {
      btn = `<button disabled>Locked</button>`;
    } else if (item.owned) {
      btn = `<button class="return" data-action="return" data-name="${item.name}">Return</button>`;
    } else {
      btn = `<button class="draw" data-action="draw" data-name="${item.name}">Draw</button>`;
    }

    card.innerHTML = `
      ${lock}
      <img class="icon" src="${iconFile(item)}" alt="">
      <div class="label">${item.label}</div>
      ${req}
      ${btn}
    `;
    grid.appendChild(card);
  });
}

document.addEventListener('click', e => {
  const btn = e.target.closest('button[data-action]');
  if (!btn) return;
  const name = btn.dataset.name;
  if (btn.dataset.action === 'draw') post('drawItem', { name });
  else if (btn.dataset.action === 'return') post('returnItem', { name });
});

$('btn-loadout').onclick = () => post('drawLoadout');
$('btn-return-all').onclick = () => post('returnLoadout');

function close() {
  $('wrap').classList.add('hidden');
  post('close');
}

document.addEventListener('keydown', e => {
  if ((e.key === 'Escape' || e.key === 'Tab') && !$('wrap').classList.contains('hidden')) {
    e.preventDefault();
    close();
  }
});

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') {
    $('rank').textContent = data.rankLabel || '—';
    $('arv-badge').classList.toggle('hidden', !data.isArmedResponse);
    renderGrid(data.catalog || []);
    $('wrap').classList.remove('hidden');
  } else if (data.action === 'close') {
    $('wrap').classList.add('hidden');
  }
});
