// --- SPRING PHYSICS ENGINE ---
class Spring {
  constructor(stiffness = 120, damping = 16, mass = 1) {
    this.stiffness = stiffness;
    this.damping = damping;
    this.mass = mass;
    this.current = 0;
    this.target = 0;
    this.velocity = 0;
  }

  update(dt) {
    const displacement = this.current - this.target;
    // Apply epsilon to avoid endless micro-jitters
    if (Math.abs(displacement) < 0.001 && Math.abs(this.velocity) < 0.001) {
      this.current = this.target;
      this.velocity = 0;
      return;
    }
    const force = -this.stiffness * displacement - this.damping * this.velocity;
    const acceleration = force / this.mass;
    this.velocity += acceleration * dt;
    this.current += this.velocity * dt;
  }

  set(val) {
    this.current = val;
    this.target = val;
    this.velocity = 0;
  }
}

// --- SVG PATHS ---
// 12-point Cookie (Squircle-ish)
const PATH_COOKIE = "M230.389 50.473C293.109 23.2328 356.767 86.8908 329.527 149.611L325.023 159.981C316.707 179.13 316.707 200.87 325.023 220.019L329.527 230.389C356.767 293.109 293.109 356.767 230.389 329.527L220.019 325.023C200.87 316.707 179.13 316.707 159.981 325.023L149.611 329.527C86.8908 356.767 23.2328 293.109 50.473 230.389L54.9768 220.019C63.2934 200.87 63.2934 179.13 54.9768 159.981L50.473 149.611C23.2328 86.8908 86.8908 23.2328 149.611 50.473L159.981 54.9768C179.13 63.2934 200.87 63.2934 220.019 54.9768L230.389 50.473Z";
// Star/Burst Shape
const PATH_BURST = "M187.293 26.6421C188.056 25.2785 188.437 24.5966 188.902 24.3108C189.575 23.8964 190.425 23.8964 191.098 24.3108C191.563 24.5966 191.944 25.2785 192.707 26.6421L218.917 73.4925C219.386 74.3306 219.62 74.7497 219.937 75.0046C220.396 75.3737 220.989 75.5326 221.571 75.4425C221.973 75.3802 222.386 75.1345 223.211 74.6431L269.335 47.1743C270.677 46.3748 271.348 45.9751 271.893 45.9598C272.684 45.9377 273.42 46.3624 273.796 47.0581C274.055 47.5379 274.045 48.3191 274.023 49.8814L273.296 103.56C273.283 104.52 273.277 105 273.424 105.38C273.637 105.929 274.071 106.363 274.62 106.576C275 106.723 275.48 106.717 276.44 106.704L330.119 105.977C331.681 105.955 332.462 105.945 332.942 106.204C333.638 106.58 334.062 107.316 334.04 108.107C334.025 108.652 333.625 109.323 332.826 110.665L305.357 156.789C304.865 157.614 304.62 158.027 304.557 158.429C304.467 159.011 304.62 159.604 304.995 160.063C305.25 160.38 305.669 160.614 306.508 161.083L353.358 187.293C354.722 188.056 355.403 188.437 355.689 188.902C356.104 189.575 356.104 190.425 355.689 191.098C355.403 191.563 354.722 191.944 353.358 192.707L306.508 218.917C305.669 219.386 305.25 219.62 304.995 219.937C304.62 220.396 304.467 220.989 304.557 221.571C304.62 221.973 304.865 222.386 305.357 223.211L332.826 269.335C333.625 270.677 334.025 271.348 334.04 271.893C334.062 272.684 333.638 273.42 332.942 273.796C332.462 274.055 331.681 274.045 330.119 274.023L276.44 273.296C275.48 273.283 275 273.277 274.62 273.424C274.071 273.637 273.637 274.071 273.424 274.62C273.277 275 273.283 275.48 273.296 276.44L274.023 330.119C274.045 331.681 274.055 332.462 273.796 332.942C273.42 333.638 272.684 334.062 271.893 334.04C271.348 334.025 270.677 333.625 269.335L223.211 305.357C222.386 304.865 221.973 304.62 221.571 304.557C220.989 304.467 220.396 304.626 219.937 304.995C219.62 305.25 219.386 305.669 218.917 306.508L192.707 353.358C191.944 354.722 191.563 355.403 191.098 355.689C190.425 356.104 189.575 356.104 188.902 355.689C188.437 355.403 188.056 354.722 187.293 353.358L161.083 306.508C160.614 305.669 160.38 305.25 160.063 304.995C159.604 304.626 159.011 304.467 158.429 304.557C158.027 304.62 157.614 304.865 156.789 305.357L110.665 332.826C109.323 333.625 108.652 334.025 108.107 334.04C107.316 334.062 106.58 333.638 106.204 332.942C105.945 332.462 105.955 331.681 105.977 330.119L106.704 276.44C106.717 275.48 106.723 275 106.576 274.62C106.363 274.071 105.929 273.637 105.38 273.424C105 273.277 104.52 273.283 103.56 273.296L49.8814 274.023C48.3191 274.045 47.5379 274.055 47.0581 273.796C46.3624 273.42 45.9377 272.684 45.9598 271.893C45.9751 271.348 46.3748 270.677 47.1743 269.335L74.6431 223.211C75.1345 222.386 75.3802 221.973 75.4425 221.571C75.5326 220.989 75.3737 220.396 75.0046 219.937C74.7497 219.62 74.3306 219.386 73.4925 218.917L26.6421 192.707C25.2785 191.944 24.5966 191.563 24.3108 191.098C23.8964 190.425 23.8964 189.575 24.3108 188.902C24.5966 188.437 25.2785 188.056 26.6421 187.293L73.4925 161.083C74.3306 160.614 74.7497 160.38 75.0046 160.063C75.3737 159.604 75.5326 159.011 75.4425 158.429C75.3802 158.027 75.1345 157.614 74.6431 156.789L47.1743 110.665C46.3748 109.323 45.9751 108.652 45.9598 108.107C45.9377 107.316 46.3624 106.58 47.0581 106.204C47.5379 105.945 48.3191 105.955 49.8814 105.977L103.56 106.704C104.52 106.717 105 106.723 105.38 106.576C105.929 106.363 106.363 105.929 106.576 105.38C106.723 105.38 106.717 104.52 106.704 103.56L105.977 49.8814C105.955 48.3191 105.945 47.5379 106.204 47.0581C106.58 46.3624 107.316 45.9377 108.107 45.9598C108.652 45.9751 109.323 46.3748 110.665 47.1743L156.789 74.6431C157.614 75.1345 158.027 75.3802 158.429 75.4425C159.011 75.5326 159.604 75.3737 160.063 75.0046C160.38 74.7497 160.614 74.3306 161.083 73.4925L187.293 26.6421Z";

