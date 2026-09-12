// CES Diaconia - Service Worker de Notificações (v3.11.0-PWA)
// Controla recebimento e exibição de push notifications via FCM e Cache Offline PWA

importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js');

const firebaseConfigProd = {
    apiKey: "AIzaSyDqlZ5pukg4NAg2mqMjAzAcRJCIeNN_K24",
    authDomain: "diaconia-a38f1.firebaseapp.com",
    projectId: "diaconia-a38f1",
    storageBucket: "diaconia-a38f1.firebasestorage.app",
    messagingSenderId: "489746524173",
    appId: "1:489746524173:web:f0eead38951fb738364d44"
};

firebase.initializeApp(firebaseConfigProd);
const messaging = firebase.messaging();

const CACHE_NAME = 'diaconia-cache-v3.11.11-PWA';
const SW_VERSION = 'v3.11.11-PWA';
const APP_URL = '/';

// App Shell: Recursos vitais a serem pré-cacheados na instalação
const APP_SHELL = [
    '/',
    '/index.html',
    '/offline.html',
    '/css/style.css',
    '/assets/logo.png'
];

// ── Instalação ──────────────────────────────────────────────
self.addEventListener('install', event => {
    console.log('[SW PWA/FCM] Instalado:', SW_VERSION);
    event.waitUntil(
        caches.open(CACHE_NAME).then(cache => {
            console.log('[SW PWA] Pré-cacheando App Shell');
            return cache.addAll(APP_SHELL);
        })
    );
    self.skipWaiting();
});

// ── Ativação e Limpeza ────────────────────────────────────────
self.addEventListener('activate', event => {
    console.log('[SW PWA/FCM] Ativado:', SW_VERSION);
    event.waitUntil(
        Promise.all([
            caches.keys().then(cacheNames => {
                return Promise.all(
                    cacheNames.map(cacheName => {
                        if (cacheName !== CACHE_NAME) {
                            console.log('[SW PWA] Removendo cache antigo:', cacheName);
                            return caches.delete(cacheName);
                        }
                    })
                );
            }),
            clients.claim()
        ])
    );
});

// ── Interceptação de Rede (Fetch) ──────────────────────────────
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);
    const acceptHeader = event.request.headers.get('accept') || '';

    // 1. BYPASS ESTRITO: Ignorar requisições dinâmicas do ecossistema Firebase/Google
    const bypassDomains = [
        'firebaseio.com',
        'firestore.googleapis.com',
        'identitytoolkit.googleapis.com',
        'securetoken.googleapis.com',
        'firebaseinstallations.googleapis.com',
        'fcmregistrations.googleapis.com',
        'fcm.googleapis.com',
        'googleapis.com',
        'gstatic.com'
    ];

    const shouldBypass = bypassDomains.some(domain => url.hostname.includes(domain)) || url.pathname.startsWith('/_/') || event.request.method !== 'GET';

    if (shouldBypass) {
        return; 
    }

    // 2. NETWORK FIRST (HTML) -> Fallback offline.html
    if (acceptHeader.includes('text/html')) {
        event.respondWith(
            fetch(event.request)
                .then(networkResponse => {
                    if (networkResponse && networkResponse.ok) {
                        const responseClone = networkResponse.clone();
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, responseClone));
                    }
                    return networkResponse;
                })
                .catch(() => {
                    return caches.match(event.request).then(cachedResponse => {
                        return cachedResponse || caches.match('/offline.html');
                    });
                })
        );
        return;
    }

    // 3. CACHE FIRST (Imagens)
    if (event.request.destination === 'image' || url.pathname.endsWith('.png') || url.pathname.endsWith('.svg')) {
        event.respondWith(
            caches.match(event.request).then(cachedResponse => {
                return cachedResponse || fetch(event.request).then(networkResponse => {
                    if (networkResponse && networkResponse.ok) {
                        const responseClone = networkResponse.clone();
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, responseClone));
                    }
                    return networkResponse;
                });
            })
        );
        return;
    }

    // 4. STALE WHILE REVALIDATE (JS e CSS)
    if (event.request.destination === 'script' || event.request.destination === 'style') {
        event.respondWith(
            caches.match(event.request).then(cachedResponse => {
                const fetchPromise = fetch(event.request).then(networkResponse => {
                    if (networkResponse && networkResponse.ok) {
                        const responseClone = networkResponse.clone();
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, responseClone));
                    }
                    return networkResponse;
                }).catch(err => console.warn('[SW PWA] Falha no revalidate (Offline):', err));
                
                return cachedResponse || fetchPromise;
            })
        );
        return;
    }

    // 5. SEM CACHE (Recursos Genéricos)
    return;
});

// ── Receber mensagens via FCM Background ─────────────────────
messaging.onBackgroundMessage((payload) => {
    console.log('[SW FCM] Recebeu push em background:', payload);
    
    const notificationTitle = payload.notification?.title || 'Novo Aviso na Escala';
    const notificationOptions = {
        body: payload.notification?.body,
        icon: '/assets/logo.png',
        badge: '/assets/logo.png',
        requireInteraction: true,
        vibrate: [200, 100, 200, 100, 400],
        data: payload.data || {}
    };

    return self.registration.showNotification(notificationTitle, notificationOptions);
});

// ── Click na notificação ──────────────────────────────────────
self.addEventListener('notificationclick', event => {
    const notification = event.notification;
    notification.close();

    const data = notification.data || {};
    const action = event.action; // if there are action buttons
    const scaleId = data.scaleId;

    let targetUrl = APP_URL;
    if (scaleId) {
        targetUrl = `${APP_URL}?action=view&scaleId=${scaleId}`;
    }

    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
            for (const client of clientList) {
                if (client.url.includes(self.location.origin)) {
                    client.focus();
                    client.postMessage({
                        type: 'NOTIFICATION_ACTION',
                        action: action || 'view',
                        scaleId: scaleId
                    });
                    return;
                }
            }
            return clients.openWindow(targetUrl);
        })
    );
});

// ── Fechar notificação ────────────────────────────────────────
self.addEventListener('notificationclose', event => {
    console.log('[SW FCM] Notificação fechada pelo usuário.');
});
