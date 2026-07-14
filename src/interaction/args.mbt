///|
/// Errors introduced by typed argument combinators.
pub(all) suberror ArgsDecodeError {
  Validation(name~ : String, message~ : String)
} derive(Debug)

///|
/// One typed command option, combining its registration definition and reader.
pub struct Arg[A] {
  priv definition : @model.CommandOption
  priv read : (CommandOptions) -> A raise
}

///|
/// A typed collection of command options used for registration and decoding.
pub struct Args[A] {
  priv definitions_ : Array[@model.CommandOption]
  priv decode_ : (CommandOptions) -> A raise
}

///|
fn[A] required_arg(
  definition : @model.CommandOption,
  read : (CommandOptions) -> A raise,
) -> Arg[A] {
  { definition, read }
}

///|
fn[A] Arg::read_value(self : Arg[A], options : CommandOptions) -> A raise {
  (self.read)(options)
}

///|
fn[A] Args::decode_value(self : Args[A], options : CommandOptions) -> A raise {
  (self.decode_)(options)
}

///|
/// Define a required string option.
pub fn arg_string(
  name~ : String,
  description~ : String,
  choices? : Array[@model.CommandOptionChoice],
  min_length? : Int,
  max_length? : Int,
) -> Arg[String] {
  required_arg(
    string_option(
      name,
      description,
      required=true,
      choices?,
      min_length?,
      max_length?,
    ),
    options => options.string(name),
  )
}

///|
/// Define a required integer option.
pub fn arg_int(
  name~ : String,
  description~ : String,
  min? : Int64,
  max? : Int64,
  choices? : Array[@model.CommandOptionChoice],
) -> Arg[Int64] {
  required_arg(
    integer_option(
      name,
      description,
      required=true,
      choices?,
      min_value?=min,
      max_value?=max,
    ),
    options => options.int(name),
  )
}

///|
/// Define a required floating-point number option.
pub fn arg_number(
  name~ : String,
  description~ : String,
  min? : Double,
  max? : Double,
  choices? : Array[@model.CommandOptionChoice],
) -> Arg[Double] {
  required_arg(
    number_option(
      name,
      description,
      required=true,
      choices?,
      min_value?=min,
      max_value?=max,
    ),
    options => options.number(name),
  )
}

///|
/// Define a required boolean option.
pub fn arg_bool(name~ : String, description~ : String) -> Arg[Bool] {
  required_arg(boolean_option(name, description, required=true), options => {
    options.bool(name)
  })
}

///|
/// Define a required user option.
pub fn arg_user(name~ : String, description~ : String) -> Arg[@model.UserId] {
  required_arg(user_option(name, description, required=true), options => {
    options.user(name)
  })
}

///|
/// Define a required channel option.
pub fn arg_channel(
  name~ : String,
  description~ : String,
  channel_types? : Array[@model.ChannelType],
) -> Arg[@model.ChannelId] {
  required_arg(
    channel_option(name, description, required=true, channel_types?),
    options => options.channel(name),
  )
}

///|
/// Define a required role option.
pub fn arg_role(name~ : String, description~ : String) -> Arg[@model.RoleId] {
  required_arg(role_option(name, description, required=true), options => {
    options.role(name)
  })
}

///|
/// Define a required mentionable option.
pub fn arg_mentionable(
  name~ : String,
  description~ : String,
) -> Arg[@model.GenericId] {
  required_arg(mentionable_option(name, description, required=true), options => {
    options.mentionable(name)
  })
}

///|
/// Define a required attachment option resolved to its attachment object.
pub fn arg_attachment(
  name~ : String,
  description~ : String,
) -> Arg[@model.Attachment] {
  required_arg(attachment_option(name, description, required=true), options => {
    options.attachment(name)
  })
}

///|
/// Make an argument optional. A missing submitted option decodes to `None`.
pub fn[A] optional(arg : Arg[A]) -> Arg[A?] {
  let definition = { ..arg.definition, required: Some(false) }
  let name = definition.name
  {
    definition,
    read: options => {
      if options.has(name) {
        Some(arg.read_value(options))
      } else {
        None
      }
    },
  }
}

///|
/// Make an argument optional in the registration payload and use a default
/// value when it is absent from a submitted command.
pub fn[A] default(arg : Arg[A], value : A) -> Arg[A] {
  let definition = { ..arg.definition, required: Some(false) }
  let name = definition.name
  {
    definition,
    read: options => {
      if options.has(name) {
        arg.read_value(options)
      } else {
        value
      }
    },
  }
}

///|
/// Validate a decoded argument. Returning `Some(message)` rejects the value.
pub fn[A] validate(arg : Arg[A], check : (A) -> String?) -> Arg[A] {
  let name = arg.definition.name
  {
    definition: arg.definition,
    read: options => {
      let value = arg.read_value(options)
      match check(value) {
        Some(message) => raise ArgsDecodeError::Validation(name~, message~)
        None => value
      }
    },
  }
}

///|
/// Transform one decoded argument without changing its registration definition.
pub fn[A, B] Arg::map(self : Arg[A], f : (A) -> B) -> Arg[B] {
  { definition: self.definition, read: options => f(self.read_value(options)) }
}

