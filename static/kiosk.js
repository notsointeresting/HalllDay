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

// Puffy/Organic Shape
const PATH_PUFFY = "M371.982 187.559C371.686 165.488 353.541 147.816 331.439 148.112C330.218 148.112 329.016 148.204 327.832 148.334C328.757 147.576 329.663 146.799 330.532 145.949C346.365 130.551 346.698 105.226 331.291 89.4031C330.384 88.4788 329.478 87.5546 328.553 86.6673C312.721 71.2692 287.4 71.6019 271.974 87.4252C271.124 88.294 270.347 89.1997 269.588 90.124C269.718 88.9409 269.792 87.7394 269.81 86.5194C270.125 64.4482 252.443 46.3142 230.359 46C229.711 46 229.064 46 228.417 46H227.103C210.734 46 196.696 55.8341 190.5 69.9013C184.304 55.8341 170.247 46 153.897 46H152.583C151.936 46 151.289 46 150.641 46C128.557 46.2958 110.875 64.4297 111.171 86.5194C111.171 87.7394 111.264 88.9409 111.393 90.124C110.635 89.1997 109.858 88.294 109.007 87.4252C93.6001 71.6019 68.2608 71.2692 52.4283 86.6673C51.5035 87.573 50.5787 88.4788 49.6909 89.4031C34.2839 105.226 34.6168 130.532 50.4493 145.949C51.3186 146.799 52.2249 147.576 53.1497 148.334C51.9659 148.204 50.7637 148.13 49.543 148.112C27.4589 147.816 9.31443 165.488 9 187.559C9 188.206 9 188.853 9 189.5C9 190.147 9 190.794 9 191.441C9.29593 213.512 27.4404 231.184 49.543 230.888C50.7637 230.888 51.9659 230.796 53.1497 230.666C52.2249 231.424 51.3186 232.201 50.4493 233.051C34.6168 248.449 34.2839 273.774 49.6909 289.597C50.5972 290.521 51.5035 291.445 52.4283 292.333C68.2608 307.731 93.5816 307.398 109.007 291.575C109.858 290.706 110.635 289.8 111.393 288.876C111.264 290.059 111.19 291.261 111.171 292.481C110.875 314.552 128.539 332.704 150.641 333C151.289 333 151.936 333 152.583 333H153.897C170.266 333 184.304 323.166 190.5 309.099C196.696 323.166 210.753 333 227.103 333H228.417C229.064 333 229.711 333 230.359 333C252.443 332.704 270.125 314.57 269.829 292.481C269.829 291.261 269.736 290.059 269.607 288.876C270.365 289.8 271.142 290.706 271.993 291.575C287.4 307.398 312.739 307.731 328.572 292.333C329.496 291.427 330.421 290.521 331.309 289.597C346.716 273.774 346.383 248.468 330.551 233.051C329.681 232.201 328.775 231.424 327.85 230.666C329.034 230.796 330.236 230.87 331.457 230.888C353.541 231.184 371.704 213.531 372 191.441C372 190.794 372 190.147 372 189.5C372 188.853 372 188.206 372 187.559H371.982Z";

// 8-Leaf Clover Shape
const PATH_CLOVER = "M338.584 189.998C364.427 238.164 344.902 281.771 295.066 295.061C281.771 344.902 238.164 364.422 189.998 338.584C141.831 364.427 98.2245 344.902 84.9337 295.066C35.0981 281.771 15.573 238.164 41.4157 189.998C15.573 141.831 35.0981 98.2245 84.9337 84.9337C98.2245 35.0981 141.831 15.573 189.998 41.4157C238.164 15.573 281.771 35.0981 295.061 84.9337C344.902 98.2245 364.422 141.831 338.584 189.998Z";

