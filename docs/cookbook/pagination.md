# Paginate message history

Channel message pagination starts with the newest messages and moves backward
when no cursor is supplied:

```moonbit
///|
let pages = client.paginate_messages(channel_id, page_size=100)
for ;; {
  match pages.next_page() {
    Some(messages) => {
      for message in messages {
        println("\{message.id}: \{message.content}")
      }
    }
    None => break
  }
}
```

Start before or after a known message by supplying one cursor. `before`,
`after`, and `around` are mutually exclusive; `around` is a single-page
request.

Use `collect` for a bounded result:

```moonbit
///|
let recent = client
  .paginate_messages(channel_id, before=message_id, page_size=100)
  .collect(max=250)
```

Use `each` when the item callback is synchronous:

```moonbit
///|
client
.paginate_guild_members(guild_id)
.each(member => println("\{to_repr(member.user)}"))
```

All paginator methods consume the same mutable cursor state. Do not call them
concurrently. Empty pages and pages shorter than the configured page size mark
the end.

Available constructors cover messages, guild members, bans, audit-log entries,
scheduled-event users, poll-answer voters, and current-user guilds. Cursor
direction and endpoint maximums are encoded by each constructor.
