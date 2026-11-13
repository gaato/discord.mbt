///|
/// Send what `conn` has buffered so far. core/async after MoonBit 0.10.20
/// renames `ServerConnection::flush` to `flush_partial_data`, so this is the
/// only line that differs between the toolchains; compat/core_async_next
/// holds the other version.
async fn flush_response(conn : @ahttp.ServerConnection) -> Unit {
  conn.flush()
}