// 12-sided Cookie (smooth)
const PATH_COOKIE_12 = "M166.697 39.8458C167.238 39.3157 167.508 39.0506 167.743 38.8298C180.246 27.0567 199.754 27.0567 212.257 38.8298C212.492 39.0506 212.762 39.3157 213.303 39.8458C213.628 40.1639 213.79 40.323 213.945 40.4703C221.945 48.1056 233.282 51.1433 244.028 48.5311C244.235 48.4807 244.456 48.4242 244.896 48.311C245.63 48.1224 245.996 48.0282 246.31 47.9542C263.024 44.0098 279.919 53.7642 284.86 70.2114C284.953 70.5199 285.055 70.8847 285.258 71.6143C285.38 72.0522 285.442 72.2711 285.502 72.4758C288.613 83.0884 296.912 91.3875 307.524 94.4985C307.729 94.5585 307.948 94.6195 308.386 94.7417C309.115 94.9452 309.48 95.0469 309.789 95.1396C326.236 100.081 335.99 116.976 332.046 133.69C331.972 134.004 331.878 134.371 331.689 135.104C331.576 135.544 331.519 135.765 331.469 135.972C328.857 146.718 331.894 158.055 339.53 166.055C339.677 166.21 339.836 166.372 340.154 166.697C340.684 167.238 340.949 167.508 341.17 167.743C352.943 180.246 352.943 199.754 341.17 212.257C340.949 212.492 340.684 212.762 340.154 213.303C339.836 213.628 339.677 213.79 339.53 213.945C331.894 221.945 328.857 233.282 331.469 244.028C331.519 244.235 331.576 244.456 331.689 244.896C331.878 245.629 331.972 245.996 332.046 246.31C335.99 263.024 326.236 279.919 309.789 284.86C309.48 284.953 309.115 285.055 308.386 285.258C307.948 285.381 307.729 285.442 307.524 285.502C296.912 288.613 288.613 296.912 285.502 307.524C285.442 307.729 285.381 307.948 285.258 308.386C285.055 309.115 284.953 309.48 284.86 309.789C279.919 326.236 263.024 335.99 246.31 332.046C245.996 331.972 245.629 331.878 244.896 331.689C244.456 331.576 244.235 331.519 244.028 331.469C233.282 328.857 221.945 331.894 213.945 339.53C213.79 339.677 213.628 339.836 213.303 340.154C212.762 340.684 212.492 340.949 212.257 341.17C199.754 352.943 180.246 352.943 167.743 341.17C167.508 340.949 167.238 340.684 166.697 340.154C166.372 339.836 166.21 339.677 166.055 339.53C158.055 331.894 146.718 328.857 135.972 331.469C135.765 331.519 135.544 331.576 135.104 331.689C134.371 331.878 134.004 331.972 133.69 332.046C116.976 335.99 100.081 326.236 95.1396 309.789C95.0469 309.48 94.9452 309.115 94.7417 308.386C94.6195 307.948 94.5585 307.729 94.4985 307.524C91.3875 296.912 83.0884 288.613 72.4758 285.502C72.2711 285.442 72.0522 285.38 71.6143 285.258C70.8847 285.055 70.5199 284.953 70.2114 284.86C53.7642 279.919 44.0098 263.024 47.9542 246.31C48.0282 245.996 48.1224 245.63 48.311 244.896C48.4242 244.456 48.4807 244.235 48.5311 244.028C51.1433 233.282 48.1056 221.945 40.4703 213.945C40.323 213.79 40.1639 213.628 39.8458 213.303C39.3157 212.762 39.0506 212.492 38.8298 212.257C27.0567 199.754 27.0567 180.246 38.8298 167.743C39.0506 167.508 39.3157 167.238 39.8458 166.697C40.1639 166.372 40.323 166.21 40.4703 166.055C48.1056 158.055 51.1433 146.718 48.5311 135.972C48.4807 135.765 48.4242 135.544 48.311 135.104C48.1224 134.371 48.0282 134.004 47.9542 133.69C44.0098 116.976 53.7642 100.081 70.2114 95.1396C70.5199 95.0469 70.8847 94.9452 71.6143 94.7417C72.0522 94.6195 72.2711 94.5585 72.4758 94.4985C83.0884 91.3875 91.3875 83.0884 94.4985 72.4758C94.5585 72.2711 94.6195 72.0522 94.7417 71.6143C94.9452 70.8847 95.0469 70.5199 95.1396 70.2114C100.081 53.7642 116.976 44.0098 133.69 47.9542C134.004 48.0282 134.371 48.1224 135.104 48.311C135.544 48.4242 135.765 48.4807 135.972 48.5311C146.718 51.1433 158.055 48.1056 166.055 40.4703C166.21 40.323 166.372 40.1639 166.697 39.8458Z";

