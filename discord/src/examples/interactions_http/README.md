# HTTP interactions example (native and moonrun Wasm)

Set the bot token and application public key, then run the server:

```fish
# Supply DISCORD_TOKEN and PUBLIC_KEY through your environment or secret manager.
env PORT=8080 moon run --target native src/examples/interactions_http
# Or use the matching moonrun runtime:
env PORT=8080 moon run --target wasm src/examples/interactions_http
```

The Wasm build uses MoonBit host networking, not browser APIs or generic WASI.
For restricted host access, build with `--target wasm --release` and run the
artifact with `moonrun --policy`; see the [root README](../../../README.md#wasm-runtime-and-permissions)
for the environment, outbound HTTPS, and bind permissions. Building still
requires Node for the dependency prebuild hooks, but no native voice library.

Set `GUILD_ID` to sync the `/echo` command to a single guild instead of globally. The example synchronizes one `/echo` command and listens on
`http://0.0.0.0:8080/`. Put it behind a TLS-terminating reverse proxy; TLS is a
deployment concern rather than part of this HTTP server.

In the Discord developer portal, set the application's **Interactions Endpoint
URL** to the public HTTPS URL routed to this server, for example
`https://bot.example.com/`.
