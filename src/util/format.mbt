///|
/// Format a user mention.
///
/// ```mbt check
/// test "format Discord mentions" {
///   let user_id : @model.UserId = Id(10UL)
///   let channel_id : @model.ChannelId = Id(20UL)
///   let command_id : @model.CommandId = Id(30UL)
///   inspect(@util.user_mention(user_id), content="<@10>")
///   inspect(@util.channel_mention(channel_id), content="<#20>")
///   inspect(
///     @util.slash_command_mention(name="echo text", command_id~),
///     content="</echo text:30>",
///   )
/// }
/// ```
pub fn user_mention(user_id : @model.UserId) -> String {
  "<@\{user_id}>"
}

///|
/// Format a channel mention.
pub fn channel_mention(channel_id : @model.ChannelId) -> String {
  "<#\{channel_id}>"
}

///|
/// Format a role mention.
pub fn role_mention(role_id : @model.RoleId) -> String {
  "<@&\{role_id}>"
}

///|
/// Format a slash-command mention. `name` may include subcommand path
/// segments, for example `"permissions user get"`.
pub fn slash_command_mention(
  name~ : String,
  command_id~ : @model.CommandId,
) -> String {
  "</\{name}:\{command_id}>"
}

///|
/// Format a custom emoji mention.
pub fn custom_emoji_mention(
  name~ : String,
  emoji_id~ : @model.EmojiId,
  animated? : Bool = false,
) -> String {
  if animated {
    "<a:\{name}:\{emoji_id}>"
  } else {
    "<:\{name}:\{emoji_id}>"
  }
}

///|
/// A Discord timestamp display style.
pub(all) enum TimestampStyle {
  ShortTime
  LongTime
  ShortDate
  LongDate
  ShortDateTime
  LongDateTime
  Relative
} derive(Eq, Debug)

///|
fn TimestampStyle::code(self : TimestampStyle) -> String {
  match self {
    ShortTime => "t"
    LongTime => "T"
    ShortDate => "d"
    LongDate => "D"
    ShortDateTime => "f"
    LongDateTime => "F"
    Relative => "R"
  }
}

///|
/// Format Unix seconds as a Discord timestamp.
///
/// ```mbt check
/// test "format absolute and model timestamps" {
///   inspect(@util.timestamp(0L, style=Relative), content="<t:0:R>")
///   inspect(
///     @util.timestamp_from_model(
///       Timestamp("1970-01-01T00:00:01Z"),
///       style=LongTime,
///     ),
///     content="<t:1:T>",
///   )
/// }
/// ```
pub fn timestamp(unix_seconds : Int64, style? : TimestampStyle) -> String {
  match style {
    None => "<t:\{unix_seconds}>"
    Some(style) => "<t:\{unix_seconds}:\{style.code()}>"
  }
}

///|
/// Parse and format a model timestamp as a Discord timestamp.
pub fn timestamp_from_model(
  value : @model.Timestamp,
  style? : TimestampStyle,
) -> String raise @model.TimestampError {
  timestamp(value.unix_ms() / 1000L, style?)
}
