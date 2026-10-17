///|
test "Ogg packet reader keeps only the unparsed tail of a long stream" {
  let writer = OggOpusWriter::new(max_packets_per_page=3)
  for index in 0..<3000 {
    writer.write_frame(Bytes::makei(100 + index % 50, i => (i % 251).to_byte()))
  }
  writer.finish()
  let stream = writer.take_output()
  let reader = OggPacketReader::new()
  let mut packets = 0
  let mut largest = 0
  // Chunks that never line up with page boundaries.
  let mut at = 0
  while at < stream.length() {
    let end = if at + 997 < stream.length() {
      at + 997
    } else {
      stream.length()
    }
    reader.push(stream[at:end].to_owned())
    at = end
    while reader.next_packet() is Some(_) {
      packets += 1
    }
    if reader.buffer.length() > largest {
      largest = reader.buffer.length()
    }
  }
  // OpusHead and OpusTags, then the audio.
  assert_eq(packets, 3002)
  assert_true(largest < 4096, msg="buffer grew to \{largest} bytes")
}
