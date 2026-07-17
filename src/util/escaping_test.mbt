///|
test "escape mentions matches Pycord mention classes" {
  inspect(
    @util.escape_mentions(
      "@everyone @here <@12345678901234567> <@!123456789012345678> <@&1234567890123456789> <#123456789012345678>",
    ),
    content="@​everyone @​here <@​12345678901234567> <@​!123456789012345678> <@​&1234567890123456789> <#123456789012345678>",
  )
}

///|
test "escape mentions respects snowflake length" {
  inspect(
    @util.escape_mentions(
      "@1234567890123456 @12345678901234567 @12345678901234567890 @123456789012345678901",
    ),
    content="@1234567890123456 @​12345678901234567 @​12345678901234567890 @123456789012345678901",
  )
}

///|
test "escape markdown preserves URLs and escapes stock syntax" {
  inspect(
    @util.escape_markdown(
      "**bold** _x_ https://example.test/a_b?q=*x*\n> quote\n[text](target)",
    ),
    content="\\*\\*bold\\*\\* \\_x\\_ https://example.test/a_b?q=*x*\n\\> quote\n\\[text](target)",
  )
}

///|
test "escape markdown preserves supported URL schemes and links" {
  inspect(
    @util.escape_markdown(
      "http://example.test/_* steam://run/1/~| https://example.test/`x` [a_b](https://example.test/_x)",
    ),
    content="http://example.test/_* steam://run/1/~| https://example.test/`x` \\[a_b](https://example.test/_x)",
  )
}

///|
test "escape markdown handles line-leading quote forms" {
  inspect(
    @util.escape_markdown("> quote\n>>> block\n>> not a quote\n>no space"),
    content="\\> quote\n\\>>> block\n>> not a quote\n>no space",
  )
}
