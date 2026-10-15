"use strict";

// Generated from the assets attached to the official upstream release.
// Keep archive and extracted-library digests together: the archive digest
// authenticates what is downloaded, while the library digest authenticates a
// preseeded extraction supplied through MBT_DAVE_NATIVE_ROOT.
const release = deepFreeze({
  repository: "https://github.com/discord/libdave",
  tag: "v1.2.0/cpp",
  commit: "9686fbaea864aa19f0675e486672b6a77811b6a1",
  cacheTag: "v1.2.0-cpp",
  releaseUrl: "https://github.com/discord/libdave/releases/tag/v1.2.0%2Fcpp",
  downloadBaseUrl:
    "https://github.com/discord/libdave/releases/download/v1.2.0%2Fcpp",
  assets: {
    "linux:x64": {
      id: "linux-x64",
      archive: "libdave-Linux-X64-boringssl.zip",
      archiveSize: 3828279,
      archiveSha256:
        "cd77724d3fa90359f6430c294fcad7b8f7e248ec8e16db9031d7b6f622eb3451",
      libraryRelativePath: "lib/libdave.so",
      librarySha256:
        "aef7aeaf1580cf629c3a241919598875b654db2f41a1f0cc1e5389b4988727c8",
    },
    "linux:arm64": {
      id: "linux-arm64",
      archive: "libdave-Linux-ARM64-boringssl.zip",
      archiveSize: 3523474,
      archiveSha256:
        "2c4396825d1d777b2f37e21dbd12fc9b4a73cb90f7cecfd9d30b2ce5b24d9a9b",
      libraryRelativePath: "lib/libdave.so",
      librarySha256:
        "8dd4726c49e85647cc52ae57cc435310b6200115f9d0c447e022499ba02f39cb",
    },
    "darwin:x64": {
      id: "macos-x64",
      archive: "libdave-macOS-X64-boringssl.zip",
      archiveSize: 1233003,
      archiveSha256:
        "30c268218c8de74c72c12fc39a8b8d2de5c979a188bb65b23fef0da63a1b2655",
      libraryRelativePath: "lib/libdave.dylib",
      librarySha256:
        "a5bf0a93060172a0d063a9ee5c5d0af1252ece8782eec6d89060bbe2cb5581a8",
    },
    "darwin:arm64": {
      id: "macos-arm64",
      archive: "libdave-macOS-ARM64-boringssl.zip",
      archiveSize: 1125514,
      archiveSha256:
        "3158ddc2af8e4def0f4c5a70c21ec6756e370f5b9191485c24c5f2fc5efa9749",
      libraryRelativePath: "lib/libdave.dylib",
      librarySha256:
        "22da75908e667726853c4c605a18fdb0eaa1da48b770f4c608c336bfe1fd0199",
    },
    "win32:x64": {
      id: "windows-x64",
      archive: "libdave-Windows-X64-boringssl.zip",
      archiveSize: 979137,
      archiveSha256:
        "f4cade98328fce51ea6e17fcc3c7bd39447999a554dbf383f7f63b89f0bbd714",
      libraryRelativePath: "bin/libdave.dll",
      librarySha256:
        "1b9a73529b7dd024137fec100f9638d5213d4deae200e322668418d8e178fc79",
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
      `libdave ${release.tag} has no official asset for ${key}; supported hosts: ${supported}`,
    );
  }
  return asset;
}

module.exports = { assetFor, normalizeArch, normalizePlatform, release };
