///|
fn roster_record(user_id : UInt64, signature_key : Bytes) -> Bytes {
  Bytes::from_array([
    (user_id >> 56).to_byte(),
    (user_id >> 48).to_byte(),
    (user_id >> 40).to_byte(),
    (user_id >> 32).to_byte(),
    (user_id >> 24).to_byte(),
    (user_id >> 16).to_byte(),
    (user_id >> 8).to_byte(),
    user_id.to_byte(),
  ]) +
  signature_key
}

///|
test "commit result decoding preserves upserts and removals" {
  let raw : FixedArray[Bytes] = [
    b"\x00",
    roster_record(42UL, b"signature"),
    roster_record(99UL, b""),
    roster_record(18446744073709551615UL, b"high-id"),
  ]
  assert_eq(
    decode_commit_result(raw, MlsFailure::{ source: "x", reason: "y", }),
    Applied(changes=[
      Upsert(user_id=42UL, signature_key=b"signature"),
      Remove(user_id=99UL),
      Upsert(user_id=18446744073709551615UL, signature_key=b"high-id"),
    ]),
  )
}

///|
test "commit result decoding preserves ignored and failed outcomes" {
  assert_eq(
    decode_commit_result([b"\x01"], MlsFailure::{
      source: "unused",
      reason: "unused",
    }),
    CommitResult::Ignored,
  )
  let failure = MlsFailure::{ source: "ProcessCommit", reason: "invalid", }
  assert_eq(
    decode_commit_result([b"\x02"], failure),
    CommitResult::Failed(failure~),
  )
}

///|
test "Welcome result decoding preserves roster changes" {
  let failure = MlsFailure::{ source: "unused", reason: "unused", }
  assert_eq(
    decode_welcome_result(
      [b"\x00", roster_record(7UL, b"sig"), roster_record(8UL, b"")],
      failure,
    ),
    WelcomeResult::Applied(changes=[
      RosterChange::Upsert(user_id=7UL, signature_key=b"sig"),
      RosterChange::Remove(user_id=8UL),
    ]),
  )
}

///|
test "native result decoder rejects unknown tags" {
  try
    decode_commit_result([b"\xff"], MlsFailure::{
      source: "unused",
      reason: "unused",
    })
  catch {
    DaveError::NativeFailure(..) => ()
    _ => fail("unexpected result decode error")
  } noraise {
    _ => fail("expected an unknown result tag to fail")
  }
}

///|
test "native result decoder rejects malformed records and tags" {
  let failure = MlsFailure::{ source: "unused", reason: "unused", }
  try decode_commit_result([], failure) catch {
    DaveError::NativeFailure(..) => ()
    _ => fail("unexpected empty-result decode error")
  } noraise {
    _ => fail("expected an empty native result to fail")
  }
  try decode_commit_result([b"\x00", b"short"], failure) catch {
    DaveError::NativeFailure(..) => ()
    _ => fail("unexpected short-record decode error")
  } noraise {
    _ => fail("expected a short roster record to fail")
  }
  try decode_commit_result([b"\x00\x01"], failure) catch {
    DaveError::NativeFailure(..) => ()
    _ => fail("unexpected malformed-tag decode error")
  } noraise {
    _ => fail("expected a malformed result tag to fail")
  }
  try decode_welcome_result([b"\x01"], failure) catch {
    DaveError::NativeFailure(..) => ()
    _ => fail("unexpected ignored-Welcome decode error")
  } noraise {
    _ => fail("expected an ignored Welcome tag to fail")
  }
  try
    decode_commit_result([b"\x01", roster_record(7UL, b"sig")], failure)
  catch {
    DaveError::NativeFailure(..) => ()
    _ => fail("unexpected ignored-result roster error")
  } noraise {
    _ => fail("expected an ignored result with roster data to fail")
  }
  try
    decode_commit_result([b"\x02", roster_record(7UL, b"sig")], failure)
  catch {
    DaveError::NativeFailure(..) => ()
    _ => fail("unexpected failed-result roster error")
  } noraise {
    _ => fail("expected a failed result with roster data to fail")
  }
}

///|
test "recognized user IDs are deduplicated and always include self" {
  let remote = [10UL, 20UL, 20UL]
  assert_eq(recognized_user_ids_with_self(remote, 30UL), [10UL, 20UL, 30UL])
  assert_eq(remote, [10UL, 20UL, 20UL])
  assert_eq(recognized_user_ids_with_self(remote, 20UL), [10UL, 20UL])
}
