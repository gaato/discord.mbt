///|
/// Settings supplied by the application that installs the feedback feature.
pub(all) struct FeedbackConfig {
  destination_channel : @model.ChannelId
  cooldown_seconds : Int
}

///|
pub fn FeedbackConfig::new(
  destination_channel~ : @model.ChannelId,
  cooldown_seconds? : Int = 30,
) -> FeedbackConfig {
  { destination_channel, cooldown_seconds }
}

///|
priv struct FeedbackForm {
  topic : String
  details : String?
}

///|
/// Feature state lives in this value and is captured by the registered modal
/// handler. Discord models remain plain data.
pub struct FeedbackFeature {
  priv config_ : FeedbackConfig
  priv mut stored_ : Int
}

///|
pub fn FeedbackFeature::new(config : FeedbackConfig) -> FeedbackFeature {
  { config_: config, stored_: 0 }
}

///|
/// Number of submissions stored since this feature instance was installed.
pub fn FeedbackFeature::stored_count(self : FeedbackFeature) -> Int {
  self.stored_
}

///|
fn feedback_modal() -> @discord.Modal[FeedbackForm] {
  @discord.modal(
    custom_id="plugin-feedback",
    title="Send feedback",
    fields=@discord.ModalFields::map2(
      @discord.text_field(custom_id="topic", label="Topic", max_length=100),
      @discord.text_field(
        custom_id="details",
        label="Details",
        style=Paragraph,
        max_length=1000,
      ).optional(),
      (topic, details) => { topic, details },
    ),
  )
}

///|
/// Register this feature's command and modal handler on an App.
pub fn FeedbackFeature::install(
  self : FeedbackFeature,
  app : @discord.App,
) -> Unit {
  let modal = feedback_modal()
  app.command(
    @discord.slash(
      name="feedback",
      description="Send feedback to the bot maintainers",
      args=@discord.Args::unit(),
      handler=Immediate((_, _) => ShowModal(modal.show())),
    )
    .check(@discord.guild_only())
    .cooldown(seconds=self.config_.cooldown_seconds, bucket=User),
  )
  app.on_modal(
    modal,
    Deferred(ephemeral=true, (ctx, form) => {
      let details = form.details.unwrap_or("(no details)")
      ctx
      .app()
      .http()
      .channel_ref(self.config_.destination_channel)
      .send(
        content="Feedback from <@\{ctx.user().id}>\n" +
          "Topic: \{form.topic}\n\{details}",
        allowed_mentions=@model.AllowedMentions::none(),
      )
      |> ignore
      self.stored_ += 1
      ctx.edit_original(content="Thanks. Your feedback was saved.") |> ignore
    }),
  )
}

///|
/// Install a feedback feature without retaining its state handle. The
/// registered closures keep the feature alive.
pub fn install_feedback(app : @discord.App, config~ : FeedbackConfig) -> Unit {
  FeedbackFeature::new(config).install(app)
}
