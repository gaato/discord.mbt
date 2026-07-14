///|
fn[T] patch_value(value : T?) -> @model.Undefinable[T] {
  match value {
    None => @model.Undefinable::Missing
    Some(value) => @model.Undefinable::Value(value)
  }
}

///|
fn[T] patch_nullable(
  field : String,
  value : T?,
  clear : Bool,
) -> @model.Undefinable[T] raise DiscordHttpError {
  if value is Some(_) && clear {
    raise DiscordHttpError::Validation(
      message="\{field} and clear_\{field} cannot both be set",
    )
  }
  if clear {
    @model.Undefinable::Null
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
  if content is Some(value) && value.length() > 4000 {
    raise DiscordHttpError::Validation(
      message="content exceeds 4000 UTF-16 units",
    )
  }
  @model.ObjBuilder::new()
  .und("content", patch_nullable("content", content, clear_content))
  .und("embeds", patch_value(embeds))
  .und("components", patch_value(components))
  .und("flags", patch_value(flags))
}
