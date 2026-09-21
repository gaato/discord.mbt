///|
/// A custom id that exceeds Discord's limit or cannot round-trip its segments.
pub(all) suberror CustomIdError {
  /// The encoded state or complete custom id exceeds 100 UTF-16 units.
  TooLong(custom_id~ : String, length~ : Int)
  /// A non-final zip segment contains `:` and would not round-trip.
  SeparatorInSegment(segment~ : String)
} derive(Debug)

///|
fn check_custom_id_length(custom_id : String) -> Unit raise CustomIdError {
  let length = custom_id.length()
  if length > 100 {
    raise TooLong(custom_id~, length~)
  }
}

///|
/// A reversible text encoding for the state carried in a custom id.
/// Custom encode/decode functions and `imap` mappings must preserve round trips.
pub struct CustomIdCodec[A] {
  priv encode_ : (A) -> String
  priv decode_ : (String) -> A raise HandlerError
  priv validate_ : (A) -> Unit raise CustomIdError
}

///|
/// Encode unit as no state at all, producing only the route id.
pub fn CustomIdCodec::unit() -> CustomIdCodec[Unit] {
  CustomIdCodec::custom(encode=_ => "", decode=text => {
    guard text.is_empty() else {
      raise InvalidArgument("expected no component state")
    }
  })
}

///|
/// Preserve the state string, including separators in a final zip segment.
pub fn CustomIdCodec::string() -> CustomIdCodec[String] {
  CustomIdCodec::custom(encode=value => value, decode=text => text)
}

///|
/// Encode and decode a decimal integer.
pub fn CustomIdCodec::int() -> CustomIdCodec[Int] {
  CustomIdCodec::custom(encode=value => value.to_string(), decode=text => {
    @string.parse_int(text) catch {
      source => raise InvalidArgument("\{Repr(source)}")
    }
  })
}

///|
/// Encode and decode a snowflake without losing its phantom resource type.
pub fn[M] CustomIdCodec::id() -> CustomIdCodec[@model.Id[M]] {
  CustomIdCodec::custom(encode=value => value.to_string(), decode=text => {
    @model.Id::parse(text) catch {
      source => raise InvalidArgument("\{Repr(source)}")
    }
  })
}

///|
/// Define a reversible encoding. Decode failures should raise `InvalidArgument`.
pub fn[A] CustomIdCodec::custom(
  encode~ : (A) -> String,
  decode~ : (String) -> A raise HandlerError,
) -> CustomIdCodec[A] {
  { encode_: encode, decode_: decode, validate_: _ => (), }
}

///|
/// Join two encodings with `:` and split at the first `:` on decode.
/// Encoding rejects a separator in the non-final segment.
/// Nest additional segments on the right, e.g. `a.zip(b.zip(c))`.
pub fn[A, B] CustomIdCodec::zip(
  self : CustomIdCodec[A],
  other : CustomIdCodec[B],
) -> CustomIdCodec[(A, B)] {
  {
    encode_: value => "\{(self.encode_)(value.0)}:\{(other.encode_)(value.1)}",
    decode_: text => {
      guard text.find(":") is Some(index) else {
        raise InvalidArgument("expected ':' between component state segments")
      }
      (
        self.decode(text[:index].to_owned()),
        other.decode(text[index + 1:].to_owned()),
      )
    },
    validate_: value => {
      (self.validate_)(value.0)
      (other.validate_)(value.1)
      let segment = (self.encode_)(value.0)
      if segment.contains(":") {
        raise SeparatorInSegment(segment~)
      }
    },
  }
}

///|
/// Map a codec to another type using a fallible decode and a reverse mapping.
pub fn[A, B] CustomIdCodec::imap(
  self : CustomIdCodec[A],
  to~ : (A) -> B raise HandlerError,
  from~ : (B) -> A,
) -> CustomIdCodec[B] {
  {
    encode_: value => (self.encode_)(from(value)),
    decode_: text => to(self.decode(text)),
    validate_: value => (self.validate_)(from(value)),
  }
}

///|
/// Encode state, rejecting ambiguous zip segments and text over 100 UTF-16 units.
/// The complete route id is checked separately by `ComponentRoute::custom_id`.
pub fn[A] CustomIdCodec::encode(
  self : CustomIdCodec[A],
  value : A,
) -> String raise CustomIdError {
  (self.validate_)(value)
  let text = (self.encode_)(value)
  check_custom_id_length(text)
  text
}

///|
/// Decode untrusted state. The handler must still authorize the invoking user.
pub fn[A] CustomIdCodec::decode(
  self : CustomIdCodec[A],
  text : String,
) -> A raise HandlerError {
  (self.decode_)(text)
}

