const { invoke } = window.__TAURI__.core;

// ── State ──────────────────────────────────────────────────────────────────

let cachedStatus    = null;
let lastTickMs      = null;   // wall-clock ms when we last got minutes_now from Rust
let lastMinutesNow  = 0;      // minutes since midnight in the configured timezone
let justShown       = false;  // suppress blur-to-hide right after popup opens
let calendarDirty   = true;   // true → animate calendar on next render
let glowPhase       = 0;      // 60fps glow animation phase
let blobPhase1      = 0;      // blob animation phases
let blobPhase2      = 0.5;

// ── DOM refs ───────────────────────────────────────────────────────────────

const statusLabel     = document.getElementById('statusLabel');
const statusSub       = document.getElementById('statusSub');
const statusBadge     = document.getElementById('statusBadge');
const nextWindow      = document.getElementById('nextWindow');
const barSegments     = document.getElementById('barSegments');
const barPast         = document.getElementById('barPast');
const nowIndicator    = document.getElementById('nowIndicator');
const blockStartLabel = document.getElementById('blockStartLabel');
const blockEndLabel   = document.getElementById('blockEndLabel');
const calendarRow     = document.getElementById('calendarRow');
const blob1           = document.querySelector('.blob-1');
const blob2           = document.querySelector('.blob-2');
const nowGlow         = document.querySelector('.now-glow');
const nowLine         = document.querySelector('.now-line');

// ── Helpers ────────────────────────────────────────────────────────────────

function minToLabel(min) {
  const h   = Math.floor(min / 60);
  const m   = min % 60;
  const sfx = h >= 12 ? 'PM' : 'AM';
  const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
  return m === 0 ? `${h12} ${sfx}` : `${h12}:${String(m).padStart(2,'0')} ${sfx}`;
}

function formatMinutes(min) {
  const h = Math.floor(min / 60);
  const m = min % 60;
  if (h > 0 && m > 0) return `${h}h ${m}m`;
  if (h > 0) return `${h}h`;
  return `${m}m`;
}

// ── Render ─────────────────────────────────────────────────────────────────

function applyTheme(theme) {
  const r = document.documentElement.style;
  r.setProperty('--active',  theme.active_color);
  r.setProperty('--blocked', theme.blocked_color);
  r.setProperty('--weekend', theme.weekend_color);
  r.setProperty('--accent',  theme.accent);
}

function renderSegments(blockStart, blockEnd) {
  const s1 = blockStart / 1440;
  const s2 = (blockEnd - blockStart) / 1440;
  const s3 = (1440 - blockEnd) / 1440;
  barSegments.innerHTML =
    `<div style="flex:${s1};background:linear-gradient(to bottom,rgba(74,222,128,0.70),rgba(22,163,74,0.42));border-radius:6px"></div>` +
    `<div style="flex:${s2};background:linear-gradient(to bottom,rgba(248,113,113,0.42),rgba(153,27,27,0.22));border-radius:6px"></div>` +
    `<div style="flex:${s3};background:linear-gradient(to bottom,rgba(74,222,128,0.70),rgba(22,163,74,0.42));border-radius:6px"></div>`;
}

function renderNowIndicator(minutesNow) {
  const pct = (minutesNow / 1440) * 100;
  nowIndicator.style.left = `${pct}%`;
  barPast.style.width     = `${pct}%`;
}

function renderCalendar(days) {
  const animate = calendarDirty;
  calendarDirty = false;
  calendarRow.innerHTML = '';
  days.forEach((day, i) => {
    const dotClass   = day.is_weekend ? 'weekend' : 'active';
    const todayClass = day.is_today   ? ' today'  : '';
    const el = document.createElement('div');
    el.className = 'cal-day';
    if (animate) {
      el.style.animation = `slide-up 0.35s cubic-bezier(0.34, 1.56, 0.64, 1) ${i * 40}ms forwards`;
    } else {
      el.style.animation = 'none';
      el.style.opacity   = '1';
      el.style.transform = 'none';
    }
    const numClass = day.is_today ? 'today' : day.is_weekend ? 'weekend' : '';
    const nameClass = day.is_weekend ? 'weekend' : '';
    el.innerHTML =
      `<span class="cal-day-num ${numClass}">${day.day_num}</span>` +
      `<div class="cal-dot ${dotClass}${todayClass}"></div>` +
      `<span class="cal-day-name ${nameClass}">${day.day_name}</span>`;
    calendarRow.appendChild(el);
  });
}

