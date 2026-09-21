# nekosama dogfooding で見つかったギャップ (2026-07-17)

nekosama(Py-cord 製の翻訳+ChatGPT ボット、348行)を discord.mbt で書き直した際の発見事項。
ファイル・行の参照は `5d31f1c7`(Color the package graph by JS support)時点。
移植自体は全機能完了しており、いずれも回避策あり。優先度順。

## 1. コマンド説明の localization が typed builder から設定できない

**Resolved**: `slash` / subcommand / option / choice builder の
`name_localizations`・`description_localizations` で登録 JSON まで貫通する。

`@model.ApplicationCommand` は `name_localizations` / `description_localizations` を持つが、
`CommandSpec`(`src/interaction/spec.mbt:5`)と `slash` / `slash_group` / `subcommand` builder
(`src/app/command.mbt`)に対応フィールドがなく、登録 JSON にも载らない。
nekosama の `/role list` などにあった日本語 `description_localizations` を移植できず、当面 EN のみにした。

**修正案**: `CommandSpec` + builder に `name_localizations?` / `description_localizations?` を追加し、
登録時の `ToJson` に反映。オプション(`Arg`)側も同様。

## 2. typed modal に実行時の value プリフィルがない

**Resolved**: `text_field(value=...)` と `Modal::show(values=...)` を追加し、
不正なキーは `ModalPrefillError` で報告する。

`text_field`(`src/app/modal.mbt:84`)は `value` を受けず、`Modal::show`(state は custom_id 末尾に
載せられるが)フィールド値の差し替え手段がない。低レベルの `@interaction.text_input(value?=...)`
(`src/interaction/builders.mbt:498-518`)は対応済みなので、App 層だけの欠落。

nekosama の「翻訳 Edit」(現訳文をプリフィルしたモーダル)は Raw コンポーネントハンドラで
`text_input(value=...)` を手組みし、custom_id prefix を合わせて typed `on_modal` で受ける形で回避。

**修正案**: `text_field(value?)` + `Modal::show(values~ : Map[String, String])` のような
呼び出し時オーバーライド。

## 3. interaction ctx から gateway latency を取得できない

**Resolved**: interaction では `AppCtx::latency_ms()`、Gateway handler では
shard 固有の `GatewayCtx::latency_ms()` を利用できる。

`Shard::latency_ms()`(`src/gateway/shard.mbt:34`)は `GatewayCtx::shard_raw()` からしか届かず、
`ImmediateCtx` 等のコマンド ctx に露出していない。`/ping` のために `Events::ready` ハンドラで
`GatewayCtx` をモジュールの `Ref` に保存して読む回避策が必要だった。

**修正案**: gateway 実行時は `AppCtx`(または各 interaction ctx)に `latency_ms()` を生やす。

## 4. MessageUpdateEvent が完全な Message を前提にしている

**Resolved**: 公式仕様に合わせて strict な full `Message` を維持し、
編集識別用に `MessageUpdateEvent::before` / `is_edit()` を追加した。
live probe(`src/examples/update_probe`、2026-07-17)で unfurl・編集・ピンの
MESSAGE_UPDATE がいずれも full payload で decode エラーなしと実証済み。
なお実機では編集 dispatch の `edited_timestamp` がマイクロ秒精度、後続の
pin/unfurl 更新ではミリ秒精度で echo されるため、`is_edit()` はミリ秒精度で
インスタント比較する。

`MessageUpdateEvent.message`(`src/model/message_event.mbt`)は完全な `Message` としてデコードするが、
Discord の `MESSAGE_UPDATE` は部分 payload になり得る(embed 展開時など)。デコードが strict だと
実機で落ちる可能性がある。**未実証**(nekosama の実機検証時に要確認)。落ちる場合は
partial message 型か `Unknown` 相当の許容が必要。

## 5. 2000文字分割ヘルパーがない

**Resolved**: UTF-16・サロゲートペア・CRLF 境界を扱う
`@util.split_content()` を追加した。

Discord の content 上限(2000 コードポイント)向けの分割・分割送信ヘルパーがなく、
MoonBit 文字列が UTF-16 コード単位なこともあり利用側で書くと事故りやすい。
nekosama では codepoint 安全な chunker を自前実装した。

**修正案**: `@discord` にユーティリティとして提供(サロゲートペア境界を割らない保証付き)。

## 6. zlib.h のビルド前提が未文書化

**Resolved**: README・getting-started guide・template に、全 native build で必要な
zlib 開発ヘッダと `moon update` / `git` の前提を追記した。

native gateway の `zlib-stream` 圧縮(`src/gateway/zlib_stream.c`)がビルド時に `zlib.h` を要求するが、
README / template / CI に zlib 開発パッケージ(`zlib1g-dev` 等)の前提が明記されていない。
クリーンな Docker(debian bookworm-slim)でのビルドで発覚。

