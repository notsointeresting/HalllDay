const hidden = document.getElementById('hiddenInput');
hidden.focus();

let buffer = '';
let lastTime = 0;
const THRESHOLD_MS = 50; // scans are fast; keystrokes slower

function setPanel(state, title, subtitle) {
  const panel = document.getElementById('statusPanel');
  panel.classList.remove('red', 'yellow', 'green');
  panel.classList.add(state);
  // swap body bg for visibility
  document.body.classList.remove('bg-green','bg-red','bg-yellow');
  if (state === 'green') document.body.classList.add('bg-green');
  if (state === 'red') document.body.classList.add('bg-red');
  if (state === 'yellow') document.body.classList.add('bg-yellow');
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

let denyTimeout;
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
    }).then(r => {
      if (r.status === 403) {
        return r.json().then(j => {
          setPanel('red', 'KIOSK SUSPENDED', j.message || 'Contact administrator to resume service.');
          beep(200, 300);
        });
      }
      return r.json().then(j => {
        if (!j.ok && j.action === 'denied') {
          clearTimeout(denyTimeout);
          setPanel('red', 'IN USE', j.message);
          denyTimeout = setTimeout(() => {
            setPanel('red', 'IN USE', 'Please wait until the pass is returned.');
          }, 2500);
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
      });
    }).catch(() => setPanel('yellow', 'Network issue', 'Try again.'));

  } else {
    // accumulate characters (digits or general)
    if (e.key.length === 1) buffer += e.key;
  }
});

// Keep focus and show friendly hint if idle
setInterval(() => hidden.focus(), 3000);

// Subscribe to status via SSE to mirror display behavior (full-bleed colors + elapsed/overdue)
function setFromStatus(j){
  if (j.kiosk_suspended) {
    setPanel('red', 'KIOSK SUSPENDED', 'Contact administrator to resume service.');
    return;
  }
  
  if (j.in_use) {
    const mins = Math.floor((j.elapsed||0)/60);
    const secs = (j.elapsed||0)%60;
    if (j.overdue) {
      setPanel('yellow', 'OVERDUE', `${j.name} • ${mins}:${secs.toString().padStart(2,'0')}`);
    } else {
      setPanel('red', 'IN USE', `${j.name} • ${mins}:${secs.toString().padStart(2,'0')}`);
    }
  } else {
    setPanel('green', 'Available', 'Scan your student ID to check out.');
  }
}

if ('EventSource' in window) {
  try{
    const es = new EventSource('/events');
    es.onmessage = (evt)=>{
      const j = JSON.parse(evt.data||'{}');
      setFromStatus(j);
    };
  }catch(e){/* no-op */}
} else {
  // fallback polling
  (async function poll(){
    try {
      const r = await fetch('/api/status');
      const j = await r.json();
      setFromStatus(j);
    } catch(e) {}
    setTimeout(poll, 1000);
  })();
}
