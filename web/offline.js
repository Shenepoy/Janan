// Only the local diary installs an offline shell. Account entry pages do not.
(() => {
  const base = new URL(document.baseURI);
  if (!('serviceWorker' in navigator) || location.search || location.hash ||
      ![base.pathname, base.pathname + 'index.html'].includes(location.pathname)) return;
  let dismissed = false;
  function notice(en, ar) {
    if (dismissed) return;
    let box = document.getElementById('janan-offline-status');
    if (!box) {
      box = document.createElement('aside');
      box.id = 'janan-offline-status';
      box.setAttribute('aria-live', 'polite');
      const text = document.createElement('span');
      const close = document.createElement('button');
      close.type = 'button';
      close.textContent = '×';
      close.setAttribute('aria-label', 'Dismiss · إغلاق');
      function dismiss() {
        dismissed = true;
        box.remove();
        document.removeEventListener('pointerdown', resume, true);
        document.removeEventListener('keydown', resume, true);
      }
      function resume(event) {
        if (!box.contains(event.target)) dismiss();
      }
      close.addEventListener('click', dismiss);
      document.addEventListener('pointerdown', resume, true);
      document.addEventListener('keydown', resume, true);
      box.append(text, close);
      document.body.append(box);
    }
    box.firstChild.textContent = en + ' · ' + ar;
  }
  navigator.serviceWorker.register(new URL('janan_service_worker.js', base), {
    scope: base.pathname, updateViaCache: 'none',
  }).then(registration => {
    const ready = () => notice('Ready for offline use', 'جاهز للاستخدام دون اتصال');
    const update = () => notice('Update ready. Close all Janan tabs, then reopen.',
      'التحديث جاهز. أغلق جميع تبويبات جنان ثم افتحه من جديد.');
    if (registration.waiting) update();
    // An existing registration alone does not prove its cache survived browser
    // eviction. Announce readiness only after a complete new installation.
    function watch() {
      const worker = registration.installing;
      if (!worker) return;
      worker.addEventListener('statechange', () => {
        if (worker.state === 'installed') {
          if (registration.active) update(); else ready();
        } else if (worker.state === 'redundant' && !registration.active) {
          notice('Offline setup failed. Reconnect and reload to retry.',
            'تعذر الإعداد دون اتصال. اتصل بالشبكة وأعد التحميل للمحاولة.');
        }
      });
    }
    watch();
    registration.addEventListener('updatefound', watch);
  }).catch(() => notice('Offline startup is unavailable in this browser session.',
    'فتح التطبيق دون اتصال غير متاح في جلسة المتصفح الحالية.'));
})();
