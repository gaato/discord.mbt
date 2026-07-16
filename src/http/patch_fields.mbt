///|
fn[T] patch_value(value : T?) -> @model.Undefinable[T] {
  match value {
    None => Missing
    Some(value) => Value(value)
  }
}

///|
fn[T] patch_nullable(
  field : String,
  value : T?,
  clear : Bool,
) -> @model.Undefinable[T] raise DiscordHttpError {
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
) -> @model.ObjBuilder raise DiscordHttpError {
  validate_content(content)
  let flags = message_flags_with_components_v2(
    flags, content, embeds, components,
  )
  @model.ObjBuilder()
  .und("content", patch_nullable("content", content, clear_content))
  .und("embeds", patch_value(embeds))
  .und("components", patch_value(components))
  .und("flags", patch_value(flags))
}