///|
/// Return the option definitions in registration order.
pub fn[A] Args::definitions(self : Args[A]) -> Array[@model.CommandOption] {
  self.definitions_.copy()
}

///|
/// Decode submitted command options into the composed value.
pub fn[A] Args::decode(self : Args[A], input : CommandOptions) -> A raise {
  self.decode_value(input)
}

///|
/// Lift one argument into a composable argument collection.
pub fn[A] Args::of(arg : Arg[A]) -> Args[A] {
  { definitions_: [arg.definition], decode_: arg.read }
}

///|
/// Transform the result of a composed argument collection.
pub fn[A, B] Args::map(self : Args[A], f : (A) -> B) -> Args[B] {
  {
    definitions_: self.definitions_,
    decode_: options => f(self.decode_value(options)),
  }
}

///|
/// Combine two argument collections, preserving left-to-right definition and
/// decoding order.
pub fn[A, B] Args::zip(self : Args[A], other : Args[B]) -> Args[(A, B)] {
  let definitions = self.definitions_.copy()
  definitions.push_iter(other.definitions_.iter())
  {
    definitions_: definitions,
    decode_: options => {
      let left = self.decode_value(options)
      let right = other.decode_value(options)
      (left, right)
    },
  }
}

///|
/// Define a command with no options.
pub fn Args::unit() -> Args[Unit] {
  { definitions_: [], decode_: _ => () }
}

///|
/// Build an argument collection from custom definitions and a custom decoder.
pub fn[A] Args::custom(
  definitions~ : Array[@model.CommandOption],
  decode~ : (CommandOptions) -> A raise,
) -> Args[A] {
  { definitions_: definitions.copy(), decode_: decode }
}

///|
pub fn[A, Z] Args::map1(a : Arg[A], f : (A) -> Z) -> Args[Z] {
  Args::of(a).map(f)
}

///|
pub fn[A, B, Z] Args::map2(a : Arg[A], b : Arg[B], f : (A, B) -> Z) -> Args[Z] {
  {
    definitions_: [a.definition, b.definition],
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      f(av, bv)
    },
  }
}

///|
pub fn[A, B, C, Z] Args::map3(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  f : (A, B, C) -> Z,
) -> Args[Z] {
  {
    definitions_: [a.definition, b.definition, c.definition],
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      let cv = c.read_value(options)
      f(av, bv, cv)
    },
  }
}

///|
pub fn[A, B, C, D, Z] Args::map4(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  d : Arg[D],
  f : (A, B, C, D) -> Z,
) -> Args[Z] {
  {
    definitions_: [a.definition, b.definition, c.definition, d.definition],
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      let cv = c.read_value(options)
      let dv = d.read_value(options)
      f(av, bv, cv, dv)
    },
  }
}

///|
pub fn[A, B, C, D, E, Z] Args::map5(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  d : Arg[D],
  e : Arg[E],
  f : (A, B, C, D, E) -> Z,
) -> Args[Z] {
  {
    definitions_: [
      a.definition,
      b.definition,
      c.definition,
      d.definition,
      e.definition,
    ],
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      let cv = c.read_value(options)
      let dv = d.read_value(options)
      let ev = e.read_value(options)
      f(av, bv, cv, dv, ev)
    },
  }
}

///|
pub fn[A, B, C, D, E, F, Z] Args::map6(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  d : Arg[D],
  e : Arg[E],
  f : Arg[F],
  combine : (A, B, C, D, E, F) -> Z,
) -> Args[Z] {
  {
    definitions_: [
      a.definition,
      b.definition,
      c.definition,
      d.definition,
      e.definition,
      f.definition,
    ],
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      let cv = c.read_value(options)
      let dv = d.read_value(options)
      let ev = e.read_value(options)
      let fv = f.read_value(options)
      combine(av, bv, cv, dv, ev, fv)
    },
  }
}

///|
pub fn[A, B, C, D, E, F, G, Z] Args::map7(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  d : Arg[D],
  e : Arg[E],
  f : Arg[F],
  g : Arg[G],
  combine : (A, B, C, D, E, F, G) -> Z,
) -> Args[Z] {
  {
    definitions_: [
      a.definition,
      b.definition,
      c.definition,
      d.definition,
      e.definition,
      f.definition,
      g.definition,
    ],
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      let cv = c.read_value(options)
      let dv = d.read_value(options)
      let ev = e.read_value(options)
      let fv = f.read_value(options)
      let gv = g.read_value(options)
      combine(av, bv, cv, dv, ev, fv, gv)
    },
  }
}

///|
pub fn[A, B, C, D, E, F, G, H, Z] Args::map8(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  d : Arg[D],
  e : Arg[E],
  f : Arg[F],
  g : Arg[G],
  h : Arg[H],
  combine : (A, B, C, D, E, F, G, H) -> Z,
) -> Args[Z] {
  {
    definitions_: [
      a.definition,
      b.definition,
      c.definition,
      d.definition,
      e.definition,
      f.definition,
      g.definition,
      h.definition,
    ],
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      let cv = c.read_value(options)
      let dv = d.read_value(options)
      let ev = e.read_value(options)
      let fv = f.read_value(options)
      let gv = g.read_value(options)
      let hv = h.read_value(options)
      combine(av, bv, cv, dv, ev, fv, gv, hv)
    },
  }
}
