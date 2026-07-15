///|
/// Fetch the current bot application.
pub async fn Client::get_current_application(
  self : Client,
) -> @model.Application raise DiscordHttpError {
  decode(self.request(GetCurrentApplication))
}
