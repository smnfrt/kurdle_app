'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "5b27923089bacccac7862d4d96d24295",
"version.json": "cc296d058fdc98a9bc0d2b6d8fbdaadd",
"splash/img/light-2x.png": "1606e1ad4583110fd1e51c13f51f787f",
"splash/img/dark-4x.png": "a379700ce140f8f5957c4ba7603a5f84",
"splash/img/light-3x.png": "5f9da5defb6247909fa8d6d973f355ec",
"splash/img/dark-3x.png": "5f9da5defb6247909fa8d6d973f355ec",
"splash/img/light-4x.png": "a379700ce140f8f5957c4ba7603a5f84",
"splash/img/dark-2x.png": "1606e1ad4583110fd1e51c13f51f787f",
"splash/img/dark-1x.png": "15771d32a0f9e5822891731e321c44be",
"splash/img/light-1x.png": "15771d32a0f9e5822891731e321c44be",
"index.html": "8e0035797d1881139fe4869f37e66798",
"/": "8e0035797d1881139fe4869f37e66798",
"main.dart.js": "3832175bbe4a83c5ae6571d7d4047c53",
"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"favicon.png": "046a59aa12631c00934c784677ba354d",
"icons/Icon-192.png": "403e8f616cc04549c4cff0cce6741088",
"icons/Icon-maskable-192.png": "403e8f616cc04549c4cff0cce6741088",
"icons/Icon-maskable-512.png": "62ec3cacaeb9c116a503005139fcdf6f",
"icons/Icon-512.png": "62ec3cacaeb9c116a503005139fcdf6f",
"manifest.json": "5e503536cd1f586b058b001b882ec801",
"assets/AssetManifest.json": "af84485e7fadeacf0e37a887ed12b016",
"assets/NOTICES": "a3e5f16ae20cfaffdd5cc0954394fa36",
"assets/FontManifest.json": "4b5de1ee59565883171ebb434a8a1e67",
"assets/AssetManifest.bin.json": "7ff4913e500c03c81b85a81a2afb407d",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "9cc86716f073c4f27f357b649aa645cb",
"assets/fonts/MaterialIcons-Regular.otf": "811dca8c8841205ded237f543f7e47ab",
"assets/assets/branding/icon-1024.png": "b5710bcc42d2ccb3d257582aa54320a7",
"assets/assets/allowed_guesses.txt": "9bbd1df54dec9076f5879c773c4e7900",
"assets/assets/sounds/win.wav": "f37d33fba38b75244ea3dff7b8263e8e",
"assets/assets/sounds/ai_turn.wav": "1a9a90819c3a409640eea40f3a502adb",
"assets/assets/sounds/lose.wav": "aa56c7c464c70129c810c90bfb62efa8",
"assets/assets/sounds/gen_sounds.py": "bf5b440c8079f50a985872299310975d",
"assets/assets/sounds/tile_return.wav": "540acc50c8b55883c1d109a80742c5cf",
"assets/assets/sounds/tile_pickup.wav": "b738e8b73a31b7f9ba31841e301a085b",
"assets/assets/sounds/tile_exchange.wav": "7c0dd6f906283ac956db1be7303d3b19",
"assets/assets/sounds/pass_turn.wav": "da05150e451093127b6198e2e6511dfe",
"assets/assets/sounds/score_up.wav": "6d6075d0a9eb728f58660da480432401",
"assets/assets/sounds/word_invalid.wav": "69cf79266b25414332e5dc07abf4864a",
"assets/assets/sounds/tile_place.wav": "63f797a08135f939edb54f40169f3c39",
"assets/assets/sounds/word_valid.wav": "396610cea5592d6c7c177606135e4aa9",
"assets/assets/ferheng/categories.json": "f005e6318e475202ee225f5708584bf6",
"assets/assets/ferheng/ATTRIBUTION.md": "7af902695f986e6dc48c0a6fb8880da3",
"assets/assets/ferheng/tr_meaning_overrides.json.gz": "3a9f394c5571deeeeb9309cff56f2ab8",
"assets/assets/ferheng/entries.ndjson.gz": "86cafd7b82bbc4bb920c1a6f172dc19e",
"assets/assets/ferheng/legacy_meanings.json": "c9fab51a93efd80736c2523f51f8a72a",
"assets/assets/ferheng/wordlist.txt.gz": "20651e58496d5e4ead4ceee6fdb953b0",
"assets/assets/answers.txt": "21e8d414f78328d3906fec7da24f12d6",
"assets/assets/kurdish_dictionary.txt": "07a0d035b1002101bb03068e3b9076ab",
"assets/assets/stats.json": "ad6ababb10c60786fa5f0202db183422",
"assets/assets/fonts/Manrope.ttf": "c329d9ac3c7bdb891ffa10296eadc08f",
"assets/assets/fonts/Inter.ttf": "bff0f6e3b9e2259a28313168a907054f",
"assets/assets/turkish_words.txt": "8fd9850ca4f179894d98c08cb54c4d88",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
