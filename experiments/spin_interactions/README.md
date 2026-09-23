# Spin 4.1 WASIp2 interaction experiment

This MoonBit component exports `wasi:http/incoming-handler@0.2.6`. It imports
Spin's `fermyon:spin/variables@2.0.0` to read the Discord public key and uses
the library's `verify` and `model` packages. It accepts signed PING and one
immediate `echo` command. The separate [Deno example](../../src/examples/deno_echo/README.md)
exercises the full shared `App`, including deferred Discord REST.

The `wit/` definitions come from
[wasi-http v0.2.6](https://github.com/WebAssembly/wasi-http/releases/tag/v0.2.6),
with `discord.wit` and `deps/spin/variables.wit` defining the adapter's Spin
world. The generated bindings were made with `wit-bindgen 0.62.0`. Version
0.54.0 built but corrupted request/response strings with the current MoonBit
ABI; the newer generator fixed the observed corruption. `handler.mbt` and the
imports in the generated `moon.pkg` files are the handwritten portion.

## Build and test locally

From the repository root, with MoonBit, wasm-tools 1.246.2, Spin 4.1.0, and
Node.js installed:

```fish
moon -C experiments/spin_interactions build --target wasm --release --deny-warn
wasm-tools component embed experiments/spin_interactions/wit experiments/spin_interactions/_build/wasm/release/build/gaato/spin-discord/gen/gen.wasm --world wasi:http/discord --encoding utf16 --output /tmp/discord-spin-embedded.wasm
wasm-tools component new /tmp/discord-spin-embedded.wasm --output experiments/spin_interactions/target/discord.component.wasm
node --test experiments/spin_interactions/test.mjs
```

The test starts Spin on loopback, generates a temporary Ed25519 key, and sends
signed PING and echo requests plus invalid requests. It does not call Discord.
Set `SPIN_BIN` if `spin` is not on `PATH`.

The experiment stops at immediate responses. The current `@discord.App` HTTP
dispatch depends on `moonbitlang/async` host imports that Spin does not
implement, so this Component directly calls the existing verifier and model
parser. Outbound HTTP, deferred callbacks, and production deployment are not
established by this test.
