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
    const force = -this.stiffness * displacement - this.damping * this.velocity;
    const acceleration = force / this.mass;

    this.velocity += acceleration * dt;
    this.current += this.velocity * dt;

    if (Math.abs(this.velocity) < 0.001 && Math.abs(displacement) < 0.001) {
      this.current = this.target;
      this.velocity = 0;
    }
  }

  set(val) {
    this.current = val;
    this.target = val;
    this.velocity = 0;
  }
}

// --- SVG PATHS ---
const PATH_COOKIE = "M230.389 50.473C293.109 23.2328 356.767 86.8908 329.527 149.611L325.023 159.981C316.707 179.13 316.707 200.87 325.023 220.019L329.527 230.389C356.767 293.109 293.109 356.767 230.389 329.527L220.019 325.023C200.87 316.707 179.13 316.707 159.981 325.023L149.611 329.527C86.8908 356.767 23.2328 293.109 50.473 230.389L54.9768 220.019C63.2934 200.87 63.2934 179.13 54.9768 159.981L50.473 149.611C23.2328 86.8908 86.8908 23.2328 149.611 50.473L159.981 54.9768C179.13 63.2934 200.87 63.2934 220.019 54.9768L230.389 50.473Z";
const PATH_BURST = "M187.293 26.6421C188.056 25.2785 188.437 24.5966 188.902 24.3108C189.575 23.8964 190.425 23.8964 191.098 24.3108C191.563 24.5966 191.944 25.2785 192.707 26.6421L218.917 73.4925C219.386 74.3306 219.62 74.7497 219.937 75.0046C220.396 75.3737 220.989 75.5326 221.571 75.4425C221.973 75.3802 222.386 75.1345 223.211 74.6431L269.335 47.1743C270.677 46.3748 271.348 45.9751 271.893 45.9598C272.684 45.9377 273.42 46.3624 273.796 47.0581C274.055 47.5379 274.045 48.3191 274.023 49.8814L273.296 103.56C273.283 104.52 273.277 105 273.424 105.38C273.637 105.929 274.071 106.363 274.62 106.576C275 106.723 275.48 106.717 276.44 106.704L330.119 105.977C331.681 105.955 332.462 105.945 332.942 106.204C333.638 106.58 334.062 107.316 334.04 108.107C334.025 108.652 333.625 109.323 332.826 110.665L305.357 156.789C304.865 157.614 304.62 158.027 304.557 158.429C304.467 159.011 304.62 159.604 304.995 160.063C305.25 160.38 305.669 160.614 306.508 161.083L353.358 187.293C354.722 188.056 355.403 188.437 355.689 188.902C356.104 189.575 356.104 190.425 355.689 191.098C355.403 191.563 354.722 191.944 353.358 192.707L306.508 218.917C305.669 219.386 305.25 219.62 304.995 219.937C304.62 220.396 304.467 220.989 304.557 221.571C304.62 221.973 304.865 222.386 305.357 223.211L332.826 269.335C333.625 270.677 334.025 271.348 334.04 271.893C334.062 272.684 333.638 273.42 332.942 273.796C332.462 274.055 331.681 274.045 330.119 274.023L276.44 273.296C275.48 273.283 275 273.277 274.62 273.424C274.071 273.637 273.637 274.071 273.424 274.62C273.277 275 273.283 275.48 273.296 276.44L274.023 330.119C274.045 331.681 274.055 332.462 273.796 332.942C273.42 333.638 272.684 334.062 271.893 334.04C271.348 334.025 270.677 333.625 269.335 332.826L223.211 305.357C222.386 304.865 221.973 304.62 221.571 304.557C220.989 304.467 220.396 304.626 219.937 304.995C219.62 305.25 219.386 305.669 218.917 306.508L192.707 353.358C191.944 354.722 191.563 355.403 191.098 355.689C190.425 356.104 189.575 356.104 188.902 355.689C188.437 355.403 188.056 354.722 187.293 353.358L161.083 306.508C160.614 305.669 160.38 305.25 160.063 304.995C159.604 304.626 159.011 304.467 158.429 304.557C158.027 304.62 157.614 304.865 156.789 305.357L110.665 332.826C109.323 333.625 108.652 334.025 108.107 334.04C107.316 334.062 106.58 333.638 106.204 332.942C105.945 332.462 105.955 331.681 105.977 330.119L106.704 276.44C106.717 275.48 106.723 275 106.576 274.62C106.363 274.071 105.929 273.637 105.38 273.424C105 273.277 104.52 273.283 103.56 273.296L49.8814 274.023C48.3191 274.045 47.5379 274.055 47.0581 273.796C46.3624 273.42 45.9377 272.684 45.9598 271.893C45.9751 271.348 46.3748 270.677 47.1743 269.335L74.6431 223.211C75.1345 222.386 75.3802 221.973 75.4425 221.571C75.5326 220.989 75.3737 220.396 75.0046 219.937C74.7497 219.62 74.3306 219.386 73.4925 218.917L26.6421 192.707C25.2785 191.944 24.5966 191.563 24.3108 191.098C23.8964 190.425 23.8964 189.575 24.3108 188.902C24.5966 188.437 25.2785 188.056 26.6421 187.293L73.4925 161.083C74.3306 160.614 74.7497 160.38 75.0046 160.063C75.3737 159.604 75.5326 159.011 75.4425 158.429C75.3802 158.027 75.1345 157.614 74.6431 156.789L47.1743 110.665C46.3748 109.323 45.9751 108.652 45.9598 108.107C45.9377 107.316 46.3624 106.58 47.0581 106.204C47.5379 105.945 48.3191 105.955 49.8814 105.977L103.56 106.704C104.52 106.717 105 106.723 105.38 106.576C105.929 106.363 106.363 105.929 106.576 105.38C106.723 105.38 106.717 104.52 106.704 103.56L105.977 49.8814C105.955 48.3191 105.945 47.5379 106.204 47.0581C106.58 46.3624 107.316 45.9377 108.107 45.9598C108.652 45.9751 109.323 46.3748 110.665 47.1743L156.789 74.6431C157.614 75.1345 158.027 75.3802 158.429 75.4425C159.011 75.5326 159.604 75.3737 160.063 75.0046C160.38 74.7497 160.614 74.3306 161.083 73.4925L187.293 26.6421Z";

