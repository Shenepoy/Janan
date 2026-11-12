// Generated per build. Contains only static asset URLs and their integrity hashes.
const build = /* BUILD_MANIFEST */;
const prefix = 'janan-shell:' + self.registration.scope + ':';
const cacheName = prefix + build.version;
const assets = new Map(Object.entries(build.files).map(([path, integrity]) =>
  [new URL(path, self.registration.scope).href, integrity]));
const shell = new URL('index.html', self.registration.scope).href;

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName);
    const pending = [...assets];
    // Finish in-flight fetches before removing a failed partial installation.
    const results = await Promise.allSettled(Array.from({length: 4}, async () => {
      while (pending.length) {
        const [url, integrity] = pending.pop();
        const response = await fetch(new Request(url, {
          cache: 'reload', credentials: 'omit', redirect: 'error', integrity,
        }));
        if (!response.ok || response.type === 'opaque') throw Error('Offline shell unavailable');
        await cache.put(url, response);
      }
    }));
    if (results.some(result => result.status === 'rejected')) {
      await caches.delete(cacheName);
      throw Error('Offline shell installation incomplete');
    }
    // Never skipWaiting: an update must not replace assets underneath open tabs.
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith(prefix) && key !== cacheName) await caches.delete(key);
    }
    // Never claim existing pages: only new navigations use this build.
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  const versionUrl = new URL('version.json', self.registration.scope);
  // package_info_plus requests build metadata with a numeric cachebuster. It
  // must describe the running cached build, not a later server deployment.
  if (url.origin === versionUrl.origin && url.pathname === versionUrl.pathname &&
      /^\?cachebuster=\d+$/.test(url.search)) url.search = '';
  // Credentials, APIs, reports, account entry routes, queries and other origins
  // are never cached. Navigation only falls back to the bare local diary shell.
  if (request.method !== 'GET' || url.search || request.headers.has('authorization') ||
      request.headers.has('range')) return;
  const root = new URL(self.registration.scope);
  if (url.origin !== root.origin) return;
  let key = url.href;
  if (request.mode === 'navigate') {
    if (url.pathname !== root.pathname && key !== shell) return;
    key = shell;
  }
  if (!assets.has(key)) return;
  event.respondWith((async () => {
    let cache;
    try {
      cache = await caches.open(cacheName);
      const cached = await cache.match(key);
      if (cached) return cached;
    } catch (_) {
      // Storage can be unavailable in restricted sessions. Online use can
      // still proceed; never clear other storage to make room for app files.
    }
    // If storage was evicted, only accept bytes matching this build. Never mix
    // an old shell with a newer deployment's same-named Flutter/SQLite files.
    try {
      const response = await fetch(new Request(key, {credentials: 'omit', redirect: 'error',
        cache: 'reload', integrity: assets.get(key)}));
      if (!response.ok || response.type === 'opaque') throw Error('App file unavailable');
      try { await cache?.put(key, response.clone()); } catch (_) { /* Keep online use working. */ }
      return response;
    } catch (error) {
      if (request.mode !== 'navigate') throw error;
      // A changed deployment may contain a complete newer build. Ask the
      // browser to check, but preserve the normal waiting-tab update policy.
      event.waitUntil(self.registration.update().catch(() => {}));
      return new Response(`<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Open Janan</title>
<style>:root{font:18px system-ui;color-scheme:light dark}body{max-width:36rem;margin:10vh auto;padding:24px;line-height:1.6}a{display:inline-block;padding:12px 20px;border:1px solid;border-radius:12px;color:inherit}</style>
<main><h1>Reconnect to open Janan</h1>
<p>Some app files are no longer available on this browser. Connect to the internet, then try again. This action does not reset your diary.</p>
<p>If an update is waiting, close all Janan tabs and reopen the app.</p>
<section lang="ar" dir="rtl"><h2>اتصل بالشبكة لفتح جنان</h2>
<p>بعض ملفات التطبيق لم تعد متاحة في هذا المتصفح. اتصل بالإنترنت ثم حاول مجدداً. هذا الإجراء لا يعيد ضبط يومياتك.</p>
<p>إذا كان هناك تحديث بانتظار التطبيق، فأغلق جميع تبويبات جنان وافتحه من جديد.</p></section>
<a href="./">Try again · حاول مجدداً</a></main></html>`, {status:503,headers:{
        'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store',
        'Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
        'Referrer-Policy':'no-referrer','X-Content-Type-Options':'nosniff',
        'Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp',
      }});
    }
  })());
});
