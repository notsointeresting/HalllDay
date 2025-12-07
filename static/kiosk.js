const hidden = document.getElementById('hiddenInput');
hidden.focus();

let buffer = '';

function setPanel(state, title, subtitle, icon) {
  const panel = document.getElementById('statusPanel');
  panel.classList.remove('red', 'yellow', 'green', 'processing');
  panel.classList.add(state);
  // swap body bg for visibility
  document.body.classList.remove('bg-green', 'bg-red', 'bg-yellow');
  if (state === 'green') document.body.classList.add('bg-green');
  if (state === 'red') document.body.classList.add('bg-red');
  if (state === 'yellow') document.body.classList.add('bg-yellow');
  document.getElementById('statusTitle').textContent = title;
  document.getElementById('statusSubtitle').textContent = subtitle || '';

  // Update icon if provided, otherwise infer from state
  const iconEl = panel.querySelector('.icon');
  if (icon) {
    iconEl.textContent = icon;
  } else {
    // Fallback defaults
    if (state === 'green') iconEl.textContent = 'check_circle';
    if (state === 'red') iconEl.textContent = 'do_not_disturb_on';
    if (state === 'yellow') iconEl.textContent = 'hourglass_empty';
  }
}

// Sound System using Web Audio API for expressive, non-fatiguing sounds
const SoundSystem = {
  ctx: null,

  init() {
    if (!this.ctx) {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  },

  // Play a tone with ADSR envelope
  playTone(freq, type, duration, startTime = 0, volume = 0.1) {
    this.init();
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = type;
    osc.frequency.setValueAtTime(freq, this.ctx.currentTime + startTime);

    gain.gain.setValueAtTime(0, this.ctx.currentTime + startTime);
    gain.gain.linearRampToValueAtTime(volume, this.ctx.currentTime + startTime + 0.05); // Attack
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + startTime + duration); // Decay

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(this.ctx.currentTime + startTime);
    osc.stop(this.ctx.currentTime + startTime + duration);
  },

  // Happy, rising major scale chime (For "Go", "Success")
  playSuccessOut() {
    this.playTone(523.25, 'sine', 0.6, 0.0); // C5
    this.playTone(659.25, 'sine', 0.6, 0.1); // E5
    this.playTone(783.99, 'sine', 0.8, 0.2); // G5
  },

  // Grounding, resolving chime (For "Return", "Back")
  playSuccessIn() {
    this.playTone(783.99, 'sine', 0.5, 0.0); // G5
    this.playTone(659.25, 'sine', 0.5, 0.1); // E5
    this.playTone(523.25, 'sine', 0.8, 0.2); // C5
  },

  // Softer warning chord (For errors, unknown ID)
  playError() {
    this.init();
    // Play a diminished triad for uncertainty/error
    this.playTone(300, 'triangle', 0.4, 0.0, 0.15);
    this.playTone(350, 'triangle', 0.4, 0.05, 0.15); // Dissonant
  },

  // Severe warning (Banned)
  playAlert() {
    this.init();
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(150, this.ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(100, this.ctx.currentTime + 0.5); // Slide down

    gain.gain.setValueAtTime(0.2, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.8);

    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start();
    osc.stop(this.ctx.currentTime + 0.8);
  },

  // Subtle interaction sound
  playProcessing() {
    this.playTone(800, 'sine', 0.1, 0, 0.05);
  }
};


let denyTimeout;
let resetTimeout;

// Toggle kiosk suspension (no password required for quick access)
async function toggleKioskSuspension() {
  try {
    const response = await fetch('/api/toggle_kiosk_suspend_quick', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });

    const result = await response.json();

    if (response.ok && result.ok) {
      // Show success message
      const status = result.suspended ? 'SUSPENDED' : 'RESUMED';
      setPanel(result.suspended ? 'red' : 'green',
        result.suspended ? 'Suspended' : 'Resumed',
        result.message || `Kiosk is ${status.toLowerCase()}`,
        result.suspended ? 'block' : 'check_circle');

      if (result.suspended) SoundSystem.playError();
      else SoundSystem.playSuccessIn(); // Sounds like "system restored"

      // Refresh status after 2 seconds
      setTimeout(async () => {
        try {
          const sr = await fetch('/api/status');
          const sj = await sr.json();
          setFromStatus(sj);
        } catch (e) { }
      }, 2000);
    } else {
      // Show error
      alert(result.message || 'Failed to toggle kiosk suspension');
    }
  } catch (e) {
    console.error('Error toggling kiosk suspension:', e);
    alert('Network error - could not toggle kiosk suspension');
  }
}

