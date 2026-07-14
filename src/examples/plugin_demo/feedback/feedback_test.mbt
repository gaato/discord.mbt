///|
test "feedback feature installs a valid command graph" {
  let app = @discord.App::new(sync=Disabled)
  let feature = @feedback.FeedbackFeature::new(
    @feedback.FeedbackConfig::new(
      destination_channel=@model.Id::parse("800000000000000001"),
      cooldown_seconds=15,
    ),
  )
  feature.install(app)
  app.validate()
  inspect(feature.stored_count(), content="0")
}
