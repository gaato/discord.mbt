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
  class FakeGatewaySocket extends EventTarget {
    constructor(url) {
      super();
      this.url = url;
      this.readyState = 0;
      sockets.push(this);
      queueMicrotask(() => {
        this.readyState = 1;
        this.dispatchEvent(new Event("open"));
        this.message('{"op":10,"d":{"heartbeat_interval":60000}}');
      });
    }
    message(data) {
      const event = new Event("message");
      Object.defineProperty(event, "data", { value: data });
      this.dispatchEvent(event);
    }
    send(text) {
      const payload = JSON.parse(text);
      sent.push(payload);
      if (payload.op === 2) {
        this.message('{"op":0,"s":1,"t":"READY","d":{"v":10,"user":{"id":"1","username":"bot","discriminator":"0","global_name":null,"avatar":null},"guilds":[],"session_id":"saved-session","resume_gateway_url":"wss://resume.example","application":{"id":"42"},"shard":[0,1]}}');
      } else if (payload.op === 6) {
        this.message('{"op":0,"s":2,"t":"RESUMED","d":{}}');
      }
    }
    close(code = 1000) {
      this.readyState = 3;
      const event = new Event("close");
      Object.defineProperties(event, {
        code: { value: code },
        reason: { value: "test close" },
      });
      this.dispatchEvent(event);
    }
  }
  vi.stubGlobal("WebSocket", FakeGatewaySocket);
  vi.stubGlobal("fetch", vi.fn(async () =>
    new Response("[]", {
      status: 200,
      headers: { "content-type": "application/json" },
    })));
  return { sockets, sent };
}

afterEach(async () => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  await reset();
});

describe("Gateway Durable Object", () => {
  it("keeps controls private and explicit stop survives alarms and cron", async () => {
    vi.stubGlobal("WebSocket", class {
      constructor() { throw new Error("local connector refused"); }
    });
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
    expect(sockets[0].readyState).toBe(3);
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
    expect(sockets[0].readyState).toBe(3);
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
    await control("/stop", "POST");
  }, 15_000);
});
