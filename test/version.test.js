"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");

test("MoonBit module and HTTP client versions match", () => {
  const moduleSource = fs.readFileSync(path.join(root, "moon.mod"), "utf8");
  const clientSource = fs.readFileSync(
    path.join(root, "src/http/client.mbt"),
    "utf8",
  );
  const moduleVersion = moduleSource.match(/^version\s*=\s*"([^"]+)"\s*$/mu);
  const clientVersion = clientSource.match(
    /^pub const VERSION\s*:\s*String\s*=\s*"([^"]+)"\s*$/mu,
  );

  assert.ok(moduleVersion, "moon.mod must declare a version");
  assert.ok(clientVersion, "src/http/client.mbt must declare VERSION");
  assert.equal(clientVersion[1], moduleVersion[1]);
});
