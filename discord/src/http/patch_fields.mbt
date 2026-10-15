///|
fn[T] patch_value(value : T?) -> @sdkjson.Presence[T] {
  match value {
    None => Absent
    Some(value) => Value(value)
  }
}

///|
fn[T] patch_nullable(
  field : String,
  value : T?,
  clear : Bool,
) -> @sdkjson.Presence[T] raise DiscordHttpError {
  if value is Some(_) && clear {
    raise Validation(message="\{field} and clear_\{field} cannot both be set")
  }
  if clear {
    Null
  } else {
    patch_value(value)
  }
}

///|
fn message_patch_builder(
  content : String?,
  clear_content : Bool,
  embeds : Array[@model.Embed]?,
  components : Array[@model.Component]?,
  flags : @model.MessageFlags?,
  has_poll~ : Bool = false,
) -> @sdkjson.ObjBuilder raise DiscordHttpError {
  validate_content(content)
  let flags = message_flags_with_components_v2(
    flags,
    content,
    embeds,
    components,
    has_poll~,
  )
  @sdkjson.ObjBuilder::new()
  .presence("content", patch_nullable("content", content, clear_content))
  .presence("embeds", patch_value(embeds))
  .presence("components", patch_value(components))
  .presence("flags", patch_value(flags))
}
