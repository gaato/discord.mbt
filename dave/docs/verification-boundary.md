# Verification boundary

Why `gaato/dave` exposes only current-group verification codes, and what an
application may and may not conclude from them.

The official prebuilt `libdave` C ABI that this module downloads (the release
is recorded in
[THIRD_PARTY.md](https://github.com/gaato/discord.mbt/blob/main/dave/THIRD_PARTY.md))
is built with `PERSISTENT_KEYS` disabled. Each `Session` therefore has a
different transient signing identity, even for the same Discord user, and
`Session::reinitialize` rotates that identity again. Concurrent sessions must
not be treated as sharing a persistent DAVE identity.

`Session::current_group_pairwise_fingerprint_blocking` compares signing keys in
the currently established MLS group only. It can produce the current group's
DAVE verification code, but it does not provide identity continuity, a durable
verified-contact state, or persistent verification across reconnects,
reinitialization, or a replacement `Session`. Applications must discard any
stored fingerprint, display code, or trust decision when that boundary changes.
The fingerprint-format version is fixed to the canonical protocol value zero;
callers cannot substitute another version. The method waits for libdave's
asynchronous fingerprint worker and must not be called on an event-loop thread.
