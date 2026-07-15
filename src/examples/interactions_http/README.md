# Native HTTP interactions example

Set the bot token and application public key, then run the server:

```sh
DISCORD_TOKEN=... PUBLIC_KEY=... PORT=8080 moon run --target native src/examples/interactions_http
```

The example synchronizes one `/echo` command and listens on
`http://0.0.0.0:8080/`. Put it behind a TLS-terminating reverse proxy; TLS is a
deployment concern rather than part of this HTTP server.

In the Discord developer portal, set the application's **Interactions Endpoint
URL** to the public HTTPS URL routed to this server, for example
`https://bot.example.com/`.
