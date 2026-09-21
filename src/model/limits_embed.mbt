///|
/// The limits Discord documents for the embeds of one message, including the
/// 6000-unit total across all of them.
pub fn embed_limit_violations(embeds : Array[Embed]) -> Array[LimitViolation] {
  let checker = LimitChecker::new()
  checker.count("embeds", Some(embeds.length()), min=0, max=10)
  let mut total_length = 0
  for embed_index, embed in embeds {
    let path = "embeds[\{embed_index}]"
    total_length += checker.embed_text("\{path}.title", embed.title, max=256)
    total_length += checker.embed_text(
      "\{path}.description",
      embed.description,
      max=4096,
    )
    checker.count(
      "\{path}.fields",
      embed.fields.map(fields => fields.length()),
      min=0,
      max=25,
    )
    if embed.fields is Some(fields) {
      for field_index, field in fields {
        let field_path = "\{path}.fields[\{field_index}]"
        total_length += checker.embed_text(
          "\{field_path}.name",
          Some(field.name),
          max=256,
        )
        total_length += checker.embed_text(
          "\{field_path}.value",
          Some(field.value),
          max=1024,
        )
      }
    }
    if embed.footer is Some(footer) {
      total_length += checker.embed_text(
        "\{path}.footer.text",
        Some(footer.text),
        max=2048,
      )
    }
    if embed.author is Some(author) {
      total_length += checker.embed_text(
        "\{path}.author.name",
        Some(author.name),
        max=256,
      )
    }
  }
  if total_length > 6000 {
    checker.report(
      "embeds",
      "\{total_length} units across all title, description, field.name, field.value, footer.text, and author.name values (at most 6000)",
    )
  }
  checker.violations
}

///|
/// Discord trims leading and trailing whitespace before applying embed text
/// limits, so this returns the same length used for the per-field and total checks.
fn LimitChecker::embed_text(
  self : LimitChecker,
  path : String,
  text : String?,
  max~ : Int,
) -> Int {
  guard text is Some(text) else { return 0 }
  let trimmed = text.trim().to_owned()
  self.text(path, Some(trimmed), max~)
  trimmed.length()
}
