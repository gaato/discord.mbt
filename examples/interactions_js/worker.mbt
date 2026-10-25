///|
/// Start a Web Request dispatch through the shared mttp Fetch adapter.
pub fn handle_interaction(
  token : String,
  application_id : String,
  public_key : String,
  api_base_url : String,
  path : String,
  request : @fetch.JsRequest,
  background : @fetch.JsBackground,
) -> @fetch.JsPromise {
  let application_id = try! (
    @model.Id::parse(application_id) : @model.ApplicationId)
  let app = try! interaction_app()
  let handler = @discord.interaction_fetch_handler(
    app,
    token~,
    application_id~,
    public_key~,
    api_base_url~,
    path~,
  )
  handler(request, background)
}
