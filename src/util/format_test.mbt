///|
test "mention formatters" {
  debug_inspect(
    [
      @util.user_mention(@model.Id(1UL)),
      @util.channel_mention(@model.Id(2UL)),
      @util.role_mention(@model.Id(3UL)),
      @util.slash_command_mention(
        name="permissions user get",
        command_id=@model.Id(4UL),
      ),
      @util.custom_emoji_mention(name="wave", emoji_id=@model.Id(5UL)),
      @util.custom_emoji_mention(
        name="dance",
        emoji_id=@model.Id(6UL),
        animated=true,
      ),
    ],
    content=(
      #|[
      #|  "<@1>",
      #|  "<#2>",
      #|  "<@&3>",
      #|  "</permissions user get:4>",
      #|  "<:wave:5>",
      #|  "<a:dance:6>",
      #|]
    ),
  )
}

///|
test "timestamp formatter supports every Discord style" {
  debug_inspect(
    [
      @util.timestamp(1615486537L),
      @util.timestamp(1615486537L, style=@util.TimestampStyle::ShortTime),
      @util.timestamp(1615486537L, style=@util.TimestampStyle::LongTime),
      @util.timestamp(1615486537L, style=@util.TimestampStyle::ShortDate),
      @util.timestamp(1615486537L, style=@util.TimestampStyle::LongDate),
      @util.timestamp(1615486537L, style=@util.TimestampStyle::ShortDateTime),
      @util.timestamp(1615486537L, style=@util.TimestampStyle::LongDateTime),
      @util.timestamp(1615486537L, style=@util.TimestampStyle::Relative),
      @util.timestamp_from_model(
        @model.Timestamp("2021-03-11T18:15:37Z"),
        style=@util.TimestampStyle::Relative,
      ),
    ],
    content=(
      #|[
      #|  "<t:1615486537>",
      #|  "<t:1615486537:t>",
      #|  "<t:1615486537:T>",
      #|  "<t:1615486537:d>",
      #|  "<t:1615486537:D>",
      #|  "<t:1615486537:f>",
      #|  "<t:1615486537:F>",
      #|  "<t:1615486537:R>",
      #|  "<t:1615486537:R>",
      #|]
    ),
  )
}
