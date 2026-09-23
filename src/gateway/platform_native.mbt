///|
fn identify_os() -> String {
  match @async.platform {
    Linux => "linux"
    MacOS => "darwin"
    Windows => "windows"
  }
}