// Soft Burst Shape
const PATH_SOFT_BURST = "M175.147 33.1508C181.983 22.2831 198.017 22.2831 204.853 33.1508L221.238 59.2009C225.731 66.3458 234.797 69.2506 242.692 66.0751L271.475 54.4972C283.482 49.6671 296.455 58.9613 295.507 71.7154L293.235 102.288C292.612 110.673 298.215 118.278 306.494 120.284L336.681 127.601C349.275 130.653 354.23 145.692 345.861 155.461L325.8 178.877C320.298 185.3 320.298 194.7 325.8 201.123L345.861 224.539C354.23 234.308 349.275 249.347 336.681 252.399L306.494 259.716C298.215 261.722 292.612 269.327 293.235 277.712L295.507 308.285C296.455 321.039 283.482 330.333 271.475 325.503L242.692 313.925C234.797 310.749 225.731 313.654 221.238 320.799L204.853 346.849C198.017 357.717 181.983 357.717 175.147 346.849L158.762 320.799C154.269 313.654 145.203 310.749 137.308 313.925L108.525 325.503C96.5177 330.333 83.5454 321.039 84.4931 308.285L86.7649 277.712C87.388 269.327 81.785 261.722 73.5056 259.716L43.3186 252.399C30.7252 249.347 25.7702 234.308 34.1391 224.539L54.1997 201.123C59.7018 194.7 59.7018 185.3 54.1997 178.877L34.1391 155.461C25.7702 145.692 30.7252 130.653 43.3186 127.601L73.5056 120.284C81.785 118.278 87.388 110.673 86.7649 102.288L84.4931 71.7154C83.5454 58.9613 96.5177 49.6671 108.525 54.4972L137.308 66.0751C145.203 69.2506 154.269 66.3458 158.762 59.201L175.147 33.1508Z";

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

    // Track previous state to only morph on actual state changes
    this.previousType = null;
    this.previousPath = null;
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

    // Update path and color - only change path on actual state transitions
    // Material 3: Shapes should be stable when state doesn't change
    const pathDom = this.element.querySelector('path');
    if (pathDom) {
      // Only update path if it actually changed (state transition)
      if (this.currentPath !== this.previousPath) {
        pathDom.setAttribute('d', this.currentPath);
        this.previousPath = this.currentPath;
      }
      // Smooth color transitions using Material 3 timing
      pathDom.style.fill = this.color;
      pathDom.style.transition = 'fill 0.3s cubic-bezier(0.2, 0, 0, 1)';
    }
  }

  setTarget(x, y, scale, type, sessionData = null) {
    this.xSpring.target = x;
    this.ySpring.target = y;
    this.scaleSpring.target = scale;
    
    // Track state changes for purposeful morphing
    const stateChanged = this.type !== type;
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
      // Stable shape for available state - no morphing
      targetPath = PATH_COOKIE;
      targetColor = 'var(--color-green-container)';
      textColor = 'var(--md-sys-color-on-green-container)';
    } else if (type === 'used') {
      // Stable 12-sided cookie for used passes
      targetPath = PATH_COOKIE_12;
      showContent = true;
      if (sessionData) {
        nameText = sessionData.name || 'Student';
        const mins = Math.floor((sessionData.elapsed || 0) / 60);
        const secs = (sessionData.elapsed || 0) % 60;
        timerText = `${mins}:${secs.toString().padStart(2, '0')}`;

        if (sessionData.overdue) {
          targetPath = PATH_SOFT_BURST; // More urgent shape when overdue
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
      // Sharp burst for banned
      targetPath = PATH_BURST;
      targetColor = 'var(--color-red-container)';
      textColor = 'var(--md-sys-color-on-red-container)';
      showContent = true;
      nameText = 'BANNED';
      iconText = 'block';
    } else if (type === 'processing') {
      targetPath = PATH_SOFT_BURST;
      targetColor = 'var(--md-sys-color-surface-variant)';
      textColor = 'var(--md-sys-color-on-surface-variant)';
    } else if (type === 'suspended') {
      // Sharp burst for suspended
      targetPath = PATH_BURST;
      targetColor = 'var(--color-red-container)';
      textColor = 'var(--md-sys-color-on-red-container)';
      showContent = true;
      nameText = 'SUSPENDED';
      iconText = 'block';
    }

    // Only update path if state actually changed (Material 3: purposeful motion)
    // This prevents distracting random shape changes
    if (stateChanged || this.currentPath !== targetPath) {
      this.currentPath = targetPath;
    }
    this.color = targetColor;

    // Update Content
    const contentEl = this.element.querySelector('.bubble-content');
    if (contentEl) {
      // Smooth content transitions using Material 3 timing
      contentEl.style.transition = 'opacity 0.3s cubic-bezier(0.2, 0, 0, 1)';
      contentEl.style.opacity = showContent ? '1' : '0';
      contentEl.style.color = textColor;
      this.element.querySelector('.bubble-name').textContent = nameText;
      this.element.querySelector('.bubble-timer').textContent = timerText;
      this.element.querySelector('.bubble-icon').textContent = iconText;
    }
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