// --- MULTI-BUBBLE SYSTEM ---

class Bubble {
  constructor(id, type = 'available') {
    this.id = id;
    this.type = type; // 'available', 'used', 'processing', 'banned', 'suspended'
    this.scaleSpring = new Spring(120, 14);
    this.xSpring = new Spring(100, 14); // Position X %
    this.ySpring = new Spring(100, 14); // Position Y %
    this.rotateSpring = new Spring(100, 12);

    // Initial state
    this.scaleSpring.set(0); // Start scale 0 to pop in
    this.xSpring.set(50);
    this.ySpring.set(50);

    this.currentPath = PATH_COOKIE;
    this.color = 'var(--color-green-container)';

    // DOM Element
    this.element = this.createDOM();
    document.getElementById('shape-container').appendChild(this.element);
  }

  createDOM() {
    const el = document.createElement('div');
    el.className = 'bubble-wrapper';
    el.style.position = 'absolute';
    el.style.left = '0';
    el.style.top = '0';
    el.style.width = '100%';
    el.style.height = '100%';
    el.style.pointerEvents = 'none'; // Keep background interaction-free

    // Inner structure: SVG + Content Overlay
    // Removed 'background-shape' class to avoid CSS transform conflicts
    el.innerHTML = `
      <svg class="bubble-svg" viewBox="0 0 380 380" fill="none"
        style="width: 100%; height: 100%; display: block;"
        xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid meet">
        <path d="${this.currentPath}" fill="${this.color}" />
      </svg>
      <div class="bubble-content" style="
        position: absolute; 
        top: 50%; 
        left: 50%; 
        transform: translate(-50%, -50%); 
        text-align: center; 
        width: 280px; 
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        color: var(--md-sys-color-on-surface);
        opacity: 0;
        transition: opacity 0.3s ease;
        pointer-events: none;
        font-family: 'Outfit', sans-serif;
      ">
        <div class="bubble-icon" style="font-family: 'Material Symbols Rounded'; font-size: 42px; margin-bottom: 8px;"></div>
        <div class="bubble-name" style="
          font-family: 'Outfit', sans-serif;
          font-size: 2rem; 
          font-weight: 700; 
          line-height: 1.1; 
          word-break: break-word; 
          text-shadow: 0 1px 2px rgba(0,0,0,0.05);
        "></div>
        <div class="bubble-timer" style="
          font-size: 1.5rem; 
          font-family: 'Outfit', sans-serif; 
          font-variant-numeric: tabular-nums; 
          opacity: 0.9; 
          margin-top: 6px; 
          font-weight: 600;
        "></div>
      </div>
    `;
    return el;
  }

