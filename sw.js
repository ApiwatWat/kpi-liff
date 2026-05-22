/* ================================================================
 * KPI Monitor LIFF — Service Worker
 * Sprint 4 #6 (22 พ.ค.69)
 *
 * Strategy:
 *   - Static (HTML/CSS/JS/IMG): cache-first, fallback network
 *   - LIFF SDK (line-scdn): cache-first (1 day TTL via lastModified)
 *   - API (Apps Script): network-first with cache fallback (graceful offline)
 *
 * Cache invalidation: bump CACHE_VERSION when assets change.
 * ================================================================ */

var CACHE_VERSION = 'kpi-liff-v1-20260522';
var STATIC_CACHE = CACHE_VERSION + '-static';
var API_CACHE = CACHE_VERSION + '-api';

/* Pre-cache on install: critical static files for offline-first load */
var PRECACHE_URLS = [
  './',
  './index.html',
  './daily-coach.html',
  './KPI_Monitor_Logo_DonutRing.jpg'
];

/* ── INSTALL: pre-cache static assets ─────────────────────────── */
self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(STATIC_CACHE).then(function(cache) {
      console.log('[SW] Pre-caching', PRECACHE_URLS.length, 'static files');
      return cache.addAll(PRECACHE_URLS);
    }).then(function() {
      return self.skipWaiting(); // activate immediately
    })
  );
});

/* ── ACTIVATE: cleanup old caches ─────────────────────────────── */
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(name) {
        if (name.indexOf(CACHE_VERSION) !== 0) {
          console.log('[SW] Deleting old cache:', name);
          return caches.delete(name);
        }
      }));
    }).then(function() {
      return self.clients.claim(); // take control immediately
    })
  );
});

/* ── FETCH: routing by URL pattern ────────────────────────────── */
self.addEventListener('fetch', function(event) {
  var url = new URL(event.request.url);

  /* Only handle GET (skip POST/PUT — never cache writes) */
  if (event.request.method !== 'GET') return;

  /* Skip cross-origin LINE SDK (let browser cache it natively) */
  if (url.hostname === 'static.line-scdn.net') return;

  /* Apps Script API: network-first */
  if (url.hostname === 'script.google.com' || url.hostname.indexOf('googleusercontent.com') >= 0) {
    event.respondWith(networkFirst(event.request, API_CACHE));
    return;
  }

  /* GitHub Pages static (same origin): cache-first */
  if (url.origin === self.location.origin) {
    event.respondWith(cacheFirst(event.request, STATIC_CACHE));
    return;
  }

  /* Everything else: pass-through (no caching) */
});

/* ── STRATEGIES ───────────────────────────────────────────────── */

function cacheFirst(request, cacheName) {
  return caches.match(request).then(function(cached) {
    if (cached) {
      /* Refresh in background (stale-while-revalidate) */
      fetch(request).then(function(networkResp) {
        if (networkResp && networkResp.status === 200) {
          caches.open(cacheName).then(function(cache) {
            cache.put(request, networkResp.clone());
          });
        }
      }).catch(function() { /* silent offline */ });
      return cached;
    }
    /* Cache miss — network + cache */
    return fetch(request).then(function(resp) {
      if (resp && resp.status === 200) {
        var clone = resp.clone();
        caches.open(cacheName).then(function(cache) {
          cache.put(request, clone);
        });
      }
      return resp;
    });
  });
}

function networkFirst(request, cacheName) {
  return fetch(request).then(function(resp) {
    if (resp && resp.status === 200) {
      var clone = resp.clone();
      caches.open(cacheName).then(function(cache) {
        cache.put(request, clone);
      });
    }
    return resp;
  }).catch(function() {
    /* Offline fallback */
    return caches.match(request).then(function(cached) {
      if (cached) {
        console.log('[SW] Offline: serving cached API response for', request.url.substring(0, 80));
        return cached;
      }
      /* No cache + no network → return synthetic error JSON */
      return new Response(JSON.stringify({
        ok: false,
        offline: true,
        msg: 'ไม่มี Internet — แสดงข้อมูลจาก cache ไม่ได้'
      }), {
        status: 503,
        headers: { 'Content-Type': 'application/json' }
      });
    });
  });
}

/* ── MESSAGE: manual cache control from page ──────────────────── */
self.addEventListener('message', function(event) {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  } else if (event.data === 'CLEAR_CACHE') {
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(n) { return caches.delete(n); }));
    }).then(function() {
      if (event.ports && event.ports[0]) {
        event.ports[0].postMessage({ ok: true, cleared: true });
      }
    });
  }
});
