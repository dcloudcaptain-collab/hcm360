/**
 * HCM360 — Guided Tour + Tooltip engine
 *
 * Features:
 *  - Auto-start incomplete tours matching the current URL + user role
 *  - Floating "?" help launcher to replay any tour
 *  - Role-based filtering (server-side)
 *  - Persistent completions per user+tour+version
 *  - data-hint="..." tooltip on any element
 *  - Mobile-friendly (tours collapse to centered modals; tooltips tap-triggered)
 */
(function () {
  'use strict';

  const STATE = {
    tours: [],       // array of tour objects for this page
    active: null,    // currently running tour
    stepIndex: 0,
    overlay: null,
    spotlight: null,
    stepEl: null,
    isMobile: window.matchMedia('(max-width: 768px)').matches,
    tooltipEl: null,
    launcherEl: null,
    menuEl: null,
  };

  // ── Helpers ────────────────────────────────────────────────────────
  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));

  function findTarget(selector) {
    if (!selector) return null;
    // Support multiple selectors separated by comma; take first that exists + visible
    const candidates = selector.split(',').map(s => s.trim()).filter(Boolean);
    for (const s of candidates) {
      try {
        const els = document.querySelectorAll(s);
        for (const el of els) {
          const rect = el.getBoundingClientRect();
          if (rect.width > 0 && rect.height > 0) return el;
        }
      } catch (_) {}
    }
    return null;
  }

  function api(path, opts) {
    return fetch(path, Object.assign({
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
    }, opts || {}));
  }

  // ── Fetch tours for current page ───────────────────────────────────
  async function loadTours() {
    const path = window.location.pathname;
    try {
      const r = await api(`/api/tours/for-page?path=${encodeURIComponent(path)}`);
      const j = await r.json();
      STATE.tours = j.tours || [];
    } catch (e) {
      STATE.tours = [];
    }
    buildLauncher();
    maybeAutoStart();
  }

  // ── Launcher ───────────────────────────────────────────────────────
  function buildLauncher() {
    if (STATE.launcherEl) STATE.launcherEl.remove();
    if (STATE.menuEl) STATE.menuEl.remove();

    const btn = document.createElement('button');
    btn.className = 'hris-help-launcher';
    btn.title = 'Help & Tours';
    btn.textContent = '?';
    btn.setAttribute('aria-label', 'Open help tours');

    const hasNew = STATE.tours.some(t => !t.is_completed && !t.is_skipped);
    if (hasNew) btn.classList.add('has-new');

    document.body.appendChild(btn);
    STATE.launcherEl = btn;

    // Menu
    const menu = document.createElement('div');
    menu.className = 'hris-help-menu';
    menu.innerHTML = '<h4>Guided Tours for This Page</h4>';

    if (STATE.tours.length === 0) {
      const p = document.createElement('button');
      p.disabled = true;
      p.innerHTML = '<em style="color:#9ca3af;">No tours for this page yet.</em>';
      menu.appendChild(p);
    } else {
      STATE.tours.forEach(t => {
        const b = document.createElement('button');
        b.type = 'button';
        const done = t.is_completed ?
          '<span class="hris-menu-done">✓ Done</span>' : '';
        b.innerHTML = `${done}<strong>${t.title}</strong>` +
          (t.description ? `<span class="hris-menu-sub">${t.description}</span>` : '');
        b.addEventListener('click', () => { menu.classList.remove('open'); startTour(t); });
        menu.appendChild(b);
      });
    }

    // Add resource link
    const resetAll = document.createElement('button');
    resetAll.type = 'button';
    resetAll.innerHTML = '<em style="color:#6b7280;">↻ Replay all tours on next visit</em>';
    resetAll.addEventListener('click', async () => {
      for (const t of STATE.tours) {
        await api(`/api/tours/${encodeURIComponent(t.tour_key)}/reset`, { method: 'POST' });
      }
      menu.classList.remove('open');
      loadTours();
    });
    menu.appendChild(resetAll);

    document.body.appendChild(menu);
    STATE.menuEl = menu;

    btn.addEventListener('click', () => {
      menu.classList.toggle('open');
    });
    document.addEventListener('click', (e) => {
      if (!menu.contains(e.target) && e.target !== btn) menu.classList.remove('open');
    });
  }

  // ── Auto-start ─────────────────────────────────────────────────────
  function maybeAutoStart() {
    if (STATE.isMobile) return; // full tours deferred on mobile
    const next = STATE.tours.find(t =>
      t.auto_start && !t.is_completed && !t.is_skipped);
    if (next) setTimeout(() => startTour(next), 600);
  }

  // ── Tour control ───────────────────────────────────────────────────
  function startTour(tour) {
    if (!tour || !tour.steps || !tour.steps.length) return;
    endTour(); // clean previous
    STATE.active = tour;
    STATE.stepIndex = 0;
    document.body.style.overflow = 'hidden';
    renderStep();
  }

  function endTour(completed) {
    if (STATE.overlay) STATE.overlay.remove();
    if (STATE.spotlight) STATE.spotlight.remove();
    if (STATE.stepEl) STATE.stepEl.remove();
    STATE.overlay = STATE.spotlight = STATE.stepEl = null;
    document.body.style.overflow = '';
    $$('.hris-tour-target-lit').forEach(el => el.classList.remove('hris-tour-target-lit'));
    if (STATE.active && completed !== undefined) {
      const path = completed ?
        `/api/tours/${encodeURIComponent(STATE.active.tour_key)}/complete` :
        `/api/tours/${encodeURIComponent(STATE.active.tour_key)}/skip`;
      api(path, {
        method: 'POST',
        body: JSON.stringify({
          version: STATE.active.version || 1,
          step_reached: STATE.stepIndex,
        }),
      }).then(() => loadTours()).catch(() => loadTours());
    }
    STATE.active = null;
  }

  function next() {
    if (!STATE.active) return;
    STATE.stepIndex++;
    if (STATE.stepIndex >= STATE.active.steps.length) {
      endTour(true);
    } else {
      renderStep();
    }
  }

  function back() {
    if (!STATE.active) return;
    STATE.stepIndex = Math.max(0, STATE.stepIndex - 1);
    renderStep();
  }

  // ── Render step ────────────────────────────────────────────────────
  function renderStep() {
    const step = STATE.active.steps[STATE.stepIndex];
    const target = step.selector ? findTarget(step.selector) : null;

    if (!STATE.overlay) {
      STATE.overlay = document.createElement('div');
      STATE.overlay.className = 'hris-tour-overlay';
      STATE.overlay.addEventListener('click', (e) => {
        if (e.target === STATE.overlay) {/* optional: click outside dismisses */}
      });
      document.body.appendChild(STATE.overlay);
    }

    // Clean prior spotlight
    if (STATE.spotlight) STATE.spotlight.remove();

    // Build step tooltip
    if (!STATE.stepEl) {
      STATE.stepEl = document.createElement('div');
      document.body.appendChild(STATE.stepEl);
    }
    STATE.stepEl.className = 'hris-tour-step' +
      (target ? '' : ' centered');
    STATE.stepEl.dataset.pos = step.position || 'bottom';

    const tot = STATE.active.steps.length;
    const i = STATE.stepIndex;
    const canBack = i > 0;
    const isLast = i === tot - 1;

    STATE.stepEl.innerHTML = `
      <div class="hris-tour-arrow"></div>
      <h3>${escape(step.title || STATE.active.title)}</h3>
      <p>${escape(step.body || '')}</p>
      <div class="hris-tour-foot">
        <span class="hris-tour-progress">Step ${i + 1} of ${tot}</span>
        <div class="hris-tour-btns">
          <button type="button" class="hris-btn-ghost" data-act="skip">Skip tour</button>
          ${canBack ? '<button type="button" class="hris-btn-back" data-act="back">Back</button>' : ''}
          <button type="button" class="hris-btn-next" data-act="next">${isLast ? 'Finish' : 'Next →'}</button>
        </div>
      </div>
    `;
    STATE.stepEl.querySelector('[data-act=next]').addEventListener('click', next);
    STATE.stepEl.querySelector('[data-act=skip]').addEventListener('click', () => endTour(false));
    const backBtn = STATE.stepEl.querySelector('[data-act=back]');
    if (backBtn) backBtn.addEventListener('click', back);

    // Position
    if (target && !STATE.isMobile) {
      positionStep(target, step.position || 'bottom');
    } else {
      // Centered modal
      STATE.stepEl.classList.add('centered');
      STATE.stepEl.style.top = '';
      STATE.stepEl.style.left = '';
    }
  }

  function positionStep(target, preferred) {
    // Scroll into view
    try {
      target.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' });
    } catch (_) {}

    setTimeout(() => {
      const rect = target.getBoundingClientRect();
      // Build spotlight
      if (!STATE.spotlight) {
        STATE.spotlight = document.createElement('div');
        STATE.spotlight.className = 'hris-tour-spotlight';
      }
      STATE.spotlight.style.top    = (rect.top - 6) + 'px';
      STATE.spotlight.style.left   = (rect.left - 6) + 'px';
      STATE.spotlight.style.width  = (rect.width + 12) + 'px';
      STATE.spotlight.style.height = (rect.height + 12) + 'px';
      if (!STATE.spotlight.isConnected) document.body.appendChild(STATE.spotlight);

      // Place step tooltip — flip if not enough room
      const stepRect = STATE.stepEl.getBoundingClientRect();
      const vw = window.innerWidth, vh = window.innerHeight;
      const margin = 14;
      let pos = preferred;

      // Auto-flip
      if (pos === 'bottom' && rect.bottom + stepRect.height + margin > vh) pos = 'top';
      if (pos === 'top' && rect.top - stepRect.height - margin < 0) pos = 'bottom';
      if (pos === 'right' && rect.right + stepRect.width + margin > vw) pos = 'left';
      if (pos === 'left' && rect.left - stepRect.width - margin < 0) pos = 'right';

      STATE.stepEl.dataset.pos = pos;
      let top, left;
      switch (pos) {
        case 'top':
          top = rect.top - stepRect.height - margin;
          left = rect.left + rect.width / 2 - stepRect.width / 2;
          break;
        case 'left':
          top = rect.top + rect.height / 2 - stepRect.height / 2;
          left = rect.left - stepRect.width - margin;
          break;
        case 'right':
          top = rect.top + rect.height / 2 - stepRect.height / 2;
          left = rect.right + margin;
          break;
        default: // bottom
          top = rect.bottom + margin;
          left = rect.left + rect.width / 2 - stepRect.width / 2;
      }
      // Clamp inside viewport
      left = Math.max(12, Math.min(vw - stepRect.width - 12, left));
      top  = Math.max(12, Math.min(vh - stepRect.height - 12, top));

      STATE.stepEl.style.position = 'fixed';
      STATE.stepEl.style.top  = top + 'px';
      STATE.stepEl.style.left = left + 'px';
      STATE.stepEl.classList.remove('centered');
    }, 280);
  }

  // ── Tooltip (data-hint) ────────────────────────────────────────────
  function initTooltips() {
    const tooltip = document.createElement('div');
    tooltip.className = 'hris-tooltip';
    document.body.appendChild(tooltip);
    STATE.tooltipEl = tooltip;

    function show(el, e) {
      const text = el.getAttribute('data-hint') || el.getAttribute('data-tour-hint');
      if (!text) return;
      tooltip.textContent = text;
      const rect = el.getBoundingClientRect();
      const vw = window.innerWidth, vh = window.innerHeight;
      // Auto-position: prefer top if room, else bottom
      let pos = 'top';
      if (rect.top < 40) pos = 'bottom';
      tooltip.dataset.pos = pos;
      // Must be visible-to-measure
      tooltip.style.left = '0px'; tooltip.style.top = '0px';
      tooltip.classList.add('show');
      const tr = tooltip.getBoundingClientRect();
      let top, left;
      if (pos === 'top') {
        top = rect.top - tr.height - 8;
        left = rect.left + rect.width / 2 - tr.width / 2;
      } else {
        top = rect.bottom + 8;
        left = rect.left + rect.width / 2 - tr.width / 2;
      }
      left = Math.max(6, Math.min(vw - tr.width - 6, left));
      top = Math.max(6, Math.min(vh - tr.height - 6, top));
      tooltip.style.top = top + 'px';
      tooltip.style.left = left + 'px';
    }
    function hide() {
      tooltip.classList.remove('show');
    }

    document.addEventListener('mouseover', (e) => {
      const el = e.target.closest('[data-hint],[data-tour-hint]');
      if (el) show(el, e);
    });
    document.addEventListener('mouseout', (e) => {
      const el = e.target.closest('[data-hint],[data-tour-hint]');
      if (el) hide();
    });
    // Mobile: tap to show
    document.addEventListener('touchstart', (e) => {
      const el = e.target.closest('[data-hint],[data-tour-hint]');
      if (el) { show(el, e); setTimeout(hide, 3000); }
    });
  }

  function escape(s) {
    const div = document.createElement('div');
    div.textContent = String(s || '');
    return div.innerHTML;
  }

  // ── Keyboard shortcuts during tour ─────────────────────────────────
  document.addEventListener('keydown', (e) => {
    if (!STATE.active) return;
    if (e.key === 'Escape') endTour(false);
    else if (e.key === 'ArrowRight' || e.key === 'Enter') next();
    else if (e.key === 'ArrowLeft') back();
  });

  // ── Public API ─────────────────────────────────────────────────────
  window.HRISTour = {
    start: (key) => {
      const t = STATE.tours.find(x => x.tour_key === key);
      if (t) startTour(t);
      else {
        // Try direct fetch
        api(`/api/tours/${encodeURIComponent(key)}`).then(r => r.json()).then(j => {
          if (j.ok) startTour(j.tour);
        });
      }
    },
    end: () => endTour(false),
    state: STATE,
    reload: loadTours,
  };

  // ── Bootstrap ──────────────────────────────────────────────────────
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bootstrap);
  } else {
    bootstrap();
  }
  function bootstrap() {
    initTooltips();
    loadTours();
  }
})();
