# Third-party software and binary provenance

The MoonBit wrapper source in this repository is licensed under Apache-2.0.
It is not the `libdave` implementation and is not endorsed by Discord.

Native builds use the shared-library assets from Discord's official
[`libdave` v1.2.0/cpp release](https://github.com/discord/libdave/releases/tag/v1.2.0%2Fcpp),
published on 2026-08-26 from upstream commit
`9686fbaea864aa19f0675e486672b6a77811b6a1`. `libdave` is licensed under the
MIT License. Each
official archive also carries upstream notices for BoringSSL, mlspp, and
nlohmann-json in its `licenses/` directory. The bootstrap preserves the entire
extracted archive so those notices remain next to the redistributed binary.

## Pinned archives

| Host asset | Bytes | Archive SHA-256 | Runtime SHA-256 |
| --- | ---: | --- | --- |
| `libdave-Linux-ARM64-boringssl.zip` | 3,523,474 | `2c4396825d1d777b2f37e21dbd12fc9b4a73cb90f7cecfd9d30b2ce5b24d9a9b` | `8dd4726c49e85647cc52ae57cc435310b6200115f9d0c447e022499ba02f39cb` |
| `libdave-Linux-X64-boringssl.zip` | 3,828,279 | `cd77724d3fa90359f6430c294fcad7b8f7e248ec8e16db9031d7b6f622eb3451` | `aef7aeaf1580cf629c3a241919598875b654db2f41a1f0cc1e5389b4988727c8` |
| `libdave-macOS-ARM64-boringssl.zip` | 1,125,514 | `3158ddc2af8e4def0f4c5a70c21ec6756e370f5b9191485c24c5f2fc5efa9749` | `22da75908e667726853c4c605a18fdb0eaa1da48b770f4c608c336bfe1fd0199` |
| `libdave-macOS-X64-boringssl.zip` | 1,233,003 | `30c268218c8de74c72c12fc39a8b8d2de5c979a188bb65b23fef0da63a1b2655` | `a5bf0a93060172a0d063a9ee5c5d0af1252ece8782eec6d89060bbe2cb5581a8` |
| `libdave-Windows-X64-boringssl.zip` | 979,137 | `f4cade98328fce51ea6e17fcc3c7bd39447999a554dbf383f7f63b89f0bbd714` | `1b9a73529b7dd024137fec100f9638d5213d4deae200e322668418d8e178fc79` |

The archive digest authenticates downloads. The runtime digest independently
authenticates `MBT_DAVE_NATIVE_ROOT` preseeds. The executable manifest used by
the bootstrap is `release/libdave-v1.2.0.js`; this table is its human-readable
provenance record.
