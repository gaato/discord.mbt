"use strict";

const assert = require("node:assert/strict");
const { Readable, Writable } = require("node:stream");
const { pipeline } = require("node:stream/promises");
const test = require("node:test");

const {
  ExactSizeTransform,
  httpsDownloadUrl,
  validateContentLength,
} = require("../build.js");

const TEST_URL = "https://example.invalid/libdave.zip";

test("Content-Length accepts the pinned size and optional omission", () => {
  assert.doesNotThrow(() => validateContentLength(undefined, 4, TEST_URL));
  assert.doesNotThrow(() => validateContentLength("4", 4, TEST_URL));
  assert.doesNotThrow(() => validateContentLength(["4", "4"], 4, TEST_URL));
});

test("initial and redirected download URLs must stay on HTTPS", () => {
  assert.equal(httpsDownloadUrl(TEST_URL).protocol, "https:");
  assert.throws(
    () => httpsDownloadUrl("http://example.invalid/libdave.zip"),
    /unsupported download protocol/u,
  );
  assert.throws(
    () => httpsDownloadUrl("file:///tmp/libdave.zip"),
    /unsupported download protocol/u,
  );
});

test("Content-Length rejects malformed, inconsistent, and mismatched sizes", () => {
  assert.throws(
    () => validateContentLength("unknown", 4, TEST_URL),
    /invalid Content-Length/u,
  );
  assert.throws(
    () => validateContentLength(["4", "5"], 4, TEST_URL),
    /inconsistent Content-Length/u,
  );
  assert.throws(
    () => validateContentLength("3", 4, TEST_URL),
    /Content-Length mismatch/u,
  );
  assert.throws(
    () => validateContentLength("5", 4, TEST_URL),
    /exceeds pinned size/u,
  );
});

async function collectWithLimit(chunks, expectedSize) {
  const collected = [];
  await pipeline(
    Readable.from(chunks),
    new ExactSizeTransform(expectedSize, TEST_URL),
    new Writable({
      write(chunk, encoding, callback) {
        collected.push(Buffer.from(chunk));
        callback();
      },
    }),
  );
  return Buffer.concat(collected);
}

test("response gate accepts an exact-size body", async () => {
  const result = await collectWithLimit([Buffer.from("ab"), Buffer.from("cd")], 4);
  assert.equal(result.toString("utf8"), "abcd");
});

test("response gate rejects an undersized body", async () => {
  await assert.rejects(
    collectWithLimit([Buffer.from("abc")], 4),
    /response size mismatch/u,
  );
});

test("chunked response gate rejects a chunk before writing past the pinned size", async () => {
  const collected = [];
  validateContentLength(undefined, 5, TEST_URL);
  await assert.rejects(
    pipeline(
      Readable.from([Buffer.from("abc"), Buffer.from("def")]),
      new ExactSizeTransform(5, TEST_URL),
      new Writable({
        write(chunk, encoding, callback) {
          collected.push(Buffer.from(chunk));
          callback();
        },
      }),
    ),
    /exceeds pinned size/u,
  );
  assert.equal(Buffer.concat(collected).toString("utf8"), "abc");
});
