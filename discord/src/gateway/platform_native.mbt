///|
fn identify_os() -> String {
  match @async.platform {
    Linux => "linux"
    MacOS => "darwin"
    Windows => "windows"
  }
}

///|
/// The close code for an oversized message: 1009, Message Too Big.
const OVERSIZED_CLOSE_CODE : Int32 = 1009
