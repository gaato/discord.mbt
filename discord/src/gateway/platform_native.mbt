///|
fn identify_os() -> String {
  // An `is` chain rather than a match: core/async after MoonBit 0.10.20
  // marks Platform #non_exhaustive, so a match needs a catch-all arm that
  // 0.10.20 reports as unused.
  let platform = @async.platform
  if platform is Linux {
    "linux"
  } else if platform is MacOS {
    "darwin"
  } else if platform is Windows {
    "windows"
  } else {
    "unknown"
  }
}

///|
/// The close code for an oversized message: 1009, Message Too Big.
const OVERSIZED_CLOSE_CODE : Int32 = 1009
