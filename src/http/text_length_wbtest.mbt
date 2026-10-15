///|
/// Discord counts code points: these are the boundaries the live API accepted
/// and rejected on 2026-10-15.
test "length validation counts code points like Discord" {
  validate_length("role name", Some("😀".repeat(100)), min=1, max=100)
  validate_length("audit_reason", Some("😀".repeat(512)), min=1, max=512)
  validate_content(Some("😀".repeat(2000)))
  for (max, text) in [(100, "😀".repeat(101)), (2000, "😀".repeat(2001))] {
    try validate_length("field", Some(text), max~) catch {
      Validation(message~) =>
        inspect(message, content="field exceeds \{max} characters")
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected \{text.char_length()} characters to exceed \{max}")
    }
  }
}
