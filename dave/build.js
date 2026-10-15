"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const https = require("node:https");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { Transform, pipeline } = require("node:stream");
const { promisify } = require("node:util");

const { assetFor, release } = require("./release/libdave-v1.2.0.js");

const pipelineAsync = promisify(pipeline);
const MARKER_FILE = ".dave-mbt-runtime.json";
const MAX_REDIRECTS = 8;
const REQUEST_TIMEOUT_MS = 30_000;

async function main() {
  const input = await readPrebuildInput();
  const environment = mergeEnvironment(input.env);
  const invokedByMoon = Object.prototype.hasOwnProperty.call(input, "paths");
  if (
    invokedByMoon &&
    !environmentFlag(environment.MBT_DAVE_REQUIRE_NATIVE)
  ) {
    // Moon does not include the selected backend in prebuild input. Requiring
    // an explicit native opt-in keeps JS and non-voice dependency graphs from
    // downloading a host library they cannot use. Direct invocation remains
    // an explicit bootstrap command.
    process.stdout.write("{}");
    return;
  }
  const asset = assetFor(process.platform, process.arch);
  await ensureLibrary(environment, asset);

  // stdout is a protocol channel. Diagnostics and progress must use stderr.
  process.stdout.write("{}");
}

async function readPrebuildInput() {
  let source = "";
  process.stdin.setEncoding("utf8");
  for await (const chunk of process.stdin) {
    source += chunk;
  }
  if (source.trim() === "") {
    return {};
  }
  const parsed = JSON.parse(source);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Moon prebuild input must be a JSON object");
  }
  return parsed;
}

function mergeEnvironment(prebuildEnvironment) {
  const merged = { ...process.env };
  if (
    prebuildEnvironment !== undefined &&
    (prebuildEnvironment === null ||
      typeof prebuildEnvironment !== "object" ||
      Array.isArray(prebuildEnvironment))
  ) {
    throw new Error("Moon prebuild input field 'env' must be a JSON object");
  }
  for (const [name, value] of Object.entries(prebuildEnvironment || {})) {
    if (value !== undefined && value !== null) {
      merged[name] = String(value);
    }
  }
  return merged;
}

async function ensureLibrary(environment, asset) {
  // MBT_DAVE_NATIVE_LIB belongs to the runtime loader. It intentionally does
  // not bypass the pinned build-time artifact.
  const preseedRoot = absoluteEnvironmentPath(
    environment,
    "MBT_DAVE_NATIVE_ROOT",
  );
  if (preseedRoot) {
    const libraryPath = path.join(preseedRoot, asset.libraryRelativePath);
    verifyLibrary(libraryPath, asset, "MBT_DAVE_NATIVE_ROOT");
    return;
  }

  const cacheRoot = cacheRootFor(environment, asset);
  const cachedLibrary = path.join(cacheRoot, asset.libraryRelativePath);
  if (hasExpectedLibrary(cachedLibrary, asset)) {
    return;
  }

  if (environmentFlag(environment.MBT_DAVE_NATIVE_OFFLINE)) {
    throw new Error(
      `libdave ${release.tag} is not present in ${cacheRoot}, and MBT_DAVE_NATIVE_OFFLINE is enabled; preseed an official extraction with MBT_DAVE_NATIVE_ROOT`,
    );
  }

  await populateCache(cacheRoot, asset);
  verifyLibrary(cachedLibrary, asset, "downloaded cache");
}

function cacheRootFor(environment, asset) {
  const override = absoluteEnvironmentPath(
    environment,
    "MBT_DAVE_NATIVE_CACHE_DIR",
  );
  const base = override || defaultCacheBase(environment);
  return path.join(base, "gaato-dave", "libdave", release.cacheTag, asset.id);
}

function defaultCacheBase(environment) {
  if (process.platform === "win32") {
    const localAppData = environment.LOCALAPPDATA;
    if (localAppData && path.isAbsolute(localAppData)) {
      return path.resolve(localAppData);
    }
    return path.join(os.homedir(), "AppData", "Local");
  }
  if (process.platform === "darwin") {
    return path.join(os.homedir(), "Library", "Caches");
  }
  const xdgCache = environment.XDG_CACHE_HOME;
  if (xdgCache && path.isAbsolute(xdgCache)) {
    return path.resolve(xdgCache);
  }
  return path.join(os.homedir(), ".cache");
}

function absoluteEnvironmentPath(environment, name) {
  const value = environment[name];
  if (value === undefined || String(value).trim() === "") {
    return null;
  }
  if (!path.isAbsolute(value)) {
    throw new Error(
      `${name} must be an absolute path, got ${JSON.stringify(value)}`,
    );
  }
  return path.resolve(value);
}

function environmentFlag(value) {
  return /^(1|true|yes|on)$/iu.test(String(value || "").trim());
}

function hasExpectedLibrary(libraryPath, asset) {
  try {
    return (
      fs.statSync(libraryPath).isFile() &&
      sha256File(libraryPath) === asset.librarySha256
    );
  } catch (error) {
    if (error && (error.code === "ENOENT" || error.code === "ENOTDIR")) {
      return false;
    }
    throw error;
  }
}

