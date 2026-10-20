# HTTP interactions example (native and moonrun Wasm)

Set the bot token and application public key, then run the server:

```fish
# Supply DISCORD_TOKEN and PUBLIC_KEY through your environment or secret manager.
env PORT=8080 moon run --target native examples/interactions_http
# Or use the matching moonrun runtime:
env PORT=8080 moon run --target wasm examples/interactions_http
```

The Wasm build uses MoonBit host networking, not browser APIs or generic WASI.
Building still requires Node for the dependency prebuild hooks, but no native
voice library.

Set `GUILD_ID` to sync the `/echo` command to a single guild instead of globally. The example synchronizes one `/echo` command and listens on
`http://0.0.0.0:8080/`. Put it behind a TLS-terminating reverse proxy; TLS is a
deployment concern rather than part of this HTTP server.

In the Discord developer portal, set the application's **Interactions Endpoint
URL** to the public HTTPS URL routed to this server, for example
`https://bot.example.com/`.

## Restricted Wasm permissions

Build with the pinned toolchain and run the artifact with its matching
`moonrun` under a policy file:

```fish
moon build --target wasm --release examples/interactions_http
moonrun --policy discord-policy.json _build/wasm/release/build/local/discord_examples/interactions_http/interactions_http.wasm
```

A `discord-policy.json` for this server:

```json
{
  "env": {
    "required_from_host": ["DISCORD_TOKEN", "PUBLIC_KEY"],
    "from_host": ["GUILD_ID"],
    "set": {"PORT": "8080"}
  },
  "net": {
    "connect": ["discord.com:443"],
    "bind": ["0.0.0.0:8080"]
  }
}
```

Supply credentials through the environment, never in the policy file. In
policy mode, omitted environment, filesystem, network, and process
permissions are denied. This example synchronizes commands at startup; run it
only when you intend to update your application's commands. A REST-only
program needs the token and outbound connection permission but no bind
permission. The coordinator needs bind permission on its server address and
connect permission on each client. Add other destinations only for features
that actually need them.
