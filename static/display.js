\
function setDisplay(inUse, name, elapsed) {
  const panel = document.getElementById('displayPanel');
  panel.classList.remove('red','green','yellow');
  const icon = document.getElementById('displayIcon');
  const title = document.getElementById('displayTitle');
  const subtitle = document.getElementById('displaySubtitle');

  if (inUse) {
    panel.classList.add('red');
    icon.textContent = '⛔';
    title.textContent = 'IN USE';
    const mins = Math.floor(elapsed/60);
    const secs = elapsed%60;
    subtitle.textContent = `${name} • ${mins}:${secs.toString().padStart(2,'0')}`;
  } else {
    panel.classList.add('green');
    icon.textContent = '✔';
    title.textContent = 'Available';
    subtitle.textContent = 'Scan to check out';
  }
}

async function poll() {
  try {
    const r = await fetch('/api/status');
    const j = await r.json();
    setDisplay(j.in_use, j.name || '', j.elapsed || 0);
  } catch(e) {
    const panel = document.getElementById('displayPanel');
    panel.classList.remove('red','green'); panel.classList.add('yellow');
    document.getElementById('displayIcon').textContent = '⚠';
    document.getElementById('displayTitle').textContent = 'Offline';
    document.getElementById('displaySubtitle').textContent = 'Trying to reconnect...';
  } finally {
    setTimeout(poll, 1000);
  }
}
poll();
