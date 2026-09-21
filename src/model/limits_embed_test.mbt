///|
test "embed limits accept every documented boundary" {
  let cases = [
    (
      "embed count",
      @model.embed_limit_violations(Array::make(10, @model.Embed())),
    ),
    (
      "title",
      @model.embed_limit_violations([
        @model.Embed(title=" \{"😀".repeat(128)} "),
      ]),
    ),
    (
      "description",
      @model.embed_limit_violations([@model.Embed(description="d".repeat(4096))]),
    ),
    (
      "field count",
      @model.embed_limit_violations([
        @model.Embed(fields=Array::make(25, EmbedField("", ""))),
      ]),
    ),
    (
      "field name",
      @model.embed_limit_violations([
        @model.Embed(fields=[EmbedField("n".repeat(256), "")]),
      ]),
    ),
    (
      "field value",
      @model.embed_limit_violations([
        @model.Embed(fields=[EmbedField("", "v".repeat(1024))]),
      ]),
    ),
    (
      "footer text",
      @model.embed_limit_violations([
        @model.Embed(footer=EmbedFooter("f".repeat(2048))),
      ]),
    ),
    (
      "author name",
      @model.embed_limit_violations([
        @model.Embed(author=EmbedAuthor("a".repeat(256))),
      ]),
    ),
    (
      "combined total",
      @model.embed_limit_violations([
        @model.Embed(title="t".repeat(256), description="d".repeat(3000), fields=[
          EmbedField("n".repeat(256), "v".repeat(488)),
        ]),
        @model.Embed(
          footer=EmbedFooter("f".repeat(1800)),
          author=EmbedAuthor("a".repeat(200)),
        ),
      ]),
    ),
  ]
  debug_inspect(
    cases,
    content=(
      #|[
      #|  ("embed count", []),
      #|  ("title", []),
      #|  ("description", []),
      #|  ("field count", []),
      #|  ("field name", []),
      #|  ("field value", []),
      #|  ("footer text", []),
      #|  ("author name", []),
      #|  ("combined total", []),
      #|]
    ),
  )
}

///|
test "embed limits report every documented violation" {
  let cases = [
    (
      "embed count",
      @model.embed_limit_violations(Array::make(11, @model.Embed())),
    ),
    (
      "title",
      @model.embed_limit_violations([
        @model.Embed(title=" \{"😀".repeat(129)} "),
      ]),
    ),
    (
      "description",
      @model.embed_limit_violations([@model.Embed(description="d".repeat(4097))]),
    ),
    (
      "field count",
      @model.embed_limit_violations([
        @model.Embed(fields=Array::make(26, EmbedField("", ""))),
      ]),
    ),
    (
      "field name",
      @model.embed_limit_violations([
        @model.Embed(fields=[EmbedField("n".repeat(257), "")]),
      ]),
    ),
    (
      "field value",
      @model.embed_limit_violations([
        @model.Embed(fields=[EmbedField("", "v".repeat(1025))]),
      ]),
    ),
    (
      "footer text",
      @model.embed_limit_violations([
        @model.Embed(footer=EmbedFooter("f".repeat(2049))),
      ]),
    ),
    (
      "author name",
      @model.embed_limit_violations([
        @model.Embed(author=EmbedAuthor("a".repeat(257))),
      ]),
    ),
    (
      "combined total",
      @model.embed_limit_violations([
        @model.Embed(title="t".repeat(256), description="d".repeat(3000), fields=[
          EmbedField("n".repeat(256), "v".repeat(488)),
        ]),
        @model.Embed(
          footer=EmbedFooter("f".repeat(1800)),
          author=EmbedAuthor("a".repeat(201)),
        ),
      ]),
    ),
  ]
  debug_inspect(
    cases,
    content=(
      #|[
      #|  (
      #|    "embed count",
      #|    [{ path: "embeds", custom_id: None, reason: "11 (0 to 10)" }],
      #|  ),
      #|  (
      #|    "title",
      #|    [
      #|      {
      #|        path: "embeds[0].title",
      #|        custom_id: None,
      #|        reason: "258 units (at most 256)",
      #|      },
      #|    ],
      #|  ),
      #|  (
      #|    "description",
      #|    [
      #|      {
      #|        path: "embeds[0].description",
      #|        custom_id: None,
      #|        reason: "4097 units (at most 4096)",
      #|      },
      #|    ],
      #|  ),
      #|  (
      #|    "field count",
      #|    [{ path: "embeds[0].fields", custom_id: None, reason: "26 (0 to 25)" }],
      #|  ),
      #|  (
      #|    "field name",
      #|    [
      #|      {
      #|        path: "embeds[0].fields[0].name",
      #|        custom_id: None,
      #|        reason: "257 units (at most 256)",
      #|      },
      #|    ],
      #|  ),
      #|  (
      #|    "field value",
      #|    [
      #|      {
      #|        path: "embeds[0].fields[0].value",
      #|        custom_id: None,
      #|        reason: "1025 units (at most 1024)",
      #|      },
      #|    ],
      #|  ),
      #|  (
      #|    "footer text",
      #|    [
      #|      {
      #|        path: "embeds[0].footer.text",
      #|        custom_id: None,
      #|        reason: "2049 units (at most 2048)",
      #|      },
      #|    ],
      #|  ),
      #|  (
      #|    "author name",
      #|    [
      #|      {
      #|        path: "embeds[0].author.name",
      #|        custom_id: None,
      #|        reason: "257 units (at most 256)",
      #|      },
      #|    ],
      #|  ),
      #|  (
      #|    "combined total",
      #|    [
      #|      {
      #|        path: "embeds",
      #|        custom_id: None,
      #|        reason: "6001 units across all title, description, field.name, field.value, footer.text, and author.name values (at most 6000)",
      #|      },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "realistic embed stays within all limits" {
  let violations = @model.embed_limit_violations([
    @model.Embed(
      title="Release 0.3.1",
      description="Native and JavaScript checks passed.",
      footer=EmbedFooter("discord.mbt build 42"),
      author=EmbedAuthor("CI Bot"),
      fields=[
        EmbedField("Target", "native", inline=true),
        EmbedField("Tests", "325 passed", inline=true),
      ],
    ),
  ])
  debug_inspect(
    violations,
    content=(
      #|[]
    ),
  )
}
