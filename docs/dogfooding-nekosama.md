# nekosama dogfooding で見つかったギャップ (2026-07-17)

nekosama(Py-cord 製の翻訳+ChatGPT ボット、348行)を discord.mbt で書き直した際の発見事項。
ファイル・行の参照は `5d31f1c7`(Color the package graph by JS support)時点。
移植自体は全機能完了しており、いずれも回避策あり。優先度順。

## 1. コマンド説明の localization が typed builder から設定できない

`@model.ApplicationCommand` は `name_localizations` / `description_localizations` を持つが、
`CommandSpec`(`src/interaction/spec.mbt:5`)と `slash` / `slash_group` / `subcommand` builder
(`src/app/command.mbt`)に対応フィールドがなく、登録 JSON にも载らない。
nekosama の `/role list` などにあった日本語 `description_localizations` を移植できず、当面 EN のみにした。

**修正案**: `CommandSpec` + builder に `name_localizations?` / `description_localizations?` を追加し、
登録時の `ToJson` に反映。オプション(`Arg`)側も同様。

## 2. typed modal に実行時の value プリフィルがない

`text_field`(`src/app/modal.mbt:84`)は `value` を受けず、`Modal::show`(state は custom_id 末尾に
載せられるが)フィールド値の差し替え手段がない。低レベルの `@interaction.text_input(value?=...)`
(`src/interaction/builders.mbt:498-518`)は対応済みなので、App 層だけの欠落。

nekosama の「翻訳 Edit」(現訳文をプリフィルしたモーダル)は Raw コンポーネントハンドラで
`text_input(value=...)` を手組みし、custom_id prefix を合わせて typed `on_modal` で受ける形で回避。

**修正案**: `text_field(value?)` + `Modal::show(values~ : Map[String, String])` のような
呼び出し時オーバーライド。

## 3. interaction ctx から gateway latency を取得できない

`Shard::latency_ms()`(`src/gateway/shard.mbt:34`)は `GatewayCtx::shard_raw()` からしか届かず、
`ImmediateCtx` 等のコマンド ctx に露出していない。`/ping` のために `Events::ready` ハンドラで
`GatewayCtx` をモジュールの `Ref` に保存して読む回避策が必要だった。

**修正案**: gateway 実行時は `AppCtx`(または各 interaction ctx)に `latency_ms()` を生やす。

## 4. MessageUpdateEvent が完全な Message を前提にしている

`MessageUpdateEvent.message`(`src/model/message_event.mbt`)は完全な `Message` としてデコードするが、
Discord の `MESSAGE_UPDATE` は部分 payload になり得る(embed 展開時など)。デコードが strict だと
実機で落ちる可能性がある。**未実証**(nekosama の実機検証時に要確認)。落ちる場合は
partial message 型か `Unknown` 相当の許容が必要。

## 5. 2000文字分割ヘルパーがない

Discord の content 上限(2000 コードポイント)向けの分割・分割送信ヘルパーがなく、
MoonBit 文字列が UTF-16 コード単位なこともあり利用側で書くと事故りやすい。
nekosama では codepoint 安全な chunker を自前実装した。

**修正案**: `@discord` にユーティリティとして提供(サロゲートペア境界を割らない保証付き)。

## 6. zlib.h のビルド前提が未文書化

native gateway の `zlib-stream` 圧縮(`src/gateway/zlib_stream.c`)がビルド時に `zlib.h` を要求するが、
README / template / CI に zlib 開発パッケージ(`zlib1g-dev` 等)の前提が明記されていない。
クリーンな Docker(debian bookworm-slim)でのビルドで発覚。

## 7. Raw ハンドラで message context command の resolved 対象が取れない

Raw コマンドハンドラに切り替えると、context menu の対象メッセージが型付きで渡らず、
`target_id` と `resolved.messages` を手動でデコードする必要があった。

**修正案**: Raw ctx にも resolved エンティティへの型付きアクセサを用意。

## 8. typing の keepalive がない

`ChannelRef::typing()` は一回限り(約10秒)で、長い LLM 呼び出しの間 typing を維持する
スコープ付きヘルパーがない。

**修正案**: `channel_ref.with_typing(async fn() -> T)` のような、完了まで定期再送するラッパー。

## 9. MessageCreateEvent.channel_type が通常欠落し、スレッド判定が面倒

`channel_type` が None の場合、スレッド判定のたびに cache 参照または `ChannelRef::fetch()` への
フォールバックを利用側で書く必要がある。cache-aware なチャンネル解決ヘルパー
(cache hit → REST fallback を一発でやる)があると使い勝手が良い。

---

## 環境メモ(ライブラリの問題ではない)

- openSUSE では `moon test` の内蔵 tcc が `libpthread` / `libc` を見つけられず、
  `MOON_CC=/usr/bin/gcc moon test` が必要。
- クリーンコンテナでは引数なし `moon install` が deprecated かつ registry を初期化しないため、
  `moon update` を先に実行する必要があった(nekosama の Dockerfile で対応済み)。
- 未公開パッケージ(`gaato/discord@0.1.0`)への依存は、利用側リポジトリに submodule +
  `moon.work` の workspace メンバーで問題なく解決できた(nekosama で実証)。
