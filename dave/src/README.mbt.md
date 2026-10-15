# Checked API examples

The documentation examples below are compile-checked without requiring a live
Discord session.

```mbt check
///|
fn make_key_package_for_docs() -> Bytes raise @dave.DaveError {
  let session = @dave.Session::new(
    protocol_version=1,
    group_id=42UL,
    self_user_id=100UL,
  )
  session.key_package()
}

///|
fn current_group_verification_code_for_docs(
  session : @dave.Session,
  peer_user_id : UInt64,
) -> String raise @dave.DaveError {
  let fingerprint = session.current_group_pairwise_fingerprint_blocking(
    user_id=peer_user_id,
  )
  @dave.pairwise_verification_code(fingerprint)
}

///|
test "documented native flows typecheck" {
  let _ = make_key_package_for_docs
  let _ = current_group_verification_code_for_docs
}
```