  remove() {
    this.element.remove();
  }

  update(dt) {
    this.scaleSpring.update(dt);
    this.xSpring.update(dt);
    this.ySpring.update(dt);
    this.rotateSpring.update(dt);

    // Breathing for available state (Subtler)
    if (this.type === 'available' && Math.abs(this.scaleSpring.velocity) < 0.05) {
      const t = Date.now() / 3000; // Slower
      this.scaleSpring.target = 1.0 + Math.sin(t) * 0.005; // Very subtle
    }

    // Update DOM Transforms
    const scale = this.scaleSpring.current;
    if (scale < 0.01) {
      this.element.style.display = 'none';
      return;
    } else {
      this.element.style.display = 'block';
    }

    const x = this.xSpring.current;
    const y = this.ySpring.current;
    const rot = this.rotateSpring.current;

    // Move the wrapper
    this.element.style.transform = `translate(calc(${x}% - 50%), calc(${y}% - 50%)) scale(${scale})`;

    const svgEl = this.element.querySelector('.bubble-svg');
    if (svgEl) {
      // Rotate the SVG itself inside the wrapper
      svgEl.style.transform = `rotate(${rot}deg)`;
      svgEl.style.transformOrigin = 'center';
    }

    // Color/Path update
    const pathDom = this.element.querySelector('path');
    if (pathDom) {
      pathDom.setAttribute('d', this.currentPath);
      pathDom.style.fill = this.color;
      pathDom.style.transition = 'fill 0.3s ease';
    }
  }

