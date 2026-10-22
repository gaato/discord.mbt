///|
// Discord HTTP-interactions server for native and moonrun Wasm.

///|
/// An HTTP server dispatching Discord interactions on native or moonrun Wasm.
pub using @endpoint_http {type InteractionsServer}

///|
/// Configuration rejected by `serve_interactions` before it starts listening.
pub using @endpoint_http {type ServerConfigError}

///|
/// Start a Discord HTTP-interactions server in `group` on native or moonrun
/// Wasm.
pub using @endpoint_http {serve_interactions}
