# Upload a file

`FileUpload` carries the filename, bytes, content type, and optional attachment
description. Message-shaped endpoints switch to multipart automatically when
`files` is present.

```moonbit
///|
async fn send_report(
  client : @dhttp.Client,
  channel_id : @model.ChannelId,
  report : Bytes,
) -> @model.Message {
  let file = @dhttp.FileUpload(
    "report.csv",
    report,
    content_type="text/csv",
    description="Daily report",
  )
  client.create_message(
    channel_id,
    content="Report attached",
    files=[file],
  )
}
```

The same `files` argument is available on interaction responses, followups,
and edit methods. On edit, the supplied files replace the attachment list sent
in that request; preserve any attachments that should remain.
