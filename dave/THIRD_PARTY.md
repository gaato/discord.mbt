# Third-party software and binary provenance

The MoonBit wrapper source in this repository is licensed under Apache-2.0.
It is not the `libdave` implementation and is not endorsed by Discord.

Native builds use the shared-library assets from Discord's official
[`libdave` v1.3.0/cpp release](https://github.com/discord/libdave/releases/tag/v1.3.0%2Fcpp),
published on 2026-11-10 from upstream commit
`b5463c443df74db75a713c775b09a847621e6d62`. `libdave` is licensed under the
MIT License. Each
official archive also carries upstream notices for BoringSSL, mlspp, and
nlohmann-json in its `licenses/` directory. The bootstrap preserves the entire
extracted archive so those notices remain next to the redistributed binary.

## Pinned archives

| Host asset | Bytes | Archive SHA-256 | Runtime SHA-256 |
| --- | ---: | --- | --- |
| `libdave-Linux-ARM64-boringssl.zip` | 3,548,389 | `024bb556da335c884471256bcb30e4871e19b0a63aaaf9eec9898f83d8e5f81c` | `9051370e90c0f6ba9cbdb4d55c43ff2a37fe7138e552043bebde0238490e48bc` |
| `libdave-Linux-X64-boringssl.zip` | 3,943,995 | `096e2b4cb64f4c9a5551b954ff717a89db7c5fe94e901860c339dd98d6f2c15d` | `3e44c3e5126a667b3c16cd4ca382054ea277b30eff9e54cf1158dca9b7fc10e2` |
| `libdave-macOS-ARM64-boringssl.zip` | 1,140,081 | `111e46c61f2fa7ef23c7a2f7840330e59bcdb75e77728d2244536a031e601e02` | `9e7f9e28462cc907d464a116e3bccae09d6847ba85bfd7647246a2ea78e31ac0` |
| `libdave-macOS-X64-boringssl.zip` | 1,246,574 | `041140b9fe4059e777d512219f796d00c8a3e38e98eb14cd49c9c5804b64367a` | `9fb1e2936550def4992a8221835d98e41a4d3fa0bcb6b9e186726b7462ac403c` |
| `libdave-Windows-X64-boringssl.zip` | 992,823 | `82993c4a9e5836f1dca01b4f7afeba72454321034dc41fda74bc239f620be6a2` | `1764d01a717acc27e6f89d168b26674289999b36ff4690fd963e8c4acf84602e` |

The archive digest authenticates downloads. The runtime digest independently
authenticates `MBT_DAVE_NATIVE_ROOT` preseeds. The executable manifest used by
the bootstrap is `release/libdave-v1.3.0.js`, which
`scripts/libdave_release.sh` generates from the release assets; this table is
its human-readable provenance record.