## 7. Raw ハンドラで message context command の resolved 対象が取れない

**Resolved**: `CommandCtx::target_message()` / `target_user()` を framework 層に追加した。

Raw コマンドハンドラに切り替えると、context menu の対象メッセージが型付きで渡らず、
`target_id` と `resolved.messages` を手動でデコードする必要があった。

**修正案**: Raw ctx にも resolved エンティティへの型付きアクセサを用意。

## 8. typing の keepalive がない

**Resolved**: `ChannelRef::with_typing()` が即時送信と 8 秒間隔の keepalive を
structured concurrency で管理する。

`ChannelRef::typing()` は一回限り(約10秒)で、長い LLM 呼び出しの間 typing を維持する
スコープ付きヘルパーがない。

**修正案**: `channel_ref.with_typing(async fn() -> T)` のような、完了まで定期再送するラッパー。

## 9. MessageCreateEvent.channel_type が通常欠落し、スレッド判定が面倒

**Resolved**: `GatewayCtx::cache()` と cache-first + REST fallback の
`GatewayCtx::resolve_channel()` を追加した。

`channel_type` が None の場合、スレッド判定のたびに cache 参照または `ChannelRef::fetch()` への
フォールバックを利用側で書く必要がある。cache-aware なチャンネル解決ヘルパー
(cache hit → REST fallback を一発でやる)があると使い勝手が良い。

## 第2ラウンド (2026-07-17)

第2ラウンドは、移植完了後に nekosama と coderunbot の両方から出た使い勝手の
フィードバックをまとめた。低レベル層(interaction builders / http / gateway)の完成度は高く、
遅れていた App 層の使い勝手も第1ラウンドでほぼ追いついた。coderunbot では回避策を外した結果、
正味で145行減り、escaping と embed の自前実装ファイルを丸ごと削除できた。

### 1. `Nullable[T]?` の読み出しが冗長

optional nullable field を読むたびに `member.nick.bind(n => n.to_option())` と書く必要があり、
値だけ欲しい箇所でも欠落と JSON `null` の二段階を手で畳んでいた。

**Resolved**: `@model.flatten()` を追加し、guide 12 に読み出しイディオムを記載した。
これは欠落と `null` を区別しない lossy view なので、PATCH body や cache merge には使わない。

### 2. fire-and-forget の response 呼び出しにも `|> ignore` が必要

戻り値を使わない `followup` などでも、呼び出し側が毎回 `|> ignore` を付ける必要がある。

**Resolved (wontfix)**: `Message` の戻り値は followup id を得る唯一の経路であり、後から
`edit_followup` / `delete_followup` するために必要なので維持する。Unit 版の併設は同じ操作の
二通り目となり、API の採否基準に抵触する。`|> ignore` を公式イディオムとして guide 02 / 11 に
明記した。

### 3. `guild_only()` の保証が handler の型に伝わらない

`guild_only()` を付けたコマンドでも `guild_id` と member を個別に guard する必要があり、
guild command ごとに同じボイラープレートが残っていた。

**Resolved**: breaking change として `InvocationScope::Guild` が `GuildInvocation`
(`guild_id` + `member`、`user()` 便宜メソッド付き)を運ぶようにした。全8個の app ctx と
`CheckCtx`、framework の3 ctx に `guild_scope()` を追加した。framework 版は Option を返し、
app 版は DM で `HandlerError::GuildOnly` を raise するため、既存の error policy がそのまま
応答を描画する。`required_permissions` も内部でこの bundle を使う。member があるのに
guild_id がない壊れた payload は、新設した `InteractionContextError::MissingGuildId` で拒否する。

## 第3ラウンド (2026-09-21、0.3.1 追従)

### 1. prebuild hook の Node.js 前提が voice guide にしか書かれていない

`gaato/discord` と依存の `gaato/dave` は `--moonbit-unstable-prebuild` で `build.js` を宣言して
おり、voice の opt-in 変数がなければ何もダウンロードせず終了するが、Moon は hook の実行自体に
`node` を要求する。音声を使わない bot でも、`node` のないクリーンな Docker builder では
`moon build` が `needs node executable in PATH` で失敗した(`moon check` は hook を走らせないので通る)。
Moon の prebuild は `.js`(node)か `.py`(python)しか選べず、`gaato/dave` 側にも同じ hook が
あるため、前提そのものは外せない。

**Resolved**: 第1ラウンド #6(zlib)と同じ 3 箇所 — README・getting-started guide・template — の
前提条件に Node.js を追記した。

### 2. modal の text input 制限がローカルで検出されない

