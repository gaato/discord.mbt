///|
/// Webhooks: CRUD, token-auth flows, execute (normal/slack/github),
/// webhook message get/edit/delete.
async fn sec_webhooks(p : P) -> Unit {
  let c = p.client
  let g = p.guild_id
  let text = need(p.s.text, "text channel") catch {
    _ => {
      p.push("webhooks section", Skip, "no text channel")
      return
    }
  }
  let mut hook : (@model.WebhookId, String)? = None
  p.probe("create_webhook", () => {
    let webhook = c.create_webhook(
      text,
      "probe-hook",
      audit_reason="live probe",
    )
    let token = need(webhook.token, "webhook token")
    hook = Some((webhook.id, token))
    p.s.webhook = Some(webhook.id)
    "id=\{webhook.id}"
  })
  p.probe("get_channel_webhooks / get_guild_webhooks", () => {
    let chans = c.get_channel_webhooks(text)
    let guilds = c.get_guild_webhooks(g)
    "channel=\{chans.length()} guild=\{guilds.length()}"
  })
  p.probe("ChannelRef::webhooks / GuildRef::webhooks", () => {
    let a = c.channel_ref(text).webhooks()
    let b = c.guild_ref(g).webhooks()
    "channel=\{a.length()} guild=\{b.length()}"
  })
  guard hook is Some((wid, wtoken)) else { return }
  p.probe("get_webhook + WebhookRef::fetch", () => {
    let webhook = c.get_webhook(wid)
    ignore(c.webhook_ref(wid).fetch())
    "name=\{nul(webhook.name)}"
  })
  p.probe("modify_webhook + WebhookRef::edit", () => {
    let renamed = c.modify_webhook(wid, name="probe-hook-2")
    ignore(renamed)
    let back = c.webhook_ref(wid).edit(name="probe-hook")
    "name=\{nul(back.name)}"
  })
  p.probe("get_webhook_with_token + WebhookTokenRef::fetch", () => {
    let webhook = c.get_webhook_with_token(wid, wtoken)
    ignore(c.webhook_token_ref(wid, wtoken).fetch())
    "name=\{nul(webhook.name)}"
  })
  p.probe("modify_webhook_with_token + WebhookTokenRef::edit", () => {
    let renamed = c.modify_webhook_with_token(wid, wtoken, name="probe-hook-t")
    ignore(renamed)
    let back = c.webhook_token_ref(wid, wtoken).edit(name="probe-hook")
    "name=\{nul(back.name)}"
  })
  let tr = c.webhook_token_ref(wid, wtoken)
  let mut hook_msg : @model.MessageId? = None
  p.probe("execute_webhook (wait, custom identity)", () => {
    let msg = c.execute_webhook(
      wid,
      wtoken,
      content="live probe webhook message",
      username="probe-hook-alias",
    )
    hook_msg = Some(msg.id)
    "id=\{msg.id}"
  })
  p.probe("WebhookTokenRef::send (embed + file)", () => {
    let file = @dhttp.FileUpload(
      "hook.txt",
      b"webhook attachment\n",
      content_type="text/plain",
    )
    let msg = tr.send(content="handle layer webhook send", files=[file])
    "attachments=\{msg.attachments.length()}"
  })
  guard hook_msg is Some(mid) else { return }
  p.probe("get_webhook_message + WebhookMessageRef::fetch", () => {
    let msg = c.get_webhook_message(wid, wtoken, mid)
    ignore(tr.message_ref(mid).fetch())
    "content len=\{msg.content.length()}"
  })
  p.probe("edit_webhook_message + WebhookMessageRef::edit", () => {
    let edited = c.edit_webhook_message(wid, wtoken, mid, content="edited")
    ignore(edited)
    let again = tr.message_ref(mid).edit(content="edited twice")
    "edited=\{again.edited_timestamp is Value(_)}"
  })
  p.probe("delete_webhook_message", () => {
    c.delete_webhook_message(wid, wtoken, mid)
    "ok"
  })
  p.probe("WebhookMessageRef::delete", () => {
    let msg = tr.send(content="delete me via handle")
    tr.message_ref(msg.id).delete()
    "ok"
  })
  p.probe("execute_slack_compatible_webhook", () => {
    let payload : Json = { "text": "slack-compatible probe" }
    c.execute_slack_compatible_webhook(wid, wtoken, payload, wait=true)
    "ok"
  })
  p.probe("WebhookTokenRef::send_slack", () => {
    tr.send_slack({ "text": "slack via handle" }, wait=true)
    "ok"
  })
  p.probe("execute_github_compatible_webhook", () => {
    let payload : Json = {
      "action": "opened",
      "repository": {
        "id": 1,
        "name": "discord.mbt",
        "full_name": "gaato/discord.mbt",
        "html_url": "https://github.com/gaato/discord.mbt",
      },
      "sender": {
        "id": 2,
        "login": "live-probe",
        "html_url": "https://github.com/gaato",
        "avatar_url": "https://github.com/gaato.png",
      },
      "issue": {
        "id": 3,
        "number": 1,
        "title": "live probe",
        "html_url": "https://github.com/gaato/discord.mbt/issues/1",
        "user": {
          "id": 2,
          "login": "live-probe",
          "html_url": "https://github.com/gaato",
          "avatar_url": "https://github.com/gaato.png",
        },
      },
    }
    c.execute_github_compatible_webhook(
      wid,
      wtoken,
      payload,
      github_event="issues",
      wait=true,
    )
    "ok"
  })
  p.probe("WebhookTokenRef::send_github", () => {
    let payload : Json = {
      "action": "opened",
      "repository": {
        "id": 1,
        "name": "discord.mbt",
        "full_name": "gaato/discord.mbt",
        "html_url": "https://github.com/gaato/discord.mbt",
      },
      "sender": {
        "id": 2,
        "login": "live-probe",
        "html_url": "https://github.com/gaato",
        "avatar_url": "https://github.com/gaato.png",
      },
      "issue": {
        "id": 4,
        "number": 2,
        "title": "live probe 2",
        "html_url": "https://github.com/gaato/discord.mbt/issues/2",
        "user": {
          "id": 2,
          "login": "live-probe",
          "html_url": "https://github.com/gaato",
          "avatar_url": "https://github.com/gaato.png",
        },
      },
    }
    tr.send_github(payload, github_event="issues", wait=true)
    "ok"
  })
  p.probe("delete_webhook_with_token (secondary hook)", () => {
    let tmp = c.create_webhook(text, "probe-hook-tmp")
    let token = need(tmp.token, "webhook token")
    c.delete_webhook_with_token(tmp.id, token)
    "ok"
  })
  p.probe("WebhookTokenRef::delete (secondary hook)", () => {
    let tmp = c.create_webhook(text, "probe-hook-tmp2")
    let token = need(tmp.token, "webhook token")
    c.webhook_token_ref(tmp.id, token).delete()
    "ok"
  })
  p.probe("delete_webhook", () => {
    c.delete_webhook(wid, audit_reason="live probe cleanup")
    p.s.webhook = None
    "ok"
  })
  p.probe("WebhookRef::delete (secondary hook)", () => {
    let tmp = c.create_webhook(text, "probe-hook-tmp3")
    c.webhook_ref(tmp.id).delete(reason="live probe cleanup")
    "ok"
  })
}
