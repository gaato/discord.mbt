import {
  createExecutionContext,
  env,
  reset,
  runDurableObjectAlarm,
  runInDurableObject,
  waitOnExecutionContext,
} from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../entry.js";

const stub = () => env.GATEWAY.get(env.GATEWAY.idFromName("gateway"));
const request = (path, method = "GET", token = "test-control-token") =>
  new Request(`https://worker.example${path}`, {
    method,
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
const control = (path, method, token) => worker.fetch(request(path, method, token), env);

function installFakeGateway() {
  const sockets = [];
  const sent = [];
  // mttp uses Workers' fetch upgrade path. Keep the real WebSocketPair so
  // READY, cancellation, and resume exercise workerd's socket lifecycle.
  vi.stubGlobal("WebSocket", vi.fn(() => {
    throw new Error("Workers gateway must use fetch upgrade");
  }));
  const fetch = vi.fn(async (url, options) => {
    const target = new URL(url);
    if (target.hostname === "127.0.0.1" || target.hostname === "resume.example") {
      expect(new Headers(options?.headers).get("Upgrade")).toBe("websocket");
      expect(target.protocol).toBe(target.hostname === "resume.example" ? "https:" : "http:");
      expect(target.searchParams.get("v")).toBe("10");
      expect(target.searchParams.get("encoding")).toBe("json");
      const { 0: client, 1: server } = new WebSocketPair();
      const connection = { url: target.href, closeCode: null };
      sockets.push(connection);
      server.accept();
      server.addEventListener("close", ({ code }) => {
        connection.closeCode = code;
      });
      server.addEventListener("message", ({ data }) => {
        const payload = JSON.parse(data);
        sent.push(payload);
        if (payload.op === 2) {
          server.send('{"op":0,"s":1,"t":"READY","d":{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"saved-session","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[0,1]}}');
        } else if (payload.op === 6) {
          server.send('{"op":0,"s":2,"t":"RESUMED","d":{}}');
        }
      });
      server.send('{"op":10,"d":{"heartbeat_interval":60000}}');
      return new Response(null, { status: 101, webSocket: client });
    }
    return new Response("[]", {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  });
  vi.stubGlobal("fetch", fetch);
  return { sockets, sent };
}

afterEach(async () => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  await reset();
});

describe("Gateway Durable Object", () => {
  it("keeps controls private and explicit stop survives alarms and cron", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => {
      throw new Error("local connector refused");
    }));
    const missing = await control("/status", "GET", "wrong");
    expect(missing.status).toBe(401);
    const noToken = await control("/status", "GET", "");
    expect(noToken.status).toBe(401);
    expect((await worker.fetch(request("/status"), {
      ...env,
      CONTROL_TOKEN: undefined,
    })).status).toBe(503);
    expect((await worker.fetch(request("/start"), {
      ...env,
      DISCORD_TOKEN: undefined,
    })).status).toBe(503);
    const before = await control("/status");
    expect(await before.json()).toEqual({ running: false, enabled: false });
    const started = await control("/start");
    expect(await started.json()).toEqual({ running: true });
    expect(await runDurableObjectAlarm(stub())).toBe(true);
    expect(await runInDurableObject(stub(), (_, state) => state.storage.get("sessions")))
      .toBe("{}");
    const stopped = await control("/stop", "POST");
    expect(await stopped.json()).toEqual({ running: false });
    expect(await runInDurableObject(stub(), (_, state) => state.storage.get("sessions")))
      .toBeUndefined();
    expect(await runDurableObjectAlarm(stub())).toBe(false);
    const ctx = createExecutionContext();
    await worker.scheduled({}, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(await (await control("/status")).json()).toEqual({
      running: false,
      enabled: false,
    });
  });

  it("orders a start still loading its module before a completed stop", async () => {
    let releaseLoad;
    let starts = 0;
    const loading = new Promise((resolve) => { releaseLoad = resolve; });
    await runInDurableObject(stub(), (instance) => {
      instance.loadModule = () => loading;
    });
    const starting = control("/start");
    await vi.waitFor(async () => {
      const enabled = await runInDurableObject(stub(), (_, state) =>
        state.storage.get("enabled"));
      expect(enabled).toBe(true);
    });
    const stopping = control("/stop", "POST");
    releaseLoad({
      start_bot: (_token, _url, _sessions, signal) => {
        starts += 1;
        return {
          sessions: () => "{}",
          finished: new Promise((_, reject) => {
            signal.addEventListener("abort", () => reject(new Error("aborted")), {
              once: true,
            });
          }),
        };
      },
    });
    await starting;
    await stopping;
    expect(starts).toBe(1);
    expect(await (await control("/status")).json()).toEqual({
      running: false,
      enabled: false,
    });
    expect(await runDurableObjectAlarm(stub())).toBe(false);
  });

  it("stops an active READY bot and clears its saved session", async () => {
    const readyLog = vi.spyOn(console, "log");
    const { sockets } = installFakeGateway();
    expect((await control("/start")).status).toBe(200);
    await vi.waitFor(async () => {
      const sessions = await runInDurableObject(stub(), (instance) =>
        instance.handle?.bridge.sessions());
      expect(JSON.parse(sessions)["0"].ready.session_id).toBe("saved-session");
    });
    await vi.waitFor(() => {
      expect(readyLog).toHaveBeenCalledWith("[gateway] ready as bot");
    });
    expect(await runDurableObjectAlarm(stub())).toBe(true);
    expect((await control("/stop", "POST")).status).toBe(200);
    await vi.waitFor(() => expect(sockets[0].closeCode).toBe(1000));
    expect(await runInDurableObject(stub(), (_, state) =>
      state.storage.get("sessions"))).toBeUndefined();
    expect(await (await control("/status")).json()).toEqual({
      running: false,
      enabled: false,
    });
  });

  it("persists a real READY snapshot and resumes from it", async () => {
    const { sockets, sent } = installFakeGateway();
    expect((await control("/start")).status).toBe(200);
    await vi.waitFor(async () => {
      const sessions = await runInDurableObject(stub(), (instance) =>
        instance.handle?.bridge.sessions());
      expect(JSON.parse(sessions)["0"].ready.session_id).toBe("saved-session");
    });
    expect(sent.some((payload) => payload.op === 2)).toBe(true);
    expect(await runDurableObjectAlarm(stub())).toBe(true);
    const persisted = await runInDurableObject(stub(), (_, state) =>
      state.storage.get("sessions"));
    expect(JSON.parse(persisted)["0"].gateway.sequence).toBe("1");
    await runInDurableObject(stub(), async (instance) => {
      const handle = instance.handle;
      handle.controller.abort();
      await handle.bridge.finished.catch(() => {});
    });
    await vi.waitFor(() => expect(sockets[0].closeCode).toBe(1000));
    const ctx = createExecutionContext();
    await worker.scheduled({}, env, ctx);
    await waitOnExecutionContext(ctx);
    await vi.waitFor(() => {
      expect(sent.some((payload) => payload.op === 6)).toBe(true);
    });
    const resume = sent.find((payload) => payload.op === 6);
    expect(resume.d.session_id).toBe("saved-session");
    expect(resume.d.seq).toBe(1);
    expect(sockets.at(-1).url).toContain("resume.example");
    await vi.waitFor(async () => {
      const sessions = await runInDurableObject(stub(), (instance) =>
        instance.handle?.bridge.sessions());
      expect(JSON.parse(sessions)["0"].gateway.sequence).toBe("2");
    });
    await control("/stop", "POST");
  }, 15_000);
});
