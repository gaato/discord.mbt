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
  priv suggest : SuggestHandler?
}

///|
/// A typed collection of command options used for registration and decoding.
pub struct Args[A] {
  priv definitions_ : Array[@model.CommandOption]
  priv decode_ : (CommandOptions) -> A raise
  priv suggests_ : Array[SuggestHandler]
}

///|
fn[A] required_arg(
  definition : @model.CommandOption,
  read : (CommandOptions) -> A raise,
  suggest? : SuggestHandler,
) -> Arg[A] {
  { definition, read, suggest, }
}

///|
fn[A] typed_suggest(
  name : String,
  decode : (SuggestInput) -> A raise,
  suggest : (async (SuggestCtx, A) -> Array[@model.CommandOptionChoice])?,
) -> SuggestHandler? {
  match suggest {
    Some(run) =>
      Some({ name_: name, run_: (ctx, input) => run(ctx, decode(input)), })
    None => None
  }
}

///|
fn collect_suggests(suggests : Array[SuggestHandler?]) -> Array[SuggestHandler] {
  suggests.filter_map(value => value)
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
  suggest? : async (SuggestCtx, String) -> Array[@model.CommandOptionChoice],
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[String] {
  let suggest_handler = typed_suggest(
    name,
    input => json_string(input.value_, name, "string"),
    suggest,
  )
  required_arg(
    string_option(
      name,
      description,
      required=true,
      choices?,
      min_length?,
      max_length?,
      autocomplete?=suggest_handler.map(_ => true),
      name_localizations?,
      description_localizations?,
    ),
    options => options.string(name),
    suggest?=suggest_handler,
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
  suggest? : async (SuggestCtx, Int64) -> Array[@model.CommandOptionChoice],
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[Int64] {
  let suggest_handler = typed_suggest(
    name,
    input => json_int64(input.value_, name, "integer"),
    suggest,
  )
  required_arg(
    integer_option(
      name,
      description,
      required=true,
      choices?,
      min_value?=min,
      max_value?=max,
      autocomplete?=suggest_handler.map(_ => true),
      name_localizations?,
      description_localizations?,
    ),
    options => options.int(name),
    suggest?=suggest_handler,
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
  suggest? : async (SuggestCtx, Double) -> Array[@model.CommandOptionChoice],
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[Double] {
  let suggest_handler = typed_suggest(
    name,
    input => json_double(input.value_, name, "number"),
    suggest,
  )
  required_arg(
    number_option(
      name,
      description,
      required=true,
      choices?,
      min_value?=min,
      max_value?=max,
      autocomplete?=suggest_handler.map(_ => true),
      name_localizations?,
      description_localizations?,
    ),
    options => options.number(name),
    suggest?=suggest_handler,
  )
}

///|
/// Define a required boolean option.
pub fn arg_bool(
  name~ : String,
  description~ : String,
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[Bool] {
  required_arg(
    boolean_option(
      name,
      description,
      required=true,
      name_localizations?,
      description_localizations?,
    ),
    options => options.bool(name),
  )
}

///|
/// Define a required user option.
pub fn arg_user(
  name~ : String,
  description~ : String,
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[@model.UserId] {
  required_arg(
    user_option(
      name,
      description,
      required=true,
      name_localizations?,
      description_localizations?,
    ),
    options => options.user(name),
  )
}

///|
/// Define a required channel option.
pub fn arg_channel(
  name~ : String,
  description~ : String,
  channel_types? : Array[@model.ChannelType],
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[@model.ChannelId] {
  required_arg(
    channel_option(
      name,
      description,
      required=true,
      channel_types?,
      name_localizations?,
      description_localizations?,
    ),
    options => options.channel(name),
  )
}

///|
/// Define a required role option.
pub fn arg_role(
  name~ : String,
  description~ : String,
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[@model.RoleId] {
  required_arg(
    role_option(
      name,
      description,
      required=true,
      name_localizations?,
      description_localizations?,
    ),
    options => options.role(name),
  )
}

///|
/// Define a required mentionable option.
pub fn arg_mentionable(
  name~ : String,
  description~ : String,
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[@model.GenericId] {
  required_arg(
    mentionable_option(
      name,
      description,
      required=true,
      name_localizations?,
      description_localizations?,
    ),
    options => options.mentionable(name),
  )
}

///|
/// Define a required attachment option resolved to its attachment object.
pub fn arg_attachment(
  name~ : String,
  description~ : String,
  name_localizations? : Map[String, String],
  description_localizations? : Map[String, String],
) -> Arg[@model.Attachment] {
  required_arg(
    attachment_option(
      name,
      description,
      required=true,
      name_localizations?,
      description_localizations?,
    ),
    options => options.attachment(name),
  )
}

///|
/// Make an argument optional. A missing submitted option decodes to `None`.
///
/// ```mbt check
/// test "make a command option optional" {
///   let args = @interaction.Args::of(
///     @interaction.arg_string(name="note", description="Optional note").optional(),
///   )
///   json_inspect(args.definitions(), content=[
///     {
///       "type": 3,
///       "name": "note",
///       "description": "Optional note",
///       "required": false,
///     },
///   ])
/// }
/// ```
pub fn[A] Arg::optional(self : Arg[A]) -> Arg[A?] {
  let definition = { ..self.definition, required: Some(false), }
  let name = definition.name
  {
    definition,
    suggest: self.suggest,
    read: options => {
      if options.has(name) {
        Some(self.read_value(options))
      } else {
        None
      }
    },
  }
}

///|
/// Make an argument optional in the registration payload and use a default
/// value when it is absent from a submitted command.
pub fn[A] Arg::with_default(self : Arg[A], value : A) -> Arg[A] {
  let definition = { ..self.definition, required: Some(false), }
  let name = definition.name
  {
    definition,
    suggest: self.suggest,
    read: options => {
      if options.has(name) {
        self.read_value(options)
      } else {
        value
      }
    },
  }
}

///|
/// Validate a decoded argument. Returning `Some(message)` rejects the value.
pub fn[A] Arg::validate(self : Arg[A], check : (A) -> String?) -> Arg[A] {
  let name = self.definition.name
  {
    definition: self.definition,
    suggest: self.suggest,
    read: options => {
      let value = self.read_value(options)
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
  {
    definition: self.definition,
    read: options => f(self.read_value(options)),
    suggest: self.suggest,
  }
}

///|
/// Return the option definitions in registration order.
pub fn[A] Args::definitions(self : Args[A]) -> Array[@model.CommandOption] {
  self.definitions_.copy()
}

///|
/// Return the type-erased autocomplete handlers carried by these arguments.
pub fn[A] Args::suggestions(self : Args[A]) -> Array[SuggestHandler] {
  self.suggests_.copy()
}

///|
/// Decode submitted command options into the composed value.
pub fn[A] Args::decode(self : Args[A], input : CommandOptions) -> A raise {
  self.decode_value(input)
}

///|
/// Lift one argument into a composable argument collection.
///
/// ```mbt check
/// test "compose defaulting and validation into an argument spec" {
///   let args = @interaction.Args::of(
///     @interaction.arg_int(
///       name="times",
///       description="Repeat count",
///       min=1L,
///       max=5L,
///     )
///     .with_default(1L)
///     .validate(value => if value <= 5L { None } else { Some("too large") }),
///   )
///   json_inspect(args.definitions(), content=[
///     {
///       "type": 4,
///       "name": "times",
///       "description": "Repeat count",
///       "required": false,
///       "min_value": 1,
///       "max_value": 5,
///     },
///   ])
/// }
/// ```
pub fn[A] Args::of(arg : Arg[A]) -> Args[A] {
  {
    definitions_: [arg.definition],
    decode_: arg.read,
    suggests_: collect_suggests([arg.suggest]),
  }
}

///|
/// Transform the result of a composed argument collection.
pub fn[A, B] Args::map(self : Args[A], f : (A) -> B) -> Args[B] {
  {
    definitions_: self.definitions_,
    decode_: options => f(self.decode_value(options)),
    suggests_: self.suggests_,
  }
}

///|
/// Combine two argument collections, preserving left-to-right definition and
/// decoding order.
pub fn[A, B] Args::zip(self : Args[A], other : Args[B]) -> Args[(A, B)] {
  let definitions = self.definitions_.copy()
  definitions.push_iter(other.definitions_.iter())
  let suggests = self.suggests_.copy()
  suggests.push_iter(other.suggests_.iter())
  {
    definitions_: definitions,
    decode_: options => {
      let left = self.decode_value(options)
      let right = other.decode_value(options)
      (left, right)
    },
    suggests_: suggests,
  }
}

///|
/// Define a command with no options.
pub fn Args::unit() -> Args[Unit] {
  { definitions_: [], decode_: _ => (), suggests_: [], }
}

///|
/// Build an argument collection from custom definitions and a custom decoder.
pub fn[A] Args::custom(
  definitions~ : Array[@model.CommandOption],
  decode~ : (CommandOptions) -> A raise,
) -> Args[A] {
  { definitions_: definitions.copy(), decode_: decode, suggests_: [], }
}

///|
/// Build a command's argument decoder from one option. The option is
/// registered from `a`'s definition and `f` maps its decoded value
/// into the handler's argument type.
pub fn[A, Z] Args::map1(a : Arg[A], f : (A) -> Z) -> Args[Z] {
  Args::of(a).map(f)
}

///|
/// Build a command's argument decoder from two options, combining
/// their decoded values with the final function argument.
pub fn[A, B, Z] Args::map2(a : Arg[A], b : Arg[B], f : (A, B) -> Z) -> Args[Z] {
  {
    definitions_: [a.definition, b.definition],
    suggests_: collect_suggests([a.suggest, b.suggest]),
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      f(av, bv)
    },
  }
}

///|
/// Build a command's argument decoder from three options, combining
/// their decoded values with the final function argument.
pub fn[A, B, C, Z] Args::map3(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  f : (A, B, C) -> Z,
) -> Args[Z] {
  {
    definitions_: [a.definition, b.definition, c.definition],
    suggests_: collect_suggests([a.suggest, b.suggest, c.suggest]),
    decode_: options => {
      let av = a.read_value(options)
      let bv = b.read_value(options)
      let cv = c.read_value(options)
      f(av, bv, cv)
    },
  }
}

///|
/// Build a command's argument decoder from four options, combining
/// their decoded values with the final function argument.
pub fn[A, B, C, D, Z] Args::map4(
  a : Arg[A],
  b : Arg[B],
  c : Arg[C],
  d : Arg[D],
  f : (A, B, C, D) -> Z,
) -> Args[Z] {
  {
    definitions_: [a.definition, b.definition, c.definition, d.definition],
    suggests_: collect_suggests([a.suggest, b.suggest, c.suggest, d.suggest]),
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
/// Build a command's argument decoder from five options, combining
/// their decoded values with the final function argument.
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
    suggests_: collect_suggests([
      a.suggest,
      b.suggest,
      c.suggest,
      d.suggest,
      e.suggest,
    ]),
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
/// Build a command's argument decoder from six options, combining
/// their decoded values with the final function argument.
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
    suggests_: collect_suggests([
      a.suggest,
      b.suggest,
      c.suggest,
      d.suggest,
      e.suggest,
      f.suggest,
    ]),
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
/// Build a command's argument decoder from seven options, combining
/// their decoded values with the final function argument.
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
    suggests_: collect_suggests([
      a.suggest,
      b.suggest,
      c.suggest,
      d.suggest,
      e.suggest,
      f.suggest,
      g.suggest,
    ]),
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
/// Build a command's argument decoder from eight options, combining
/// their decoded values with the final function argument.
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
    suggests_: collect_suggests([
      a.suggest,
      b.suggest,
      c.suggest,
      d.suggest,
      e.suggest,
      f.suggest,
      g.suggest,
      h.suggest,
    ]),
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
