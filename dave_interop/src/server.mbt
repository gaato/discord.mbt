// The voice gateway's side of DAVE's MLS exchange, written from RFC 9420
// (MLS) and the DAVE protocol whitepaper: the external sender whose signed
// proposals add and remove group members. A real group needs these
// proposals, and only the holder of the external sender's P-256 key can sign
// them, so the tests here play that holder with a fixed key.

///|
/// Signs DAVE proposals as the voice gateway's MLS external sender.
pub struct VoiceServer {
  priv key : @ecdsa.PrivateKey
  priv group_id : UInt64
}

///|
/// One signed proposal as an MLSMessage, and the reference libdave files it
/// under, which a revoke names.
pub struct SignedProposal {
  message : Bytes
  reference : Bytes
}

///|
/// A server for the group whose ID libdave derives from `group_id`, the
/// voice channel ID in Discord.
pub fn VoiceServer::new(group_id~ : UInt64) -> VoiceServer raise {
  // Any scalar below the P-256 group order is a private key.
  let scalar = Bytes::makei(32, index => (index + 1).to_byte())
  { key: @ecdsa.PrivateKey::new(scalar), group_id, }
}

///|
fn write_varint(buffer : Buffer, value : Int32) -> Unit {
  // RFC 9420 §2.1.2: the QUIC variable-length integer.
  if value < 0x40 {
    buffer.write_byte(value.to_byte())
  } else if value < 0x4000 {
    buffer.write_uint16_be((0x4000 | value).to_uint16())
  } else {
    buffer.write_uint_be(0x80000000U | value.reinterpret_as_uint())
  }
}

///|
fn write_opaque(buffer : Buffer, value : BytesView) -> Unit {
  write_varint(buffer, value.length())
  buffer.write_bytes(value)
}

///|
/// The serialized ExternalSender that the voice gateway sends in opcode 25:
/// the signature key and a basic credential.
pub fn VoiceServer::external_sender(self : VoiceServer) -> Bytes {
  let buffer = Buffer()
  write_opaque(buffer, self.key.public().bytes())
  buffer.write_uint16_be(1) // CredentialType basic
  write_opaque(buffer, b"\x00\x00\x00\x00\x00\x00\x00\x00")
  buffer.to_bytes()
}

///|
fn VoiceServer::sign(
  self : VoiceServer,
  epoch : UInt64,
  proposal : Bytes,
) -> SignedProposal {
  let group_id = Buffer()
  group_id.write_uint64_be(self.group_id)
  // FramedContent from an external sender, carrying one proposal.
  let content = Buffer()
  write_opaque(content, group_id.to_bytes())
  content.write_uint64_be(epoch)
  content.write_byte(2) // SenderType external
  content.write_uint_be(0) // the first external sender
  write_opaque(content, b"") // authenticated_data
  content.write_byte(2) // ContentType proposal
  content.write_bytes(proposal)
  let content = content.to_bytes()
  // FramedContentTBS has no GroupContext for an external sender (RFC 9420
  // §6.1), and SignWithLabel signs a labelled SignContent (§5.1.2).
  let tbs = Buffer()
  tbs.write_uint16_be(1) // mls10
  tbs.write_uint16_be(1) // mls_public_message
  tbs.write_bytes(content)
  let sign_content = Buffer()
  write_opaque(sign_content, b"MLS 1.0 FramedContentTBS")
  write_opaque(sign_content, tbs.to_bytes())
  let rs = self.key.sign(sign_content.to_bytes())
  // MLS carries an ECDSA signature DER-encoded.
  let signature = @asn1.sequence([
    @asn1.integer(rs[0:32].to_owned()),
    @asn1.integer(rs[32:64].to_owned()),
  ])
  let message = Buffer()
  message.write_uint16_be(1) // mls10
  message.write_uint16_be(1) // mls_public_message
  message.write_bytes(content)
  write_opaque(message, signature)
  // ProposalRef = RefHash("MLS 1.0 Proposal Reference", AuthenticatedContent).
  let authenticated = Buffer()
  authenticated.write_uint16_be(1) // mls_public_message
  authenticated.write_bytes(content)
  write_opaque(authenticated, signature)
  let ref_input = Buffer()
  write_opaque(ref_input, b"MLS 1.0 Proposal Reference")
  write_opaque(ref_input, authenticated.to_bytes())
  { message: message.to_bytes(), reference: @sha2.hash(ref_input.to_bytes()), }
}

