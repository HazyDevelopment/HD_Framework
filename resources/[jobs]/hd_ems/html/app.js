const $ = id => document.getElementById(id);

function fmt(ms) {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  return `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

window.addEventListener('message', ({ data }) => {
  if (data.action === 'show') {
    $('vignette').classList.remove('hidden');
    $('panel').classList.remove('hidden');
  } else if (data.action === 'tick') {
    $('timer').textContent = data.elapsedMs < 0 ? 'Getting up...' : fmt(data.elapsedMs);
  } else if (data.action === 'hide') {
    $('vignette').classList.add('hidden');
    $('panel').classList.add('hidden');
  }
});