  setTarget(x, y, scale, type, sessionData = null) {
    this.xSpring.target = x;
    this.ySpring.target = y;
    this.scaleSpring.target = scale;
    this.type = type;

    let targetPath = PATH_COOKIE;
    let targetColor = 'var(--color-green-container)';
    let showContent = false;
    let nameText = '';
    let timerText = '';
    let iconText = '';
    let textColor = 'var(--md-sys-color-on-green-container)';

    // Determine visuals based on type
    if (type === 'available') {
      targetPath = PATH_COOKIE;
      targetColor = 'var(--color-green-container)';
      textColor = 'var(--md-sys-color-on-green-container)';
    } else if (type === 'used') {
      targetPath = PATH_COOKIE;
      showContent = true;
      if (sessionData) {
        nameText = sessionData.name || 'Student';
        const mins = Math.floor((sessionData.elapsed || 0) / 60);
        const secs = (sessionData.elapsed || 0) % 60;
        timerText = `${mins}:${secs.toString().padStart(2, '0')}`;

        if (sessionData.overdue) {
          targetColor = 'var(--color-yellow-container)';
          textColor = 'var(--md-sys-color-on-yellow-container)';
          iconText = 'alarm';
        } else {
          targetColor = 'var(--color-red-container)';
          textColor = 'var(--md-sys-color-on-red-container)';
          iconText = 'timer';
        }
      }
    } else if (type === 'banned') {
      targetPath = PATH_BURST;
      targetColor = 'var(--color-red-container)';
      textColor = 'var(--md-sys-color-on-red-container)';
      showContent = true;
      nameText = 'BANNED';
      iconText = 'block';
    } else if (type === 'processing') {
      targetPath = PATH_COOKIE;
      targetColor = 'var(--md-sys-color-surface-variant)';
      textColor = 'var(--md-sys-color-on-surface-variant)';
    } else if (type === 'suspended') {
      targetPath = PATH_BURST;
      targetColor = 'var(--color-red-container)';
      textColor = 'var(--md-sys-color-on-red-container)';
      showContent = true;
      nameText = 'SUSPENDED';
      iconText = 'block';
    }

    // Just update properties, update() handles DOM
    this.currentPath = targetPath;
    this.color = targetColor;

    // Update Content
    const contentEl = this.element.querySelector('.bubble-content');
    if (contentEl) {
      contentEl.style.opacity = showContent ? '1' : '0';
      contentEl.style.color = textColor;
      this.element.querySelector('.bubble-name').textContent = nameText;
      this.element.querySelector('.bubble-timer').textContent = timerText;
      this.element.querySelector('.bubble-icon').textContent = iconText;
    }

    // Breathing logic moved to update()
  }
}

// Global Manager
const bubbleManager = {
  bubbles: [], // Array of Bubble instances

  // Sync bubbles with state
  sync(capacity, activeSessions, isSuspended, isBannedUser) {
    if (isSuspended || isBannedUser) {
      this.ensureBubbleCount(1);
      const b = this.bubbles[0];
      b.setTarget(50, 50, 1.0, isSuspended ? 'suspended' : 'banned');
      return;
    }

    const usedCount = activeSessions.length;
    const showAvailable = usedCount < capacity;
    const totalBubbles = usedCount + (showAvailable ? 1 : 0);

    this.ensureBubbleCount(totalBubbles);

    const layout = this.getLayout(totalBubbles);

    activeSessions.forEach((sess, i) => {
      const b = this.bubbles[i];
      const pos = layout[i];
      b.setTarget(pos.x, pos.y, pos.scale, 'used', sess);
    });

    if (showAvailable) {
      const idx = activeSessions.length;
      const b = this.bubbles[idx];
      const pos = layout[idx];

      if (b.scaleSpring.current === 0 && totalBubbles > 1) {
        const parent = this.bubbles[idx - 1] || this.bubbles[0];
        if (parent) {
          b.xSpring.current = parent.xSpring.current;
          b.ySpring.current = parent.ySpring.current;
        }
      }

      b.setTarget(pos.x, pos.y, pos.scale, 'available');
    }
  },

  ensureBubbleCount(count) {
    while (this.bubbles.length < count) {
      const b = new Bubble(Date.now() + Math.random());
      this.bubbles.push(b);
    }
    while (this.bubbles.length > count) {
      const b = this.bubbles.pop();
      b.remove();
    }
  },

  getLayout(count) {
    if (count <= 1) return [{ x: 50, y: 50, scale: 1.0 }];
    if (count === 2) return [
      { x: 35, y: 50, scale: 0.75 }, // L
      { x: 65, y: 50, scale: 0.75 }  // R
    ];
    if (count === 3) return [
      { x: 50, y: 35, scale: 0.6 }, // Top
      { x: 35, y: 65, scale: 0.6 }, // BL
      { x: 65, y: 65, scale: 0.6 }  // BR
    ];
    // Generic Grid for 4+
    const result = [];
    const cols = Math.ceil(Math.sqrt(count));
    const rows = Math.ceil(count / cols);
    const scale = 1.6 / Math.max(cols, rows);

    for (let i = 0; i < count; i++) {
      const r = Math.floor(i / cols);
      const c = i % cols;
      const rowHeight = 100 / rows;
      const colWidth = 100 / cols;
      const x = (c + 0.5) * colWidth;
      const y = (r + 0.5) * rowHeight;
      result.push({ x, y, scale });
    }
    return result;
  },

  update(dt) {
    this.bubbles.forEach(b => b.update(dt));
  }
};


