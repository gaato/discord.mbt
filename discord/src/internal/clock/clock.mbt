///|
/// Current wall-clock time in milliseconds since the Unix epoch, as a signed
/// integer so deadline arithmetic such as `deadline - now_ms()` can go
/// negative without wrapping.
pub fn now_ms() -> Int64 {
  @env.now().reinterpret_as_int64()
}
