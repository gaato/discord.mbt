"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const outputArgument = process.argv[2];
if (!outputArgument) {
  throw new Error("usage: node package-licenses.js <output-directory>");
}

const crateRoot = __dirname;
const result = spawnSync(
  "cargo",
  ["metadata", "--locked", "--format-version", "1"],
  { cwd: crateRoot, encoding: "utf8" },
);
if (result.status !== 0) {
  process.stderr.write(result.stderr || "cargo metadata failed\n");
  process.exit(result.status || 1);
}

const metadata = JSON.parse(result.stdout);
const outputRoot = path.resolve(process.cwd(), outputArgument);
if (fs.existsSync(outputRoot)) {
  throw new Error(`output directory already exists: ${outputRoot}`);
}
fs.mkdirSync(outputRoot, { recursive: true });

const packages = metadata.packages
  .filter((pkg) => pkg.id !== metadata.resolve.root)
  .sort((left, right) => left.name.localeCompare(right.name));

for (const pkg of packages) {
  const packageRoot = path.dirname(pkg.manifest_path);
  const notices = fs.readdirSync(packageRoot).filter((name) =>
    /^(LICENSE|LICENCE|COPYING|NOTICE)/iu.test(name),
  );
  if (notices.length === 0) {
    throw new Error(`${pkg.name} ${pkg.version} ships no license notice`);
  }
  const destination = path.join(outputRoot, `${pkg.name}-${pkg.version}`);
  fs.mkdirSync(destination, { recursive: true });
  for (const notice of notices.sort()) {
    const source = path.join(packageRoot, notice);
    if (fs.statSync(source).isFile()) {
      fs.copyFileSync(source, path.join(destination, notice));
    }
  }
}
