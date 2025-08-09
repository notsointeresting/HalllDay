function setDisplay(inUse, name, elapsed, overdue) {
  const panel = document.getElementById('displayPanel');
  panel.classList.remove('red','green','yellow');
  const icon = document.getElementById('displayIcon');
  const title = document.getElementById('displayTitle');
  const subtitle = document.getElementById('displaySubtitle');

  if (inUse) {
    panel.classList.add(overdue ? 'yellow' : 'red');
    icon.textContent = overdue ? '⏰' : '⛔';
    title.textContent = overdue ? 'OVERDUE' : 'IN USE';
    const mins = Math.floor((elapsed||0)/60);
    const secs = (elapsed||0)%60;
    subtitle.textContent = `${name} • ${mins}:${secs.toString().padStart(2,'0')}`;
  } else {
    panel.classList.add('green');
    icon.textContent = '✔';
    title.textContent = 'Available';
    subtitle.textContent = 'Scan to check out';
  }
}

function startSSE() {
  let es;
  let backoff = 1000;
  const maxBackoff = 15000;

  function connect() {
    try {
      es = new EventSource('/events');
      es.onmessage = (evt) => {
        backoff = 1000;
        const j = JSON.parse(evt.data || '{}');
        setDisplay(!!j.in_use, j.name || '', j.elapsed || 0, !!j.overdue);
      };
      es.onerror = () => {
        es.close();
        showOffline();
        setTimeout(connect, backoff);
        backoff = Math.min(maxBackoff, backoff * 2);
      };
    } catch(e) {
      showOffline();
      setTimeout(connect, backoff);
      backoff = Math.min(maxBackoff, backoff * 2);
    }
  }

  function showOffline() {
    const panel = document.getElementById('displayPanel');
    panel.classList.remove('red','green'); panel.classList.add('yellow');
    document.getElementById('displayIcon').textContent = '⚠';
    document.getElementById('displayTitle').textContent = 'Offline';
    document.getElementById('displaySubtitle').textContent = 'Trying to reconnect...';
  }

  connect();
}

if ('EventSource' in window) {
  startSSE();
} else {
  // fallback to polling
  (async function poll(){
    try {
      const r = await fetch('/api/status');
      const j = await r.json();
      setDisplay(j.in_use, j.name || '', j.elapsed || 0, !!j.overdue);
    } catch(e) {}
    setTimeout(poll, 1000);
  })();
}
