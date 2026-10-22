///|
// The JavaScript-only signed interaction dispatch bridge.

///|
/// A JavaScript `{ response, background }` object for one interaction dispatch.
pub using @app {type InteractionHttpDispatch}

///|
/// The JavaScript response a dispatch resolves to: an object with `status`,
/// `contentType`, and `body`.
pub using @app {type InteractionHttpJsResponse}
