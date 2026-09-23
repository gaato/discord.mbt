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
  const publicKey = Deno.env.get("DISCORD_PUBLIC_KEY");
  const token = Deno.env.get("DISCORD_TOKEN");
  const applicationId = Deno.env.get("DISCORD_APPLICATION_ID");
  if (!publicKey || !token || !applicationId) {
    throw new Error("Set DISCORD_PUBLIC_KEY, DISCORD_TOKEN and DISCORD_APPLICATION_ID");
  }
  Deno.serve(createHandler({ publicKey, token, applicationId }));
}
