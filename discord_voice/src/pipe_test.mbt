///|
/// Write `data` into an in-memory pipe in pieces of `chunk_size` bytes from a
/// background task, and return what `read` makes of the other end. MoonBit
/// after 0.10.20 renames core/async's `@io.pipe` to `@io.memory_pipe`, so this
/// is the only function that differs between the toolchains.
async fn[T] through_pipe(
  data : Bytes,
  chunk_size~ : Int32,
  read : async (&@io.BinaryReader) -> T,
) -> T {
  let result = Ref(None)
  @async.with_task_group(group => {
    let (read_end, write_end) = @io.pipe()
    defer read_end.close()
    group.spawn_bg(() => {
      defer write_end.close()
      for offset = 0; offset < data.length(); {
        let next = offset + chunk_size
        let end = if next < data.length() { next } else { data.length() }
        write_end.write(data[offset:end])
        continue end
      }
    })
    result.val = Some(read(read_end))
  })
  result.val.unwrap()
}
