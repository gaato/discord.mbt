// Import inside an event: MoonBit initializes a hasher with crypto.getRandomValues,
// which Workers cannot call while evaluating the module at startup.
let workerModule;
function loadWorkerModule() {
  workerModule ??= import(
    "../../../_build/js/release/build/examples/workers_gateway/workers_gateway.js"
  );
  return workerModule;
}

const json = (body) =>
  new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json" },
  });

export class GatewayShard {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.handle = null;
    this.serial = Promise.resolve();
    this.loadModule = loadWorkerModule;
  }

  // Every control and alarm transition shares one queue. A completed stop is
  // always ordered after an earlier start, including its dynamic import.
  enqueue(action) {
    const result = this.serial.then(action, action);
    this.serial = result.catch(() => {});
    return result;
  }

  isRunning() {
    return this.handle !== null && !this.handle.settled;
  }

  async ensureRunning() {
    if (this.isRunning()) return;
    const { start_bot } = await this.loadModule();
    const sessions = (await this.ctx.storage.get("sessions")) ?? "{}";
    const controller = new AbortController();
    const bridge = start_bot(
      this.env.DISCORD_TOKEN,
      this.env.DISCORD_GATEWAY_URL ?? "wss://gateway.discord.gg",
      sessions,
      controller.signal,
    );
    const handle = { bridge, controller, settled: false };
    this.handle = handle;
    bridge.finished.then(
      () => this.onFinished(handle),
      (error) => this.onFinished(handle, error),
    ).catch((error) => console.error("[gateway] finish cleanup", String(error)));
  }

  async onFinished(handle, error) {
    handle.settled = true;
    if (error && !handle.controller.signal.aborted) {
      console.error("[gateway] stopped", String(error));
    }
    await this.enqueue(async () => {
      if (this.handle !== handle) return;
      this.handle = null;
      if (await this.ctx.storage.get("enabled")) {
        await this.ctx.storage.setAlarm(Date.now() + 30_000);
      }
    });
  }

  async persist() {
    if (this.isRunning()) {
      await this.ctx.storage.put("sessions", this.handle.bridge.sessions());
    }
  }

  async reconcile() {
    if (!(await this.ctx.storage.get("enabled"))) return false;
    if (!this.env.DISCORD_TOKEN) {
      console.error("[gateway] DISCORD_TOKEN is not configured");
      await this.ctx.storage.setAlarm(Date.now() + 30_000);
      return false;
    }
    await this.ensureRunning();
    await this.ctx.storage.setAlarm(Date.now() + 30_000);
    return true;
  }

  async stop() {
    await this.ctx.storage.put("enabled", false);
    await this.ctx.storage.deleteAlarm();
    const handle = this.handle;
    this.handle = null;
    if (handle) {
      handle.controller.abort();
      await handle.bridge.finished.catch(() => {});
    }
    // Graceful close uses code 1000; Discord invalidates that session.
    await this.ctx.storage.delete("sessions");
  }

  async fetch(request) {
    const path = new URL(request.url).pathname;
    if (request.method === "GET" && path === "/status") {
      return this.enqueue(async () =>
        json({
          running: this.isRunning(),
          enabled: (await this.ctx.storage.get("enabled")) === true,
        }),
      );
    }
    if (request.method === "GET" && path === "/start") {
      return this.enqueue(async () => {
        await this.ctx.storage.put("enabled", true);
        await this.reconcile();
        return json({ running: this.isRunning() });
      });
    }
    if (request.method === "POST" && path === "/stop") {
      return this.enqueue(async () => {
        await this.stop();
        return json({ running: false });
      });
    }
    if (request.method === "POST" && path === "/reconcile") {
      return this.enqueue(async () => {
        await this.reconcile();
        return json({ running: this.isRunning() });
      });
    }
    return new Response("Not found", { status: 404 });
  }

  async alarm() {
    return this.enqueue(async () => {
      if (!(await this.ctx.storage.get("enabled"))) {
        await this.ctx.storage.deleteAlarm();
        return;
      }
      await this.persist();
      await this.reconcile();
    });
  }
}

const shard = (env) => env.GATEWAY.get(env.GATEWAY.idFromName("gateway"));

export default {
  async fetch(request, env) {
    if (!env.CONTROL_TOKEN) {
      return new Response("Control token is not configured", { status: 503 });
    }
    if (request.headers.get("authorization") !== `Bearer ${env.CONTROL_TOKEN}`) {
      return new Response("Unauthorized", { status: 401 });
    }
    const path = new URL(request.url).pathname;
    if (path === "/start" && !env.DISCORD_TOKEN) {
      return new Response("Discord token is not configured", { status: 503 });
    }
    if (!(path === "/start" || path === "/status" || path === "/stop")) {
      return new Response("Not found", { status: 404 });
    }
    return shard(env).fetch(request);
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(
      shard(env).fetch("https://gateway.internal/reconcile", { method: "POST" }),
    );
  },
};
