const hidden = document.getElementById('hiddenInput');
hidden.focus();

let buffer = '';

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
let resetTimeout;

// Toggle kiosk suspension (no password required for quick access)
async function toggleKioskSuspension() {
  try {
    const response = await fetch('/api/toggle_kiosk_suspend_quick', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'}
    });
    
    const result = await response.json();
    
    if (response.ok && result.ok) {
      // Show success message
      const status = result.suspended ? 'SUSPENDED' : 'RESUMED';
      setPanel(result.suspended ? 'red' : 'green', 
               `Kiosk ${status}`, 
               result.message || `Kiosk has been ${status.toLowerCase()}`);
      beep(result.suspended ? 400 : 800, 200);
      
      // Refresh status after 2 seconds
      setTimeout(async () => {
        try {
          const sr = await fetch('/api/status');
          const sj = await sr.json();
          setFromStatus(sj);
        } catch(e) {}
      }, 2000);
    } else {
      // Show error
      alert(result.message || 'Failed to toggle kiosk suspension');
    }
  } catch(e) {
    console.error('Error toggling kiosk suspension:', e);
    alert('Network error - could not toggle kiosk suspension');
  }
}

// Centralized code processing function used by both scanner and numpad
function processCode(code) {
  if (!code) return;

  setPanel('yellow', 'Pass Recognized!', 'Processing...');

  fetch('/api/scan', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({code})
  }).then(async r => {
    let j = {};
    try { j = await r.json(); } catch(e) {}
    if (!r.ok) {
      console.error('scan error', r.status, j);
      if (r.status === 403 && j.action === 'banned') {
        // BANNED STUDENT - Show scary red warning with loud beep
        clearTimeout(resetTimeout);
        setPanel('red', '🚫 RESTROOM BANNED 🚫', j.message || 'RESTROOM PRIVILEGES SUSPENDED - SEE TEACHER');
        // Super loud scary beep (low frequency, long duration)
        beep(150, 800);  // Very low pitch, very long duration
        setTimeout(() => beep(150, 800), 900);  // Double beep for emphasis
        setTimeout(() => beep(150, 800), 1800);  // Triple beep!
        // Hold message for longer so teacher can see
        resetTimeout = setTimeout(async () => {
          try {
            const sr = await fetch('/api/status');
            const sj = await sr.json();
            setFromStatus(sj);
          } catch(e) {}
        }, 5000);  // 5 seconds to give teacher time to see
      } else if (r.status === 403) {
        setPanel('red', 'KIOSK SUSPENDED', j.message || 'Contact administrator to resume service.');
        beep(200, 300);
      } else if (r.status === 404) {
        // Unknown student ID
        clearTimeout(resetTimeout);
        setPanel('yellow', 'Student not recognized', (j.message || 'Please try again.')); 
        beep(220, 220);
        resetTimeout = setTimeout(async () => {
          try {
            const sr = await fetch('/api/status');
            const sj = await sr.json();
            setFromStatus(sj);
          } catch(e) {}
        }, 3500);
      } else {
        clearTimeout(resetTimeout);
        setPanel('yellow', 'Service issue', j.message || `Status ${r.status}`);
        resetTimeout = setTimeout(async () => {
          try {
            const sr = await fetch('/api/status');
            const sj = await sr.json();
            setFromStatus(sj);
          } catch(e) {}
        }, 3500);
      }
      return;
    }
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
  }).catch(e => {
    console.error('network error', e);
    setPanel('yellow', 'Network issue', 'Try again.');
  });
}

// Handle both barcode scanner and manual numpad entry
document.addEventListener('keydown', (e) => {
  // Keyboard shortcut: Ctrl+Shift+S to toggle kiosk suspension
  if (e.ctrlKey && e.shiftKey && e.key === 'S') {
    e.preventDefault();
    toggleKioskSuspension();
    return;
  }
  
  if (e.key === 'Enter') {
    const code = buffer.trim();
    buffer = '';
    if (code) processCode(code);
  } else if (e.key.length === 1) {
    // Accumulate any single character (digits, letters, etc.)
    buffer += e.key;
  } else if (e.key === 'Backspace') {
    // Allow corrections
    buffer = buffer.slice(0, -1);
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
    setPanel('green', 'Available', 'Scan your badge or type your student ID and press Enter');
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
