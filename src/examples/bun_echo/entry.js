import { handleInteraction } from "../interactions_js/handler.js";

export function createHandler(config, onBackgroundError = console.error) {
  const pending = new Set();
  const handler = (request) =>
    handleInteraction(request, config, (background) => {
      const tracked = background.catch(onBackgroundError).finally(() => {
        pending.delete(tracked);
      });
      pending.add(tracked);
    });
  handler.whenIdle = () => Promise.all([...pending]);
  return handler;
}

if (import.meta.main) {
  const { DISCORD_PUBLIC_KEY: publicKey, DISCORD_TOKEN: token, DISCORD_APPLICATION_ID: applicationId } = Bun.env;
  if (!publicKey || !token || !applicationId) {
    throw new Error("Set DISCORD_PUBLIC_KEY, DISCORD_TOKEN and DISCORD_APPLICATION_ID");
  }
  Bun.serve({ fetch: createHandler({ publicKey, token, applicationId }) });
}
