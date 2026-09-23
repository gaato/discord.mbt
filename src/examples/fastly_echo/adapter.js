import { handleInteraction } from "../interactions_js/handler.js";

// Fastly requires the first waitUntil call in the synchronous fetch callback.
export function respondToFetchEvent(event, config, onBackgroundError = console.error) {
  let background;
  const response = handleInteraction(event.request, config, (promise) => {
    background = promise;
  });
  event.waitUntil(response.then(() => background).catch(onBackgroundError));
  event.respondWith(response);
}
