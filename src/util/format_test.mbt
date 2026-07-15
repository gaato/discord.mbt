///|
test "mention formatters" {
  debug_inspect(
    [
      @util.user_mention(Id(1UL)),
      @util.channel_mention(Id(2UL)),
      @util.role_mention(Id(3UL)),
      @util.slash_command_mention(
        name="permissions user get",
        command_id=Id(4UL),
      ),
      @util.custom_emoji_mention(name="wave", emoji_id=Id(5UL)),
      @util.custom_emoji_mention(name="dance", emoji_id=Id(6UL), animated=true),
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
      @util.timestamp(1615486537L, style=ShortTime),
      @util.timestamp(1615486537L, style=LongTime),
      @util.timestamp(1615486537L, style=ShortDate),
      @util.timestamp(1615486537L, style=LongDate),
      @util.timestamp(1615486537L, style=ShortDateTime),
      @util.timestamp(1615486537L, style=LongDateTime),
      @util.timestamp(1615486537L, style=Relative),
      @util.timestamp_from_model(
        Timestamp("2021-03-11T18:15:37Z"),
        style=Relative,
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
