// Auto-generated service worker for PWA
'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';
const RESOURCES = { ... }; // huge list of all files

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keyList) => {
    return Promise.all(keyList.map((key) => {
      if (key !== CACHE_NAME) return caches.delete(key);
    }));
  }));
});