function verifyLibrary(libraryPath, asset, source) {
  let stats;
  try {
    stats = fs.statSync(libraryPath);
  } catch (error) {
    if (error && (error.code === "ENOENT" || error.code === "ENOTDIR")) {
      throw new Error(
        `${source} does not contain ${asset.libraryRelativePath} for ${asset.id}`,
      );
    }
    throw error;
  }
  if (!stats.isFile()) {
    throw new Error(`${source} library is not a regular file: ${libraryPath}`);
  }
  const actual = sha256File(libraryPath);
  if (actual !== asset.librarySha256) {
    throw new Error(
      `${source} libdave SHA-256 mismatch for ${libraryPath}: expected ${asset.librarySha256}, got ${actual}`,
    );
  }
}

async function populateCache(cacheRoot, asset) {
  const cacheParent = path.dirname(cacheRoot);
  fs.mkdirSync(cacheParent, { recursive: true });

  const stagingRoot = fs.mkdtempSync(
    path.join(cacheParent, `.${asset.id}-extract-`),
  );
  const archivePath = path.join(
    cacheParent,
    `.${asset.id}-${process.pid}-${crypto.randomBytes(6).toString("hex")}.zip`,
  );

  try {
    const downloadUrl = `${release.downloadBaseUrl}/${encodeURIComponent(asset.archive)}`;
    await download(downloadUrl, archivePath, asset.archiveSize);
    verifyArchive(archivePath, asset);
    extractZip(archivePath, stagingRoot);
    const stagedLibrary = path.join(stagingRoot, asset.libraryRelativePath);
    verifyLibrary(stagedLibrary, asset, "downloaded archive");
    writeMarker(stagingRoot, asset);
    installStagingTree(stagingRoot, cacheRoot, asset);
  } finally {
    removeIfPresent(archivePath);
    removeIfPresent(stagingRoot);
  }
}

function verifyArchive(archivePath, asset) {
  const size = fs.statSync(archivePath).size;
  if (size !== asset.archiveSize) {
    throw new Error(
      `archive size mismatch for ${asset.archive}: expected ${asset.archiveSize}, got ${size}`,
    );
  }
  const actual = sha256File(archivePath);
  if (actual !== asset.archiveSha256) {
    throw new Error(
      `archive SHA-256 mismatch for ${asset.archive}: expected ${asset.archiveSha256}, got ${actual}`,
    );
  }
}

function sha256File(filePath) {
  const digest = crypto.createHash("sha256");
  const descriptor = fs.openSync(filePath, "r");
  const buffer = Buffer.allocUnsafe(1024 * 1024);
  try {
    for (;;) {
      const length = fs.readSync(descriptor, buffer, 0, buffer.length, null);
      if (length === 0) {
        break;
      }
      digest.update(buffer.subarray(0, length));
    }
  } finally {
    fs.closeSync(descriptor);
  }
  return digest.digest("hex");
}

async function download(url, destination, expectedSize, redirectCount = 0) {
  assertPinnedArchiveSize(expectedSize);
  if (redirectCount > MAX_REDIRECTS) {
    throw new Error(`too many redirects while downloading ${url}`);
  }
  const parsed = httpsDownloadUrl(url);
  const response = await request(parsed);
  if (
    response.statusCode >= 300 &&
    response.statusCode < 400 &&
    response.headers.location
  ) {
    let redirected;
    try {
      redirected = new URL(response.headers.location, parsed);
    } catch (error) {
      response.destroy();
      throw error;
    }
    response.destroy();
    return download(
      redirected.toString(),
      destination,
      expectedSize,
      redirectCount + 1,
    );
  }
  if (response.statusCode !== 200) {
    const status = `${response.statusCode || "unknown"} ${response.statusMessage || ""}`.trim();
    response.destroy();
    throw new Error(`download failed for ${url}: HTTP ${status}`);
  }

  try {
    validateContentLength(
      response.headers["content-length"],
      expectedSize,
      url,
    );
  } catch (error) {
    response.destroy();
    throw error;
  }

  await pipelineAsync(
    response,
    new ExactSizeTransform(expectedSize, url),
    fs.createWriteStream(destination, { flags: "wx" }),
  );
}

function httpsDownloadUrl(url) {
  const parsed = new URL(url);
  if (parsed.protocol !== "https:") {
    throw new Error(`unsupported download protocol: ${parsed.protocol}`);
  }
  return parsed;
}

function assertPinnedArchiveSize(expectedSize) {
  if (!Number.isSafeInteger(expectedSize) || expectedSize < 0) {
    throw new Error(
      `pinned archive size must be a non-negative safe integer, got ${expectedSize}`,
    );
  }
}

