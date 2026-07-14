# Send a direct message

Create or reuse a DM channel, then send through its channel ID:

```moonbit
///|
async fn dm_user(
  client : @dhttp.Client,
  user_id : @model.UserId,
  content : String,
) -> @model.Message {
  let channel = client.create_dm(user_id)
  client.create_message(
    channel.id,
    content~,
    allowed_mentions=@model.AllowedMentions::none(),
  )
}
```

`create_dm` is idempotent for an existing one-to-one DM. Sending a message can
still fail when the recipient does not accept DMs from the bot.

See [REST client](../guide/05-rest.md) for client lifetime and error behavior.
