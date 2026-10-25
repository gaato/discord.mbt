import { handleInteraction } from "../interactions_js/handler.js";

// Fastly requires the first waitUntil call in the synchronous fetch callback.
export function respondToFetchEvent(event, config, onBackgroundError = console.error) {
  const response = handleInteraction(event.request, config, (promise) => {
    event.waitUntil(promise.catch(onBackgroundError));
  });
  event.respondWith(response);
}