function validateContentLength(header, expectedSize, url) {
  assertPinnedArchiveSize(expectedSize);
  if (header === undefined) {
    return;
  }

  const values = (Array.isArray(header) ? header : [header])
    .flatMap((value) => String(value).split(","))
    .map((value) => value.trim());
  if (values.length === 0 || values.some((value) => !/^\d+$/u.test(value))) {
    throw new Error(`invalid Content-Length while downloading ${url}`);
  }

  const lengths = values.map((value) => BigInt(value));
  if (lengths.some((value) => value !== lengths[0])) {
    throw new Error(`inconsistent Content-Length while downloading ${url}`);
  }

  const expected = BigInt(expectedSize);
  if (lengths[0] > expected) {
    throw new Error(
      `archive response exceeds pinned size for ${url}: expected ${expectedSize}, got ${lengths[0]}`,
    );
  }
  if (lengths[0] !== expected) {
    throw new Error(
      `archive response Content-Length mismatch for ${url}: expected ${expectedSize}, got ${lengths[0]}`,
    );
  }
}

class ExactSizeTransform extends Transform {
  constructor(expectedSize, url) {
    super();
    assertPinnedArchiveSize(expectedSize);
    this.expectedSize = expectedSize;
    this.receivedSize = 0;
    this.url = url;
  }

  _transform(chunk, encoding, callback) {
    const nextSize = this.receivedSize + chunk.length;
    if (nextSize > this.expectedSize) {
      callback(
        new Error(
          `archive response exceeds pinned size for ${this.url}: expected ${this.expectedSize}, received more than ${this.expectedSize}`,
        ),
      );
      return;
    }
    this.receivedSize = nextSize;
    callback(null, chunk);
  }

  _flush(callback) {
    if (this.receivedSize !== this.expectedSize) {
      callback(
        new Error(
          `archive response size mismatch for ${this.url}: expected ${this.expectedSize}, got ${this.receivedSize}`,
        ),
      );
      return;
    }
    callback();
  }
}

function request(url) {
  return new Promise((resolve, reject) => {
    const outgoing = https.get(
      url,
      {
        headers: {
          Accept: "application/octet-stream",
          "Accept-Encoding": "identity",
          "User-Agent": "gaato-dave-moonbit-prebuild/0.1",
        },
      },
      resolve,
    );
    outgoing.setTimeout(REQUEST_TIMEOUT_MS, () => {
      outgoing.destroy(
        new Error(`download timed out after ${REQUEST_TIMEOUT_MS} ms: ${url}`),
      );
    });
    outgoing.once("error", reject);
  });
}

function extractZip(archivePath, destination) {
  let command;
  let args;
  if (process.platform === "win32") {
    const archiveBase64 = Buffer.from(archivePath, "utf8").toString("base64");
    const destinationBase64 = Buffer.from(destination, "utf8").toString(
      "base64",
    );
    const script = [
      "$ErrorActionPreference='Stop'",
      `$archive=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${archiveBase64}'))`,
      `$destination=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${destinationBase64}'))`,
      "Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force",
    ].join("; ");
    command = "powershell.exe";
    args = [
      "-NoLogo",
      "-NoProfile",
      "-NonInteractive",
      "-EncodedCommand",
      Buffer.from(script, "utf16le").toString("base64"),
    ];
  } else {
    command = "unzip";
    args = ["-q", archivePath, "-d", destination];
  }

  const result = spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 1024 * 1024,
    windowsHide: true,
  });
  if (result.error) {
    throw new Error(
      `could not extract ${path.basename(archivePath)} with ${command}: ${result.error.message}`,
    );
  }
  if (result.status !== 0) {
    const detail = String(result.stderr || result.stdout || "").trim();
    throw new Error(
      `${command} failed while extracting ${path.basename(archivePath)}${detail ? `: ${detail}` : ""}`,
    );
  }
}

function writeMarker(stagingRoot, asset) {
  const marker = {
    schema: 1,
    upstream: release.repository,
    tag: release.tag,
    commit: release.commit,
    asset: asset.archive,
    archiveSha256: asset.archiveSha256,
    library: asset.libraryRelativePath,
    librarySha256: asset.librarySha256,
  };
  fs.writeFileSync(
    path.join(stagingRoot, MARKER_FILE),
    `${JSON.stringify(marker, null, 2)}\n`,
    { encoding: "utf8", mode: 0o644 },
  );
}

function installStagingTree(stagingRoot, cacheRoot, asset) {
  if (hasExpectedLibrary(path.join(cacheRoot, asset.libraryRelativePath), asset)) {
    return;
  }
  removeIfPresent(cacheRoot);
  try {
    fs.renameSync(stagingRoot, cacheRoot);
  } catch (error) {
    if (
      error &&
      (error.code === "EEXIST" || error.code === "ENOTEMPTY") &&
      hasExpectedLibrary(path.join(cacheRoot, asset.libraryRelativePath), asset)
    ) {
      return;
    }
    throw error;
  }
}

function removeIfPresent(target) {
  try {
    fs.rmSync(target, { force: true, recursive: true });
  } catch (error) {
    if (!error || error.code !== "ENOENT") {
      throw error;
    }
  }
}

if (require.main === module) {
  main().catch((error) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`dave.mbt prebuild: ${message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  ExactSizeTransform,
  httpsDownloadUrl,
  validateContentLength,
};