// Centralized code processing function used by both scanner and numpad
function processCode(code) {
  if (!code) return;

  // New Processing State: "processing" class instead of yellow
  const panel = document.getElementById('statusPanel');
  panel.className = 'expressive-container processing';

  // Minimal text for processing
  document.getElementById('statusTitle').textContent = '';
  document.getElementById('statusSubtitle').textContent = 'Scanning...';
  // Use a spinner or hourglass
  panel.querySelector('.icon').textContent = 'hourglass_top';

  SoundSystem.playProcessing();

  fetch('/api/scan', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code })
  }).then(async r => {
    let j = {};
    try { j = await r.json(); } catch (e) { }
    if (!r.ok) {
      console.error('scan error', r.status, j);
      if (r.status === 403 && j.action === 'banned') {
        // BANNED STUDENT - Show scary red warning
        clearTimeout(resetTimeout);
        setPanel('red', 'BANNED', j.message || 'See Teacher', 'block');

        SoundSystem.playAlert();
        setTimeout(() => SoundSystem.playAlert(), 600);

        // Hold message for longer so teacher can see
        resetTimeout = setTimeout(async () => {
          try {
            const sr = await fetch('/api/status');
            const sj = await sr.json();
            setFromStatus(sj);
          } catch (e) { }
        }, 5000);
      } else if (r.status === 403) {
        setPanel('red', 'Suspended', j.message || 'Ask Admin', 'block');
        SoundSystem.playError();
      } else if (r.status === 404) {
        // Unknown student ID
        clearTimeout(resetTimeout);
        setPanel('yellow', 'Not Found', (j.message || 'Try again'), 'help');
        SoundSystem.playError();
        resetTimeout = setTimeout(async () => {
          try {
            const sr = await fetch('/api/status');
            const sj = await sr.json();
            setFromStatus(sj);
          } catch (e) { }
        }, 3500);
      } else {
        clearTimeout(resetTimeout);
        setPanel('yellow', 'Service issue', j.message || `Status ${r.status}`, 'warning');
        SoundSystem.playError();
        resetTimeout = setTimeout(async () => {
          try {
            const sr = await fetch('/api/status');
            const sj = await sr.json();
            setFromStatus(sj);
          } catch (e) { }
        }, 3500);
      }
      return;
    }
    if (!j.ok && j.action === 'denied') {
      clearTimeout(denyTimeout);
      setPanel('red', 'In Use', 'Wait for return', 'timer');
      SoundSystem.playError();
      return;
    }
    if (j.ok && j.action === 'started') {
      setPanel('red', 'In Use', `${j.name} is out`, 'timer');
      SoundSystem.playSuccessOut();
    } else if (j.ok && j.action === 'ended') {
      setPanel('green', 'Returned', `${j.name} is back`, 'check_circle');
      SoundSystem.playSuccessIn();
      // Auto-reset to idle after 5 seconds
      resetTimeout = setTimeout(async () => {
        try {
          const sr = await fetch('/api/status');
          const sj = await sr.json();
          setFromStatus(sj);
        } catch (e) { }
      }, 5000);
    } else {
      setPanel('yellow', 'Check Scanner', j.message || 'Unknown response', 'help');
      SoundSystem.playError();
    }
  }).catch(e => {
    console.error('network error', e);
    setPanel('yellow', 'Network issue', 'Try again.', 'wifi_off');
    SoundSystem.playError();
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
function setFromStatus(j) {
  if (j.kiosk_suspended) {
    setPanel('red', 'Suspended', 'Ask Admin', 'block');
    return;
  }

  if (j.in_use) {
    const mins = Math.floor((j.elapsed || 0) / 60);
    const secs = (j.elapsed || 0) % 60;
    if (j.overdue) {
      setPanel('yellow', 'Overdue', `${j.name} • ${mins}:${secs.toString().padStart(2, '0')}`, 'alarm');
    } else {
      setPanel('red', 'In Use', `${j.name} • ${mins}:${secs.toString().padStart(2, '0')}`, 'timer');
    }
  } else {
    setPanel('green', 'Scan Badge', '', 'check_circle');
  }
}

if ('EventSource' in window) {
  try {
    const es = new EventSource('/events');
    es.onmessage = (evt) => {
      const j = JSON.parse(evt.data || '{}');
      setFromStatus(j);
    };
  } catch (e) {/* no-op */ }
} else {
  // fallback polling
  (async function poll() {
    try {
      const r = await fetch('/api/status');
      const j = await r.json();
      setFromStatus(j);
    } catch (e) { }
    setTimeout(poll, 1000);
  })();
}
