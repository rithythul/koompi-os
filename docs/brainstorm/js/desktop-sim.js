// ══════════════════════════════════════════════════════════════
// DESKTOP SIM — interactivity for the three desktop simulations
// Functions are GLOBALS so inline onclick= attributes (injected via
// innerHTML) can call them. innerHTML-injected <script> never runs,
// so this file is loaded directly from index.html.
// sim = 'hug' | 'taskbar' | 'dock'
// ══════════════════════════════════════════════════════════════

(function () {
  function root(sim) { return document.getElementById('sim-root-' + sim); }
  function q(sim, sel) { var r = root(sim); return r ? r.querySelector(sel) : null; }

  // Close every transient layer in a sim except an optional keeper.
  function closeAll(sim, keep) {
    var r = root(sim);
    if (!r) return;
    r.querySelectorAll('.sim-popup.open, .sim-overview.open, .sim-launcher.open, .sim-left-sidebar.open, .sim-right-sidebar.open')
      .forEach(function (el) { if (el !== keep) el.classList.remove('open'); });
  }

  // ── Sidebars ──────────────────────────────────────────────
  window.simToggleSidebar = function (sim, side, ev) {
    if (ev) ev.stopPropagation();
    var el = q(sim, '.sim-' + side + '-sidebar');
    if (!el) return;
    var willOpen = !el.classList.contains('open');
    closeAll(sim, willOpen ? el : null);
    el.classList.toggle('open', willOpen);
  };

  // ── Popups (anchored cards) ───────────────────────────────
  window.simTogglePopup = function (sim, name, ev) {
    if (ev) ev.stopPropagation();
    var el = q(sim, '.sim-popup[data-popup="' + name + '"]');
    if (!el) return;
    var willOpen = !el.classList.contains('open');
    closeAll(sim, willOpen ? el : null);
    el.classList.toggle('open', willOpen);
  };

  // ── Overview ──────────────────────────────────────────────
  window.simToggleOverview = function (sim, ev) {
    if (ev) ev.stopPropagation();
    var el = q(sim, '.sim-overview');
    if (!el) return;
    var willOpen = !el.classList.contains('open');
    closeAll(sim, willOpen ? el : null);
    el.classList.toggle('open', willOpen);
  };
  window.simOverviewBg = function (el, ev) {
    if (ev.target === el) el.classList.remove('open');
  };

  // ── Launcher ──────────────────────────────────────────────
  window.simToggleLauncher = function (sim, ev) {
    if (ev) ev.stopPropagation();
    var el = q(sim, '.sim-launcher');
    if (!el) return;
    var willOpen = !el.classList.contains('open');
    closeAll(sim, willOpen ? el : null);
    el.classList.toggle('open', willOpen);
  };
  window.simLauncherBg = function (el, ev) {
    if (ev.target === el) el.classList.remove('open');
  };

  // ── OSD (auto-dismiss after 2s) ───────────────────────────
  var osdTimers = {};
  window.simShowOSD = function (sim, kind, ev) {
    if (ev) ev.stopPropagation();
    var r = root(sim);
    if (!r) return;
    r.querySelectorAll('.sim-osd').forEach(function (o) { o.classList.remove('open'); });
    var el = q(sim, '.sim-osd[data-osd="' + kind + '"]');
    if (!el) return;
    el.classList.add('open');
    var key = sim + ':' + kind;
    if (osdTimers[key]) clearTimeout(osdTimers[key]);
    osdTimers[key] = setTimeout(function () { el.classList.remove('open'); }, 2000);
  };

  // ── App window focus (Hug + Dock) ─────────────────────────
  window.simFocusWin = function (sim, winId, title, ev) {
    if (ev) ev.stopPropagation();
    var r = root(sim);
    if (!r) return;
    r.querySelectorAll('.sim-win').forEach(function (w) { w.classList.remove('win-focused'); });
    var w = q(sim, '#' + winId);
    if (w) w.classList.add('win-focused');
    var tl = q(sim, '.active-win');
    if (tl && title) tl.textContent = title;
  };

  // ── Dismiss all panels when clicking the desktop background ──
  // Sidebars, popups, and the bar all call event.stopPropagation(),
  // so this only fires when the bare wallpaper / app-window area is hit.
  window.simDeskClick = function (sim, e) {
    // Skip if the click landed on any interactive layer that didn't stop it
    var el = e && e.target;
    while (el) {
      if (el.matches && el.matches(
        '.sim-left-sidebar,.sim-right-sidebar,.sim-popup-layer,' +
        '.sim-bar-wrap,.sim-overview,.sim-launcher,.sim-osd'
      )) return;
      el = el.parentElement;
    }
    closeAll(sim, null);
  };
})();