// --- ANIMATION LOOP ---
let lastTime = 0;
function animate(time) {
  if (!lastTime) lastTime = time;
  const dt = (time - lastTime) / 1000;
  lastTime = time;
  const safeDt = Math.min(dt, 0.05);

  bubbleManager.update(safeDt);
  requestAnimationFrame(animate);
}
requestAnimationFrame(animate);

// --- UI LOGIC ---

function setPanel(state, title, subtitle, icon) {
  // Update Body Background
  document.body.classList.remove('bg-green', 'bg-red', 'bg-yellow');
  if (state === 'green') document.body.classList.add('bg-green');
  if (state === 'red') document.body.classList.add('bg-red');
  if (state === 'yellow') document.body.classList.add('bg-yellow');

  // Update Content
  const titleEl = document.getElementById('statusTitle');
  const subtitleEl = document.getElementById('statusSubtitle');
  const iconEl = document.querySelector('.icon');

  // Reset placement overrides
  subtitleEl.style.position = 'static';
  subtitleEl.style.bottom = 'auto';
  subtitleEl.style.left = 'auto';
  subtitleEl.style.width = 'auto';
  subtitleEl.style.transform = 'none';

  titleEl.textContent = title;
  subtitleEl.textContent = subtitle || '';
  iconEl.classList.remove('processing-spin');
  if (icon) {
    iconEl.textContent = icon;
    iconEl.style.display = 'block';
  } else {
    iconEl.style.display = 'none';
  }
}

// ... Sound System & Helpers ...
const SoundSystem = {
  // ... (unchanged) ...
  ctx: null,
  init() {
    if (!this.ctx) {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  },
  playTone(freq, type, duration, startTime = 0, volume = 0.1) {
    this.init();
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, this.ctx.currentTime + startTime);
    gain.gain.setValueAtTime(0, this.ctx.currentTime + startTime);
    gain.gain.linearRampToValueAtTime(volume, this.ctx.currentTime + startTime + 0.05);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + startTime + duration);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(this.ctx.currentTime + startTime);
    osc.stop(this.ctx.currentTime + startTime + duration);
  },
  playSuccessOut() {
    this.playTone(523.25, 'sine', 0.6, 0.0); // C5
    this.playTone(659.25, 'sine', 0.6, 0.1); // E5
    this.playTone(783.99, 'sine', 0.8, 0.2); // G5
  },
  playSuccessIn() {
    this.playTone(783.99, 'sine', 0.5, 0.0); // G5
    this.playTone(659.25, 'sine', 0.5, 0.1); // E5
    this.playTone(523.25, 'sine', 0.8, 0.2); // C5
  },
  playError() {
    this.init();
    this.playTone(300, 'triangle', 0.4, 0.0, 0.15);
    this.playTone(350, 'triangle', 0.4, 0.05, 0.15);
  },
  playAlert() {
    this.init();
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(150, this.ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(100, this.ctx.currentTime + 0.5);
    gain.gain.setValueAtTime(0.2, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.8);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start();
    osc.stop(this.ctx.currentTime + 0.8);
  },
  playProcessing() {
    this.playTone(800, 'sine', 0.1, 0, 0.05);
  }
};

let buffer = ''; // FIXED: Missing buffer variable
let denyTimeout;
let resetTimeout;

async function toggleKioskSuspension() {
  try {
    const token = window.HALLPASS_TOKEN || '';
    const response = await fetch('/api/toggle_kiosk_suspend_quick', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token })
    });
    const result = await response.json();
    if (response.ok && result.ok) {
      if (result.suspended) SoundSystem.playError();
      else SoundSystem.playSuccessIn();
      fetchStatus();
    }
  } catch (e) { console.error(e); }
}