// Springs
const scaleSpring = new Spring(120, 14);
const rotateSpring = new Spring(100, 12);

// Animation State
let currentPath = PATH_COOKIE;
let targetPath = PATH_COOKIE;
let lastState = 'green';
let pathSwapPending = false;

// Initialize animation
scaleSpring.set(1);
rotateSpring.set(0);

// Animation Loop
let lastTime = 0;
function animate(time) {
  if (!lastTime) lastTime = time;
  const dt = (time - lastTime) / 1000;
  lastTime = time;

  const safeDt = Math.min(dt, 0.05);

  scaleSpring.update(safeDt);
  rotateSpring.update(safeDt);

  const pathEl = document.getElementById('background-shape');
  if (pathEl) {
    const scale = scaleSpring.current;
    const rotate = rotateSpring.current;

    pathEl.style.transform = `translate(-50%, -50%) scale(${scale}) rotate(${rotate}deg)`;

    if (pathSwapPending) {
      scaleSpring.target = 0.8;

      if (scaleSpring.current < 0.85) {
        const el = document.getElementById('blob-path');
        el.setAttribute('d', targetPath);
        currentPath = targetPath;
        pathSwapPending = false;

        scaleSpring.target = 1.0;
        rotateSpring.velocity += 10;
      }
    } else {
      if (Math.abs(scaleSpring.velocity) < 0.01) {
        const t = Date.now() / 2000;
        scaleSpring.target = 1.0 + Math.sin(t) * 0.03;
        rotateSpring.target = Math.sin(t * 0.5) * 2;
      }
    }
  }

  requestAnimationFrame(animate);
}
requestAnimationFrame(animate);

function setDisplay(inUse, name, elapsed, overdue, kioskSuspended) {
  // Update Body Background
  document.body.classList.remove('bg-green', 'bg-red', 'bg-yellow');

  let state = 'green';
  let nextPath = PATH_COOKIE;
  let targetColor = 'var(--color-green-container)';
  let icon = 'check_circle';
  let title = 'Available';
  let subtitle = 'Scan to check out';

  if (kioskSuspended) {
    state = 'red';
    nextPath = PATH_BURST;
    targetColor = 'var(--color-red-container)';
    icon = 'block';
    title = 'Suspended';
    subtitle = 'Ask Admin';
  } else if (inUse) {
    if (overdue) {
      state = 'yellow';
      nextPath = PATH_COOKIE;
      targetColor = 'var(--color-yellow-container)';
      icon = 'alarm';
      title = 'Overdue';
    } else {
      state = 'red';
      nextPath = PATH_BURST;
      targetColor = 'var(--color-red-container)';
      icon = 'timer';
      title = 'In Use';
    }
    const mins = Math.floor((elapsed || 0) / 60);
    const secs = (elapsed || 0) % 60;
    subtitle = `${name} • ${mins}:${secs.toString().padStart(2, '0')}`;
  }

  document.body.classList.add(`bg-${state}`);

  // Trigger Transition if path changed
  if (nextPath !== currentPath) {
    targetPath = nextPath;
    pathSwapPending = true;
    scaleSpring.target = 0.6;
    scaleSpring.velocity = 0;
  } else if (state !== lastState) {
    scaleSpring.velocity += 5;
  }

  lastState = state;

  // Set Color
  const pathEl = document.getElementById('blob-path');
  pathEl.style.fill = targetColor;

  // Update Content
  document.getElementById('displayIcon').textContent = icon;
  document.getElementById('displayTitle').textContent = title;
  document.getElementById('displaySubtitle').textContent = subtitle;
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
    document.body.classList.remove('bg-green', 'bg-red');
    document.body.classList.add('bg-yellow');
    const pathEl = document.getElementById('blob-path');
    pathEl.style.fill = 'var(--color-yellow-container)';
    document.getElementById('displayIcon').textContent = 'wifi_off';
    document.getElementById('displayTitle').textContent = 'Offline';
    document.getElementById('displaySubtitle').textContent = 'Trying to reconnect...';
  }

  connect();
}

if ('EventSource' in window) {
  startSSE();
} else {
  (async function poll() {
    try {
      const r = await fetch('/api/status');
      const j = await r.json();
      setDisplay(j.in_use, j.name || '', j.elapsed || 0, !!j.overdue, !!j.kiosk_suspended);
    } catch (e) { }
    setTimeout(poll, 1000);
  })();
}
