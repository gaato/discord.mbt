import { waitUntil } from "@vercel/functions";
import { createVercelHandler } from "../adapter.js";

export default {
  fetch(request) {
    const handler = createVercelHandler(
      {
        publicKey: process.env.DISCORD_PUBLIC_KEY,
        token: process.env.DISCORD_TOKEN,
        applicationId: process.env.DISCORD_APPLICATION_ID,
      },
      waitUntil,
    );
    return handler.fetch(request);
  },
};
