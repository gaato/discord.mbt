"use strict";

// Generated from the assets attached to the component release. The archive
// digest authenticates the download, while the extracted-library digest
// authenticates an offline/preseeded runtime root.
const release = deepFreeze({
  repository: "https://github.com/gaato/discord.mbt",
  tag: "voice-shim-v0.1.0",
  commit: "2acd02addaf6af493e07dd61f60fe0d643599958",
  cacheTag: "v0.1.0",
  releaseUrl:
    "https://github.com/gaato/discord.mbt/releases/tag/voice-shim-v0.1.0",
  downloadBaseUrl:
    "https://github.com/gaato/discord.mbt/releases/download/voice-shim-v0.1.0",
  assets: {
    "linux:x64": {
      id: "linux-x64",
      archive: "discord-voice-shim-v0.1.0-linux-x86_64.tar.gz",
      archiveFormat: "tar.gz",
      archiveSize: 224280,
      archiveSha256:
        "94ceaf0fbb5c6fc1e21b76ca239440c8619a5b889df9727af99e85bc1fb523d0",
      libraryRelativePath: "libdiscord_voice_shim.so",
      librarySize: 494712,
      librarySha256:
        "c6d7aea432182fc78ab56b34461bccf7454510e93b7a8a80de3e8c8dc18977a7",
    },
    "linux:arm64": {
      id: "linux-arm64",
      archive: "discord-voice-shim-v0.1.0-linux-aarch64.tar.gz",
      archiveFormat: "tar.gz",
      archiveSize: 207282,
      archiveSha256:
        "ec8085454769007671e6219a3ee7e94281710e8da4cbef1b4a7f1d61d0a654f5",
      libraryRelativePath: "libdiscord_voice_shim.so",
      librarySize: 460824,
      librarySha256:
        "21d07c492eb89461152e313a9f47d0cc1b96a16059b464c29e093b1fa04ad98d",
    },
    "darwin:x64": {
      id: "macos-x64",
      archive: "discord-voice-shim-v0.1.0-macos-x86_64.tar.gz",
      archiveFormat: "tar.gz",
      archiveSize: 202411,
      archiveSha256:
        "d59737afc3eed391b071a7d7b4463cd37878ec9deb0d3505a37900e2d1e8c6c6",
      libraryRelativePath: "libdiscord_voice_shim.dylib",
      librarySize: 444728,
      librarySha256:
        "fd8c31e116ceb5f6adb5b2dbe58341a17377a2f63f56055c56ee8fdcb49d6e0b",
    },
    "darwin:arm64": {
      id: "macos-arm64",
      archive: "discord-voice-shim-v0.1.0-macos-aarch64.tar.gz",
      archiveFormat: "tar.gz",
      archiveSize: 186197,
      archiveSha256:
        "4a8e111b2183cefdcbe614f42770a621184efff3d9a41939cb5c4cfacd94a7dc",
      libraryRelativePath: "libdiscord_voice_shim.dylib",
      librarySize: 425792,
      librarySha256:
        "14b9b3dbbc343d0cf532c4d0f6a61ce47322344a0ef29a70f8e5829e75d96e5c",
    },
    "win32:x64": {
      id: "windows-x64",
      archive: "discord-voice-shim-v0.1.0-windows-x86_64.zip",
      archiveFormat: "zip",
      archiveSize: 216134,
      archiveSha256:
        "dec3cc07ec049be96b4b3b58f6e70995256f94a2ef3cca65f5f81ddd1e9d36b9",
      libraryRelativePath: "discord_voice_shim.dll",
      librarySize: 178688,
      librarySha256:
        "a5f40082d4dc3e2487a3291ba55f4be758e5814751928443b6539ea297062816",
    },
  },
});

function deepFreeze(value) {
  if (value && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const child of Object.values(value)) {
      deepFreeze(child);
    }
  }
  return value;
}

function normalizePlatform(platform) {
  switch (String(platform).toLowerCase()) {
    case "linux":
      return "linux";
    case "darwin":
    case "macos":
      return "darwin";
    case "win32":
    case "windows":
      return "win32";
    default:
      return String(platform).toLowerCase();
  }
}

function normalizeArch(arch) {
  switch (String(arch).toLowerCase()) {
    case "x64":
    case "x86_64":
    case "amd64":
      return "x64";
    case "arm64":
    case "aarch64":
      return "arm64";
    default:
      return String(arch).toLowerCase();
  }
}

function assetFor(platform, arch) {
  const key = `${normalizePlatform(platform)}:${normalizeArch(arch)}`;
  const asset = release.assets[key];
  if (!asset) {
    const supported = Object.keys(release.assets).sort().join(", ");
    throw new Error(
      `${release.tag} has no component asset for ${key}; supported hosts: ${supported}`,
    );
  }
  return asset;
}

module.exports = { assetFor, normalizeArch, normalizePlatform, release };
