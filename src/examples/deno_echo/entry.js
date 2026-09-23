import { handleInteraction, trackBackground } from "../interactions_js/handler.js";

export function createHandler(config, onBackgroundError = console.error) {
  const background = trackBackground(onBackgroundError);
  const handler = (request) =>
    handleInteraction(request, config, (promise) => background.schedule(promise));
  handler.whenIdle = () => background.whenIdle();
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
