# DAVE live probe

A manual check of DAVE against a real voice channel; it is not part of CI.

`examples/dave_probe` joins an existing channel, waits for
`DaveMediaContextActivated(protocol_version=1)`, sends one second of canonical
Opus silence through the active libdave encryptor, and disconnects. It does
not create or delete Discord resources. Keep a normal DAVE-capable Discord
client in the channel while testing: the gateway sends an initial Add proposal
to the other pending members, so a bot alone cannot establish the group. Set
`DISCORD_TOKEN`, `GUILD_ID`, and `CHANNEL_ID`, then run:

```sh
env DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

With no other announced participant, the probe reports an inconclusive result.
It fails if a peer is present but DAVE v1 does not activate within 30 seconds,
or if the control or encryption paths emit a DAVE diagnostic. A successful run proves
the local client completed the server-driven MLS transition and encrypted its
outbound frames. It does not prove that another participant decrypted them;
that final interoperability check requires a second Discord client in the
channel.

For that final outbound interoperability check, explicitly enable the audible
mode with a short, low-volume Ogg/Opus file. The probe still waits for DAVE v1
activation before playback and clips the input at three seconds. For example:

```sh
ffmpeg -y -hide_banner -loglevel error -f lavfi -i 'sine=frequency=880:duration=1.5' -filter:a 'volume=0.7' -c:a libopus -ar 48000 -ac 2 -frame_duration 20 /tmp/discord-dave-tone.ogg
env DAVE_PROBE_AUDIBLE=1 DAVE_PROBE_AUDIO_FILE=/tmp/discord-dave-tone.ogg DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

Have the other participant confirm hearing the short tone, and also
require the probe to report no DAVE diagnostics and a clean disconnect.
Hearing the tone confirms the
outbound bot-to-client decrypt/decode/render path; validating the reverse path
requires speaking from the client and observing decrypted frames on a
subscription separately. To perform that reverse check without recording the audio,
set `DAVE_PROBE_RECEIVE=1`, run the same probe, and speak from the other client
when the receive probe starts. It waits up to 20 seconds for ten decrypted Opus
frames and stores only the frame count:

```sh
env DAVE_PROBE_RECEIVE=1 DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

UDP can arrive before the voice gateway's initial Speaking event establishes
the SSRC-to-user mapping. The probe subscribes to the first user whose
Speaking event arrives, so earlier frames are discarded unread; it passes the
receive check once ten later frames from that user decrypt successfully. DAVE
decrypt failures remain fatal.

For a content-level manual check, `DAVE_PROBE_ECHO=1` implies receive mode,
waits for a peer Speaking event, discards five warm-up frames, holds the next
100 frames (about two seconds) from that peer in memory, then plays them back
once through the active DAVE encryptor. Speak for about three seconds and stop;
the probe does not write the audio to disk and does not echo while recording,
so it cannot create a continuous feedback loop. It logs only Opus packet-size
statistics, not the sender ID or audio content:

```sh
env DAVE_PROBE_ECHO=1 DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```

When explicit recording is acceptable, set `DAVE_PROBE_RECORD_PATH` to an Ogg
output path. This also uses the Speaking-gated two-second capture, but does not
enable echo unless `DAVE_PROBE_ECHO=1` is set separately:

```sh
env DAVE_PROBE_RECORD_PATH=/tmp/discord-dave-receive-check.ogg DISCORD_VOICE_REQUIRE_SHIM=1 MBT_DAVE_REQUIRE_NATIVE=1 moon run --target native --release examples/dave_probe
```
