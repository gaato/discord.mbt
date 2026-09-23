# Wasm host follow-up draft

Local experiment on 2026-09-23, for a possible upstream discussion. This has
not been posted.

## Reproduction

`moon build --target wasm --release src/examples/interactions_http` succeeds,
but the resulting core module imports 118 functions from `moonbitlang/async`,
eight from `__moonbit_fs_unstable`, and one from `__moonbit_time_unstable`.
It therefore cannot run as a generic WASIp2 HTTP component under Spin.

```fish
wasm-tools print _build/wasm/release/build/examples/interactions_http/interactions_http.wasm | rg '^  \(import '
```

The separate [Spin Component experiment](../experiments/spin_interactions/README.md)
uses pure MoonBit `gaato/discord/verify` and `gaato/discord/model` successfully
through generated WIT bindings. Its synchronous signed PING and echo work under
Spin 4.1.0, but it does not call `@discord.App::serve` or make outbound REST
requests. The JS adapters run the same `App` on workerd and Deno, including
deferred REST.

## Suggested upstream scope

- `moonbitlang/async` and moonrun: define a host-neutral async runtime boundary
  and an adapter for at least one non-moonrun Wasm host. Keep cancellation,
  timers, task groups, WebSocket, and socket ownership observable in tests.
- Component tooling and `wit-bindgen`: document a matched MoonBit/bindgen
  matrix. With this toolchain, wit-bindgen 0.54.0 generated a Component that
  loaded but corrupted HTTP strings; 0.62.0 produced correct request and
  response strings in the same Spin test.
- `moonbitlang/core`: no change is demonstrated by this experiment. The
  verifier and model parser work on the general Wasm target. A core issue
  would need a smaller reproduction independent of `async` or generated WIT.

An upstream issue should ask for the supported adapter contract and test
matrix, and attach the minimal import list and Spin test result. This draft
does not assume that WASIp2 can directly replace the current async host ABI.
