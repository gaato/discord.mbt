///|
/// Convenience aliases for the types a typical bot names directly, so the
/// core loop can be written against `@discord` alone. Everything else —
/// entity models, REST wrappers, gateway internals, option builders —
/// lives in the focused packages: `@discord/model`, `@discord/http`,
/// `@discord/gateway`, `@discord/interaction`, `@discord/framework`.
pub using @dhttp {type Client, type FileUpload}

///|
pub using @model {type Intents, type Event}

///|
pub using @gateway {type Shard, type ShardEvent}

///|
pub using @interaction {
  type CommandSpec,
  type CommandOptions,
  trait CommandModel,
}

///|
pub using @framework {
  type Framework,
  type CommandCtx,
  type ComponentCtx,
  type ModalCtx,
  type AutocompleteCtx,
}
