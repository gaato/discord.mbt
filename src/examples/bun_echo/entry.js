import { handleInteraction, trackBackground } from "../interactions_js/handler.js";

export function createHandler(config, onBackgroundError = console.error) {
  const background = trackBackground(onBackgroundError);
  const handler = (request) =>
    handleInteraction(request, config, (promise) => background.schedule(promise));
  handler.whenIdle = () => background.whenIdle();
  return handler;
}

if (import.meta.main) {
  const { DISCORD_PUBLIC_KEY: publicKey, DISCORD_TOKEN: token, DISCORD_APPLICATION_ID: applicationId } = Bun.env;
  if (!publicKey || !token || !applicationId) {
    throw new Error("Set DISCORD_PUBLIC_KEY, DISCORD_TOKEN and DISCORD_APPLICATION_ID");
  }
  Bun.serve({ fetch: createHandler({ publicKey, token, applicationId }) });
}
