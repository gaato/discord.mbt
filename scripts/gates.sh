#!/usr/bin/env bash
# The MoonBit gates that depend on the toolchain version: type checks, format,
# and the test suites of every workspace member. CI (ci.yml) runs them on the
# pinned toolchain and the canary (canary.yml) on the latest and nightly ones,
# both through this script, so the canary cannot drift from what CI checks.
#
# Usage: scripts/gates.sh [check|native|js|wasm|dave|all] [ARGS...]
#   check   native type check, format, and gaato/discord against the
#           published versions of its dependencies
#   native  native tests; ARGS go to `moon test`, so CI can add
#           --enable-coverage for its coverage report
#   js      js type check and tests
#   wasm    Wasm type check, tests, and the HTTP interactions example build
#   dave    gaato/dave built on its own, as published: native against
#           libdave, and the unavailable facade on js and Wasm
#   all     every gate above, in that order (the default)
#
# The audits, the voice shim, the JavaScript host runtimes, the Spin
# component, and the template image stay in ci.yml: they need tools the
# canary image does not carry or do not depend on the toolchain version.
# dave.yml runs the dave gates on each platform, Windows included, with its
# own steps, so a change to the dave gate here must be made there too.
set -euo pipefail
cd "$(dirname "$0")/.."

run() {
  echo "+ $*"
  "$@"
}

gate_check() {
  run moon check --target native --deny-warn
  run moon fmt --check
  # The workspace resolves every member to its directory; a consumer gets
  # every dependency from the registry.
  run env MOON_WORK=off moon -C discord check --target native --deny-warn
}

gate_native() {
  run moon test --target native "$@"
}

gate_js() {
  run moon check --target js --deny-warn
  run moon test --target js
}

gate_wasm() {
  run moon check --target wasm --deny-warn
  # Explicit roots must not silently disappear through target filtering.
  run moon check discord/src discord/src/coordinator discord/src/endpoint_http \
    discord/src/testkit --target wasm --deny-warn
  # --verbose names each test, including the HTTP and TCP loopback ones.
  run moon test --target wasm --release --verbose
  run moon build examples/interactions_http --target wasm --release --deny-warn
}

gate_dave() (
  cd dave
  export MOON_WORK=off
  # Only the native backend can load libdave; the native gates must not fall
  # back to the unavailable facade.
  run env MBT_DAVE_REQUIRE_NATIVE=1 moon check --target native --deny-warn
  run env MBT_DAVE_REQUIRE_NATIVE=1 moon build --target native --release --deny-warn
  run env MBT_DAVE_REQUIRE_NATIVE=1 moon test --target native --release --deny-warn
  run moon fmt --check
  # js and Wasm test the unavailable facade and must not bootstrap libdave.
  for target in js wasm; do
    run env MBT_DAVE_NATIVE_ROOT=/definitely/missing/dave-must-not-bootstrap \
      moon check --target "$target" --deny-warn
    run env MBT_DAVE_NATIVE_ROOT=/definitely/missing/dave-must-not-bootstrap \
      moon test --target "$target" --release --deny-warn
  done
)

usage() {
  echo "usage: scripts/gates.sh [check|native|js|wasm|dave|all] [ARGS...]" >&2
  exit 2
}

gate="${1:-all}"
[ $# -gt 0 ] && shift
if [ "$gate" != native ] && [ $# -gt 0 ]; then
  usage
fi

case "$gate" in
  check) gate_check ;;
  native) gate_native "$@" ;;
  js) gate_js ;;
  wasm) gate_wasm ;;
  dave) gate_dave ;;
  all)
    gate_check
    gate_native
    gate_js
    gate_wasm
    gate_dave
    ;;
  *) usage ;;
esac
