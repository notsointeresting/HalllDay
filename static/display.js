function setDisplay(inUse, name, elapsed, overdue, kioskSuspended) {
  const panel = document.getElementById('displayPanel');
  panel.classList.remove('red', 'green', 'yellow');
  const icon = document.getElementById('displayIcon');
  const title = document.getElementById('displayTitle');
  const subtitle = document.getElementById('displaySubtitle');

  // Check if kiosk is suspended first
  if (kioskSuspended) {
    panel.classList.add('red');
    document.body.classList.remove('bg-green', 'bg-yellow');
    document.body.classList.add('bg-red');
    icon.textContent = 'block';
    title.textContent = 'KIOSK SUSPENDED';
    subtitle.textContent = 'Contact administrator to resume service';
    return;
  }

  if (inUse) {
    panel.classList.add(overdue ? 'yellow' : 'red');
    document.body.classList.remove('bg-green', 'bg-red', 'bg-yellow');
    document.body.classList.add(overdue ? 'bg-yellow' : 'bg-red');
    icon.textContent = overdue ? 'alarm' : 'timer';
    title.textContent = overdue ? 'OVERDUE' : 'IN USE';
    const mins = Math.floor((elapsed || 0) / 60);
    const secs = (elapsed || 0) % 60;
    subtitle.textContent = `${name} • ${mins}:${secs.toString().padStart(2, '0')}`;
  } else {
    panel.classList.add('green');
    document.body.classList.remove('bg-red', 'bg-yellow');
    document.body.classList.add('bg-green');
    icon.textContent = 'check_circle';
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
        setDisplay(!!j.in_use, j.name || '', j.elapsed || 0, !!j.overdue, !!j.kiosk_suspended);
      };
      es.onerror = () => {
        es.close();
        showOffline();
        setTimeout(connect, backoff);
        backoff = Math.min(maxBackoff, backoff * 2);
      };
    } catch (e) {
      showOffline();
      setTimeout(connect, backoff);
      backoff = Math.min(maxBackoff, backoff * 2);
    }
  }

  function showOffline() {
    const panel = document.getElementById('displayPanel');
    panel.classList.remove('red', 'green'); panel.classList.add('yellow');
    document.getElementById('displayIcon').textContent = 'wifi_off';
    document.getElementById('displayTitle').textContent = 'Offline';
    document.getElementById('displaySubtitle').textContent = 'Trying to reconnect...';
  }

  connect();
}

if ('EventSource' in window) {
  startSSE();
} else {
  // fallback to polling
  (async function poll() {
    try {
      const r = await fetch('/api/status');
      const j = await r.json();
      setDisplay(j.in_use, j.name || '', j.elapsed || 0, !!j.overdue, !!j.kiosk_suspended);
    } catch (e) { }
    setTimeout(poll, 1000);
  })();
}
