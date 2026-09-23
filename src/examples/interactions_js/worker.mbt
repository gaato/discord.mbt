///|
/// Start one signed interaction dispatch for a JavaScript host.
///
/// The argument list is fixed by `handler.js`: an empty `signature` or
/// `timestamp` string means the header was absent.
pub fn start_signed_interaction(
  token : String,
  application_id : String,
  public_key : String,
  http_method : String,
  signature : String,
  timestamp : String,
  body : Bytes,
  api_base_url : String,
  abort_signal : @js_async.AbortSignal,
) -> @discord.InteractionHttpDispatch {
  // A malformed application id is a deployment error: abort here so the host
  // sees a thrown exception instead of a 500 dispatched to Discord.
  let application_id = try! (
    @model.Id::parse(application_id) : @model.ApplicationId)
  interaction_app().start_signed_http(
    {
      http_method,
      signature: if signature.is_empty() {
        None
      } else {
        Some(signature)
      },
      timestamp: if timestamp.is_empty() {
        None
      } else {
        Some(timestamp)
      },
      body,
    },
    token~,
    application_id~,
    public_key~,
    api_base_url~,
    abort_signal~,
  )
}
