import { handleInteraction } from "../interactions_js/handler.js";

export default {
  fetch(request, env, ctx) {
    return handleInteraction(
      request,
      { publicKey: env.DISCORD_PUBLIC_KEY, token: env.DISCORD_TOKEN, applicationId: env.DISCORD_APPLICATION_ID },
      (background) => ctx.waitUntil(background),
    );
  },
};
