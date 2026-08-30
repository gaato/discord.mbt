"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  cacheRootFor,
  ensureLibrary,
  httpsDownloadUrl,
  validateContentLength,
} = require("../build.js");
const {
  assetFor,
  normalizeArch,
  normalizePlatform,
  release,
} = require("../release/voice-shim-v0.1.0.js");

test("release manifest covers every published host", () => {
  assert.deepEqual(Object.keys(release.assets).sort(), [
    "darwin:arm64",
    "darwin:x64",
    "linux:arm64",
    "linux:x64",
    "win32:x64",
  ]);
  for (const asset of Object.values(release.assets)) {
    assert.match(asset.archiveSha256, /^[0-9a-f]{64}$/u);
    assert.match(asset.librarySha256, /^[0-9a-f]{64}$/u);
    assert.ok(Number.isSafeInteger(asset.archiveSize));
    assert.ok(asset.archiveSize > 0);
    assert.ok(Number.isSafeInteger(asset.librarySize));
    assert.ok(asset.librarySize > 0);
  }
  assert.ok(Object.isFrozen(release));
  assert.ok(Object.isFrozen(release.assets["linux:x64"]));
});

test("platform and architecture aliases select the same asset", () => {
  assert.equal(normalizePlatform("macOS"), "darwin");
  assert.equal(normalizePlatform("windows"), "win32");
  assert.equal(normalizeArch("amd64"), "x64");
  assert.equal(normalizeArch("aarch64"), "arm64");
  assert.equal(assetFor("linux", "amd64").id, "linux-x64");
  assert.throws(() => assetFor("freebsd", "x64"), /supported hosts/u);
});

test("download URL must use HTTPS", () => {
  assert.equal(
    httpsDownloadUrl("https://example.com/file").protocol,
    "https:",
  );
  assert.throws(
    () => httpsDownloadUrl("http://example.com/file"),
    /unsupported download protocol/u,
  );
});

test("Content-Length must exactly match the pinned archive size", () => {
  assert.doesNotThrow(() => validateContentLength(undefined, 12, "test"));
  assert.doesNotThrow(() => validateContentLength("12", 12, "test"));
  assert.throws(
    () => validateContentLength("13", 12, "test"),
    /exceeds pinned size/u,
  );
  assert.throws(
    () => validateContentLength("11", 12, "test"),
    /Content-Length mismatch/u,
  );
  assert.throws(
    () => validateContentLength("12, 11", 12, "test"),
    /inconsistent Content-Length/u,
  );
  assert.throws(
    () => validateContentLength("invalid", 12, "test"),
    /invalid Content-Length/u,
  );
});

test("cache override must be absolute and is versioned by asset", () => {
  const root = path.resolve(os.tmpdir(), "discord-prebuild-cache");
  assert.equal(
    cacheRootFor(
      { DISCORD_VOICE_SHIM_CACHE_DIR: root },
      { id: "linux-x64" },
    ),
    path.join(root, "gaato-discord", "voice-shim", "v0.1.0", "linux-x64"),
  );
  assert.throws(
    () =>
      cacheRootFor(
        { DISCORD_VOICE_SHIM_CACHE_DIR: "relative" },
        { id: "linux-x64" },
      ),
    /must be an absolute path/u,
  );
});

test("preseeded roots require the pinned library size and digest", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "discord-prebuild-test-"));
  const contents = Buffer.from("verified transport shim fixture", "utf8");
  const libraryRelativePath = "libdiscord_voice_shim.so";
  const libraryPath = path.join(root, libraryRelativePath);
  fs.writeFileSync(libraryPath, contents);
  const asset = {
    id: "fixture",
    libraryRelativePath,
    librarySize: contents.length,
    librarySha256: crypto.createHash("sha256").update(contents).digest("hex"),
  };
  try {
    assert.equal(
      await ensureLibrary({ DISCORD_VOICE_SHIM_ROOT: root }, asset),
      libraryPath,
    );
    fs.appendFileSync(libraryPath, "corrupt");
    await assert.rejects(
      ensureLibrary({ DISCORD_VOICE_SHIM_ROOT: root }, asset),
      /library size mismatch/u,
    );
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("offline mode fails before attempting a download", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "discord-prebuild-test-"));
  const asset = {
    id: "fixture",
    libraryRelativePath: "missing.so",
    librarySize: 1,
    librarySha256: "0".repeat(64),
  };
  try {
    await assert.rejects(
      ensureLibrary(
        {
          DISCORD_VOICE_SHIM_CACHE_DIR: root,
          DISCORD_VOICE_SHIM_OFFLINE: "1",
        },
        asset,
      ),
      /OFFLINE is enabled/u,
    );
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
