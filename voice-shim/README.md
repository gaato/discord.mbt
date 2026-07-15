# discord.mbt voice shim

This crate builds the native cryptographic shim used by `gaato/discord/voice`.
Milestone 2 provides transport AEAD only; DAVE exports are added in Milestone 3.

Build it with:

```sh
cargo build --release
```

The output is one of:

- Linux: `target/release/libdiscord_voice_shim.so`
- macOS: `target/release/libdiscord_voice_shim.dylib`
- Windows: `target/release/discord_voice_shim.dll`

Set `DISCORD_VOICE_SHIM_PATH` to the absolute path of that file when running
discord.mbt tests or applications. When the variable is set, the loader tries
only that path. Without it, the loader searches the platform library path for
`libdiscord_voice_shim.so`, `libdiscord_voice_shim.dylib`, then
`discord_voice_shim.dll`.
