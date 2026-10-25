///|
// The JavaScript-only signed interaction dispatch bridge.

///|
/// Build the bounded Web Request adapter for a signed interaction App.
/// The host retains the synchronously registered promise for deferred work.
pub fn interaction_fetch_handler(
  app : @app.App,
  token~ : String,
  application_id~ : @model.ApplicationId,
  public_key~ : String,
  api_base_url? : String,
  path? : String,
  deadline_ms? : Int32,
  max_body_bytes? : Int32,
) -> (@fetch.JsRequest, @fetch.JsBackground) -> @fetch.JsPromise {
  @endpoint_http.interaction_fetch_handler(
    app,
    token~,
    application_id~,
    public_key~,
    api_base_url?,
    path?,
    deadline_ms?,
    max_body_bytes?,
  )
}

///|
/// A JavaScript `{ response, background }` object for one interaction dispatch.
pub using @app {type InteractionHttpDispatch}

///|
/// The JavaScript response a dispatch resolves to: an object with `status`,
/// `contentType`, and `body`.
pub using @app {type InteractionHttpJsResponse}