function render(s) {
  applyTheme(s.theme);
  document.body.className = s.status;
  statusLabel.textContent = s.label;
  statusSub.textContent   = s.sublabel;
  nextWindow.textContent  = s.next_window;

  // Status badge
  const badgeMap = { active: 'LIVE', blocked: 'OFF', weekend: 'WKD' };
  statusBadge.textContent = badgeMap[s.status] || '';

  blockStartLabel.textContent = minToLabel(s.block_start_min);
  blockEndLabel.textContent   = minToLabel(s.block_end_min);
  // Position labels to match actual time positions on the bar
  blockStartLabel.style.left = `${(s.block_start_min / 1440) * 100}%`;
  blockEndLabel.style.left   = `${(s.block_end_min / 1440) * 100}%`;
  renderSegments(s.block_start_min, s.block_end_min);
  renderNowIndicator(s.minutes_now);
  renderCalendar(s.calendar);
}

// ── 60fps animation loop (blobs + glow) ────────────────────────────────────

function animationLoop() {
  // Advance phases
  blobPhase1 += 0.004;
  blobPhase2 += 0.003;
  glowPhase  += 0.05;

  // Animate blobs with organic sine/cosine movement
  const b1x = 60 * Math.cos(blobPhase1);
  const b1y = 40 * Math.sin(blobPhase1 * 0.7);
  blob1.style.transform = `translate(${b1x}px, ${b1y}px)`;

  const b2x = -50 * Math.cos(blobPhase2);
  const b2y = 60 * Math.sin(blobPhase2 * 0.5);
  blob2.style.transform = `translate(${b2x}px, ${b2y}px)`;

  // Animate glow on now-indicator
  const glowOp = 0.20 + 0.08 * Math.sin(glowPhase);
  const shadowRadius = 4 + 2 * Math.sin(glowPhase);
  nowGlow.style.opacity = glowOp;
  if (cachedStatus) {
    const color = cachedStatus.status === 'blocked' ? 'var(--blocked)'
                : cachedStatus.status === 'weekend' ? 'var(--weekend)'
                : 'var(--active)';
    nowLine.style.boxShadow = `0 0 ${shadowRadius}px ${color}`;
  }

  requestAnimationFrame(animationLoop);
}

// ── Tick ───────────────────────────────────────────────────────────────────

async function tick() {
  try {
    const s = await invoke('get_status');
    lastMinutesNow = s.minutes_now;
    lastTickMs     = Date.now();
    render(s);
    cachedStatus = s;
  } catch (e) {
    console.error('get_status failed:', e);
  }
}

// Advance the now-line every second using elapsed wall time from last tick.
function smoothTick() {
  if (lastTickMs === null) return;
  const elapsedMin = (Date.now() - lastTickMs) / 60_000;
  renderNowIndicator(lastMinutesNow + elapsedMin);
}

// ── Click-outside to close (blur-based) ───────────────────────────────────

window.__TAURI__.event.listen('popup-shown', () => {
  justShown     = true;
  calendarDirty = true;
  setTimeout(() => { justShown = false; }, 800);
  tick();
});

window.addEventListener('blur', async () => {
  if (justShown) return;
  await new Promise(r => setTimeout(r, 80));
  if (document.hasFocus()) return;
  try {
    await invoke('hide_window');
  } catch (e) {
    console.warn('hide_window failed:', e);
  }
});

// ── Boot ───────────────────────────────────────────────────────────────────

setTimeout(tick, 50);
setInterval(tick, 10_000);
setInterval(smoothTick, 1_000);
requestAnimationFrame(animationLoop);
