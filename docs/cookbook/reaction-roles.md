# Reaction roles

Subscribe to reaction add and remove events, identify the configured emoji,
then update the member role through the REST client.

```moonbit
///|
fn install_reaction_role(
  bot : @discord.Bot,
  role_id : @model.RoleId,
) -> Unit {
  bot.on(@discord.Events::message_reaction_add(), (ctx, event) => {
    guard event.guild_id is Some(guild_id) else { return }
    guard event.emoji.name.to_option() == Some("✅") else { return }
    if event.user_id == ctx.ready().user.id {
      return
    }
    ctx
    .app()
    .http()
    .add_member_role(
      guild_id,
      event.user_id,
      role_id,
      audit_reason="reaction role",
    )
  })

  bot.on(@discord.Events::message_reaction_remove(), (ctx, event) => {
    guard event.guild_id is Some(guild_id) else { return }
    guard event.emoji.name.to_option() == Some("✅") else { return }
    ctx
    .app()
    .http()
    .remove_member_role(
      guild_id,
      event.user_id,
      role_id,
      audit_reason="reaction role removed",
    )
  })
}
```

The bot needs the `Manage Roles` permission, and its highest role must be above
the assigned role. Typed subscriptions infer the non-privileged reaction
delivery intents when `Bot::new` omits an explicit `intents` value. If intents
are explicit, include `Intents::guild_message_reactions()`.

Production handlers should also restrict the configured message and channel
IDs and make the add/remove operations idempotent at the application level.
