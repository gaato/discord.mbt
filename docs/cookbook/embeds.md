# Send an embed

Embed models are public records. Set fields that Discord should receive and use
`None` for the rest:

```moonbit
///|
fn status_embed() -> @model.Embed {
  {
    title: Some("Build complete"),
    typ: None,
    url: Some("https://example.com/builds/42"),
    description: Some("All checks passed."),
    timestamp: Some(@model.Timestamp("2026-07-15T00:00:00Z")),
    color: Some(0x57F287),
    footer: Some({
      text: "build 42",
      icon_url: None,
      proxy_icon_url: None,
    }),
    image: None,
    thumbnail: None,
    video: None,
    provider: None,
    author: None,
    fields: Some([
      { name: "Target", value: "native", inline: Some(true) },
      { name: "Tests", value: "325 passed", inline: Some(true) },
    ]),
  }
}

///|
let message = client.create_message(channel_id, embeds=[status_embed()])
```

For an interaction handler, pass the same value to
`CommandReply::message(embeds=[...])`, `ctx.respond`, or a followup method.
Discord applies its documented embed count and text-length limits.