function processCode(code) {
  if (!code) return;
  document.querySelector('.icon').classList.add('processing-spin');
  SoundSystem.playProcessing();

  const token = window.HALLPASS_TOKEN || '';
  fetch('/api/scan', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code, token })
  }).then(async r => {
    let j = {};
    try { j = await r.json(); } catch (e) { }

    if (!r.ok) {
      if (r.status === 403 && j.action === 'banned') {
        setPanel('red', 'BANNED', j.message || 'See Teacher', 'block');
        SoundSystem.playAlert();
      } else if (r.status === 403) {
        setPanel('red', 'Suspended', j.message || 'Ask Admin', 'block');
        SoundSystem.playError();
      } else if (r.status === 404) {
        setPanel('yellow', 'Not Found', 'Try again', 'help');
        SoundSystem.playError();
      } else {
        setPanel('yellow', 'Error', j.message || 'Service issue', 'warning');
        SoundSystem.playError();
      }
      setTimeout(fetchStatus, 3500);
      return;
    }

    if (j.ok) {
      if (j.action === 'started') {
        setPanel('red', 'Scanned Out', j.name, 'timer');
        SoundSystem.playSuccessOut();
      } else if (j.action === 'ended') {
        setPanel('green', 'Returned', j.name, 'check_circle');
        SoundSystem.playSuccessIn();
      }
      fetchStatus();
    } else {
      setPanel('yellow', 'Denied', j.message, 'block');
      SoundSystem.playError();
      setTimeout(fetchStatus, 3000);
    }
  }).catch(e => {
    console.error(e);
    setPanel('yellow', 'Network', 'Check connection', 'wifi_off');
    SoundSystem.playError();
  });
}

function setFromStatus(j) {
  const capacity = j.capacity || 1;
  const active = j.active_sessions || [];
  const kioskSuspended = j.kiosk_suspended;

  bubbleManager.sync(capacity, active, kioskSuspended, false);

  if (kioskSuspended) {
    setPanel('red', 'Suspended', 'Ask Teacher', 'block');
    return;
  }

  if (active.length === 0) {
    setPanel('green', 'Scan Badge', 'Ready', 'check_circle');
  } else if (active.length < capacity) {
    // In use but available
    setPanel('green', '', `${active.length} / ${capacity} In Use`, '');
  } else {
    // Full
    setPanel('red', '', 'Hall Pass Full', '');
  }

  // --- OVERLAP FIX: Move subtitle to bottom if active bubbles exist ---
  if (active.length > 0) {
    const subtitleEl = document.getElementById('statusSubtitle');
    subtitleEl.style.position = 'fixed';
    subtitleEl.style.bottom = '40px';
    subtitleEl.style.left = '0';
    subtitleEl.style.width = '100%';
    subtitleEl.style.textAlign = 'center';
  }
}

async function fetchStatus() {
  try {
    const token = window.HALLPASS_TOKEN || '';
    const query = token ? `?token=${encodeURIComponent(token)}` : '';
    const sr = await fetch('/api/status' + query);
    const sj = await sr.json();
    setFromStatus(sj);
  } catch (e) { }
}

document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    const code = buffer.trim();
    buffer = '';
    if (code) processCode(code);
  } else if (e.key.length === 1) {
    buffer += e.key;
  } else if (e.key === 'Backspace') {
    buffer = buffer.slice(0, -1);
  }
});

setInterval(() => hidden.focus(), 3000);

if ('EventSource' in window) {
  try {
    const token = window.HALLPASS_TOKEN || '';
    const query = token ? `?token=${encodeURIComponent(token)}` : '';
    const es = new EventSource('/events' + query);
    es.onmessage = (evt) => {
      const j = JSON.parse(evt.data || '{}');
      setFromStatus(j);
    };
  } catch (e) { }
} else {
  (async function poll() {
    await fetchStatus();
    setTimeout(poll, 1000);
  })();
}