///|
/// A component's route identity and the codec shared by producer and handler.
pub struct ComponentRoute[A] {
  priv id_ : String
  priv state_ : CustomIdCodec[A]
}

///|
/// Define a component route matching `id` or `id:state`.
/// The id may itself contain `:`, so ids that are already in use elsewhere
/// (`bot:rolemenu`) keep working. `App::validate` rejects empty ids, ids over
/// 100 units, and an id that extends another typed route's id at a `:`
/// (`ticket` beside `ticket:close`), because the shorter route's state could
/// then produce a custom id the longer route receives.
///
/// ```mbt check
/// test "build a component from its route" {
///   let route = @app.component_route(id="page", state=@app.CustomIdCodec::int())
///   let app = @app.App()
///   app.on_component(
///     route,
///     Immediate((_, page) => @app.ComponentReply::message(content="Page \{page}")),
///   )
///   let _ = @interaction.button(custom_id=route.custom_id(2), label="Next")
///   assert_eq(route.custom_id(2), "page:2")
///   app.validate()
/// }
/// ```
pub fn[A] component_route(
  id~ : String,
  state~ : CustomIdCodec[A],
) -> ComponentRoute[A] {
  { id_: id, state_: state, }
}

///|
/// Build the id or `id:state`, enforcing Discord's 100 UTF-16-unit limit.
/// An empty encoded state produces the bare id.
pub fn[A] ComponentRoute::custom_id(
  self : ComponentRoute[A],
  state : A,
) -> String raise CustomIdError {
  (self.state_.validate_)(state)
  let text = (self.state_.encode_)(state)
  let custom_id = if text.is_empty() { self.id_ } else { "\{self.id_}:\{text}" }
  check_custom_id_length(custom_id)
  custom_id
}

///|
/// Decode the state from a custom id this route produced — the inverse of
/// `custom_id`. Typed handlers receive the state already decoded; use this for
/// ids that reach you undecoded, such as the `ComponentCtx` returned by
/// `wait_for_component`, and in tests. An id that belongs to another route, or
/// whose state does not decode, raises `HandlerError::InvalidArgument`. The
/// decoded state is untrusted input.
///
/// ```mbt check
/// test {
///   let route = @app.component_route(
///     id="ticket-close",
///     state=@app.CustomIdCodec::int(),
///   )
///   assert_eq(route.decode(route.custom_id(42)), 42)
/// }
/// ```
pub fn[A] ComponentRoute::decode(
  self : ComponentRoute[A],
  custom_id : String,
) -> A raise HandlerError {
  let text = if custom_id == self.id_ {
    ""
  } else if custom_id.has_prefix("\{self.id_}:") {
    custom_id[self.id_.length() + 1:].to_owned()
  } else {
    raise InvalidArgument(
      "custom id \{custom_id} does not belong to route \{self.id_}",
    )
  }
  self.state_.decode(text) catch {
    source => raise InvalidArgument("\{Repr(source)}")
  }
}

///|
priv enum AppRoutePattern {
  Prefix(String)
  Id(String)
}

///|
fn AppRoutePattern::base(self : AppRoutePattern) -> String {
  match self {
    Prefix(prefix) | Id(prefix) => prefix
  }
}

///|
fn validate_route(
  pattern : AppRoutePattern,
  seen : Set[String],
  ids : Array[String],
  modal~ : Bool,
) -> Unit raise AppConfigError {
  let custom_id = pattern.base()
  if custom_id.is_empty() {
    if modal {
      raise EmptyModalRoute
    } else {
      raise EmptyComponentRoute
    }
  }
  let effective_prefix = match pattern {
    Prefix(prefix) => prefix
    Id(id) => {
      if id.length() > 100 {
        raise InvalidRouteId(
          custom_id~,
          reason="route ids cannot exceed 100 UTF-16 units",
        )
      }
      "\{id}:"
    }
  }
  if seen.contains(effective_prefix) {
    if modal {
      raise DuplicateModalRoute(custom_id~)
    } else {
      raise DuplicateComponentRoute(custom_id~)
    }
  }
  seen.add(effective_prefix)
  if pattern is Id(id) {
    // Typed routes never shadow each other: `a` and `a:b` would both match
    // `a:b:state`, and state encoded for `a` could reach the handler of `a:b`.
    for other in ids {
      if effective_prefix.has_prefix("\{other}:") ||
        "\{other}:".has_prefix(effective_prefix) {
        raise InvalidRouteId(
          custom_id~,
          reason="overlaps the typed route id '\{other}' at a ':' boundary",
        )
      }
    }
    ids.push(id)
  }
}
