const hidden = document.getElementById('hiddenInput');
hidden.focus();

let buffer = '';
let lastTime = 0;
const THRESHOLD_MS = 50; // scans are fast; keystrokes slower

function setPanel(state, title, subtitle) {
  const panel = document.getElementById('statusPanel');
  panel.classList.remove('red', 'yellow', 'green');
  panel.classList.add(state);
  document.getElementById('statusTitle').textContent = title;
  document.getElementById('statusSubtitle').textContent = subtitle || '';
}

function beep(freq=880, ms=120) {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.connect(g); g.connect(ctx.destination);
    o.frequency.value = freq; o.type = 'sine';
    o.start();
    setTimeout(()=>{o.stop(); ctx.close();}, ms);
  } catch {}
}

document.addEventListener('keydown', (e) => {
  const now = performance.now();
  if (now - lastTime > THRESHOLD_MS) buffer = ''; // reset if too slow
  lastTime = now;

  if (e.key === 'Enter') {
    const code = buffer.trim();
    buffer = '';
    if (!code) return;

    setPanel('yellow', 'Pass Recognized!', 'Redirecting to student ID entry...');

    fetch('/api/scan', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({code})
    }).then(r => r.json()).then(j => {
      if (!j.ok && j.action === 'denied') {
        setPanel('red', 'IN USE', j.message);
        beep(200, 200);
        return;
      }
      if (j.ok && j.action === 'started') {
        setPanel('red', 'IN USE', `${j.name} is out. Scan to return.`);
        beep(700, 100);
      } else if (j.ok && j.action === 'ended') {
        setPanel('green', 'Available', `${j.name} returned.`);
        beep(1000, 120);
      } else {
        setPanel('yellow', 'Check Scanner', j.message || 'Unknown response');
      }
    }).catch(() => setPanel('yellow', 'Network issue', 'Try again.'));

  } else {
    // accumulate characters (digits or general)
    if (e.key.length === 1) buffer += e.key;
  }
});
