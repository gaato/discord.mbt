///|
/// Schedules per run. On JavaScript every scheduler round costs a macrotask,
/// so this target samples a few; native and Wasm run the full set.
const FUZZ_SEED_COUNT : Int32 = 8
