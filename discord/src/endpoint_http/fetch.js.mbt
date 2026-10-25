///|
/// Adapt a signed Discord App to Web Request/Response. The host must retain
/// the synchronously registered background promise until deferred work ends.
/// Each dispatch owns its REST client; aborting the response waiter does not
/// cancel already started app work. Request bytes are bounded by the adapter.
pub fn interaction_fetch_handler(
  app : @app.App,
  token~ : String,
  application_id~ : @model.ApplicationId,
  public_key~ : String,
  api_base_url~ : String = "https://discord.com",
  path~ : String = "/",
  deadline_ms~ : Int32 = 2500,
  max_body_bytes~ : Int32 = 1048576,
) -> (@fetch.JsRequest, @fetch.JsBackground) -> @fetch.JsPromise {
  let verifier = try @verify.InteractionVerifier::new(public_key) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
  @fetch.fetch_handler(
    request => {
      guard verifier is Some(verifier) else {
        return text_response(401, "invalid signature")
      }
      guard request.attributes.get(@hmodel.background) is Some(schedule) else {
        return text_response(500, "missing background owner")
      }
      let responses : @aqueue.Queue[Unit] = Queue(kind=Unbounded)
      let pending : Ref[@hmodel.Response?] = Ref(None)
      let wanted = Ref(true)
      defer {
        wanted.val = false
        if pending.val is Some(reply) {
          reply.close()
        }
      }
      schedule(() => {
        let mut sent = false
        errdefer @async.protect_from_cancel(() => {
          if !sent && wanted.val {
            pending.val = Some(text_response(500, "internal server error"))
            responses.put(())
          }
        })
        @async.with_task_group(group => {
          let client = @dhttp.Client(token, base_url=api_base_url)
          group.add_defer(() => client.close())
          let endpoint = app.serve(
            group,
            access=Client(client),
            application_id~,
          )
          let handler = interaction_handler(
            endpoint,
            verifier,
            path~,
            deadline_ms~,
            max_body_bytes~,
            warn=warning => app.warn(warning),
          )
          let reply = handler(request)
          if wanted.val {
            pending.val = Some(reply)
            responses.put(())
          } else {
            reply.close()
          }
          sent = true
        })
      })
      responses.get() catch {
        _ => return text_response(500, "interaction dispatch failed")
      }
      let reply = pending.val.unwrap()
      pending.val = None
      reply
    },
    max_body_bytes~,
  )
}