Edit モーダルで `text_field(max_length=4096)`(embed description の上限)を指定していたため、
Discord が毎回 50035 Invalid Form Body を返していた。text input の上限は 4000。
`Modal::show(values=...)` の prefill 値が 4000 を超える場合も同じく 400 になるまで気づけない。
custom id の 100 文字制限は 0.3.0 で検証済みなのに、同型の制限が素通りだった。

**Resolved**: 同型の問題(文書化された値制約の未検証)を全件に広げて解いた。`@model` に
`LimitViolation` と `modal_limit_violations` / `message_component_limit_violations` /
`embed_limit_violations` を置き、メッセージ系の全送信経路と `show_modal` が送信前に
`DiscordHttpError::Validation` で拒否する。typed modal は `App::validate` が起動時に
`ModalOutsideLimits` で検出し、動的な prefill は `Modal::show` が
`ModalPrefillError::ValueTooLong` で拒否する。制限値は公式ドキュメントに書かれたものだけを採る。

### 3. 型付き route の id に `:` を含められない

既に投稿済みメッセージに付いている custom id(`nekosama:rolemenu` など)は変えられないが、
`App::validate` が `:` を含む route id を `InvalidRouteId` で拒否するため、型付き
`ComponentRoute` に移せず `on_component_raw` に逃げる必要があった。

**Resolved**: `:` 禁止は「ある型付き route の state が別の型付き route に届かない」という
不変条件の代理だった。代理をやめて不変条件そのもの — 2 つの型付き id が `:` 境界で入れ子に
ならないこと(`ticket` と `ticket:close`)— を検査する。従来通っていた構成はすべて通る。
`App::validate` の他の規則は Discord の規則か往復可能性そのもので、代理ルールはこれだけだった。

### 4. ギルドメンバーのアバター URL ヘルパーがない

`GuildMember::avatar` はモデルにあるのに、`guilds/{guild}/users/{user}/avatars/{hash}` を組む
builder が `@util` になかった。

**Resolved**: 公式 CDN endpoint 表と突き合わせ、モデルが hash を持つ全 route に builder を
揃えた(12 個追加)。クライアントと同じ優先順位(メンバー → ユーザー → デフォルト)で解決する
`display_avatar_url` も追加。表との乖離は `scripts/docs_cdn_audit.py` が検出する
(意図的に除外した 3 行は `docs_cdn_audit.allow` に理由付きで記載)。

### 5. `@fs.mkdir(recursive=true)` が既存ディレクトリで失敗する(moonbitlang/async)

discord.mbt の問題ではない。上流に修正 PR (#628) を出した。内容は下の「上流 (moonbitlang/async)」を参照。

## 上流 (moonbitlang/async)

### `@fs.mkdir(recursive=true)` が既存ディレクトリと並行呼び出しで失敗する

確認: async `b1ad24d`(2026-09-21 の origin/HEAD、`src/fs/dir.mbt` の `mkdir` は 0.22 系と同一)。
既存の issue / PR はなかった(recursive を入れた #231 のみ)。
**Reported**: [moonbitlang/async#628](https://github.com/moonbitlang/async/pull/628)(修正 PR、2026-09-21)。

`mkdir` は最初の `mkdir(2)` が ENOENT のときだけ親を再帰的に作り、それ以外のエラーはそのまま
raise する。このため:

1. 既存ディレクトリに対する `mkdir(path, recursive=true)` が `File exists` で失敗する。
   `mkdir -p`、Rust `create_dir_all`、Go `MkdirAll`、Python `makedirs(exist_ok=True)`、
   Node `mkdir({recursive: true})` はいずれも成功する。
2. 一般化すると競合バグになる: 共有の親を持つ複数タスクが同時に呼ぶと、親の作成で負けた側が
   EEXIST で失敗する。4 タスクで `_build/repro_race/shared/parent/{i}` を作ると 3 つが
   `"_build/repro_race": File exists` などで失敗した(`with_task_group` + `spawn_bg` で再現)。
   呼び出し側で事前に存在確認しても TOCTOU で防げない。

PR の内容: `recursive=true` では、`mkdir(2)` の EEXIST を「対象がディレクトリなら成功」として扱う
(親の再帰作成と最後の作成の両方)。ファイルが存在する場合は従来どおり EEXIST。

---

## 環境メモ(ライブラリの問題ではない)

- openSUSE では `moon test` の内蔵 tcc が `libpthread` / `libc` を見つけられず、
  `MOON_CC=/usr/bin/gcc moon test` が必要。
- クリーンコンテナでは引数なし `moon install` が deprecated かつ registry を初期化しないため、
  `moon update` を先に実行する必要があった(nekosama の Dockerfile で対応済み)。
- 未公開パッケージ(`gaato/discord@0.1.0`)への依存は、利用側リポジトリに submodule +
  `moon.work` の workspace メンバーで問題なく解決できた(nekosama で実証)。