///|
/// An Add proposal for the member that published `key_package` (opcode 26).
pub fn VoiceServer::add(
  self : VoiceServer,
  epoch~ : UInt64,
  key_package : Bytes,
) -> SignedProposal {
  let proposal = Buffer()
  proposal.write_uint16_be(1) // ProposalType add
  proposal.write_bytes(key_package)
  self.sign(epoch, proposal.to_bytes())
}

///|
/// A Remove proposal for the member at `leaf_index`.
pub fn VoiceServer::remove(
  self : VoiceServer,
  epoch~ : UInt64,
  leaf_index~ : UInt32,
) -> SignedProposal {
  let proposal = Buffer()
  proposal.write_uint16_be(3) // ProposalType remove
  proposal.write_uint_be(leaf_index)
  self.sign(epoch, proposal.to_bytes())
}

///|
/// An opcode 27 payload that appends `proposals` to the queue.
pub fn append(proposals : ArrayView[SignedProposal]) -> Bytes {
  let messages = Buffer()
  for proposal in proposals {
    messages.write_bytes(proposal.message)
  }
  let payload = Buffer()
  payload.write_byte(0) // append
  write_opaque(payload, messages.to_bytes())
  payload.to_bytes()
}

///|
/// An opcode 27 payload that withdraws `proposals` from the queue.
pub fn revoke(proposals : ArrayView[SignedProposal]) -> Bytes {
  let refs = Buffer()
  for proposal in proposals {
    write_opaque(refs, proposal.reference)
  }
  let payload = Buffer()
  payload.write_byte(1) // revoke
  write_opaque(payload, refs.to_bytes())
  payload.to_bytes()
}

///|
priv struct Reader {
  bytes : Bytes
  mut position : Int32
}

///|
fn Reader::take(self : Reader, length : Int32) -> BytesView raise {
  guard length >= 0 && self.position + length <= self.bytes.length() else {
    fail("commit is truncated")
  }
  let view = self.bytes[self.position:self.position + length]
  self.position += length
  view
}

///|
fn Reader::byte(self : Reader) -> Byte raise {
  self.take(1)[0]
}

///|
fn Reader::vector(self : Reader) -> BytesView raise {
  let first = self.byte().to_int()
  let length = match first >> 6 {
    0 => first
    1 => ((first & 0x3f) << 8) | self.byte().to_int()
    2 => {
      let rest = self.take(3)
      ((first & 0x3f) << 24) |
      (rest[0].to_int() << 16) |
      (rest[1].to_int() << 8) |
      rest[2].to_int()
    }
    _ => fail("invalid variable-length integer")
  }
  self.take(length)
}

///|
/// Split what `Session::process_proposals` returns for an Add into the commit
/// (an MLSMessage, which the gateway relays in opcode 29) and the Welcome
/// (opcode 30). Only a commit without an UpdatePath can be split here, which
/// is what libdave produces when every proposal is an Add.
pub fn split_commit(output : Bytes) -> (Bytes, Bytes) raise {
  let reader = Reader::{ bytes: output, position: 0, }
  ignore(reader.take(4)) // version, wire_format
  ignore(reader.vector()) // group_id
  ignore(reader.take(8)) // epoch
  guard reader.byte() == 1 else { fail("commit sender is not a member") }
  ignore(reader.take(4)) // leaf index
  ignore(reader.vector()) // authenticated_data
  guard reader.byte() == 3 else { fail("message is not a commit") }
  ignore(reader.vector()) // proposals
  guard reader.byte() == 0 else { fail("commit carries an UpdatePath") }
  ignore(reader.vector()) // signature
  ignore(reader.vector()) // confirmation_tag
  ignore(reader.vector()) // membership_tag
  let commit = output[0:reader.position].to_owned()
  let welcome = output[reader.position:].to_owned()
  guard welcome.length() > 0 else { fail("commit has no Welcome") }
  (commit, welcome)
}
