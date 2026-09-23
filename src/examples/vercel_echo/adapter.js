import { handleInteraction } from "../interactions_js/handler.js";

export function createVercelHandler(config, waitUntil, onBackgroundError = console.error) {
  return {
    fetch(request) {
      return handleInteraction(request, config, (background) => {
        waitUntil(background.catch(onBackgroundError));
      });
    },
  };
}
