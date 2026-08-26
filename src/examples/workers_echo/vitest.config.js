import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      // Configure the local runtime directly so Wrangler never loads ignored
      // `.dev.vars` secrets into the test isolate. The deployment config is
      // checked separately with `wrangler deploy --dry-run`.
      main: "./entry.js",
      miniflare: { compatibilityDate: "2026-07-14" },
    }),
  ],
});
