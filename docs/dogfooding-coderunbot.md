# coderunbot dogfooding で見つかったギャップ (2026-07-17)

coderunbot(Py-cord 製のコード実行ボット。Wandbox バックエンド、MathJax TeX レンダリング、
prefix コマンド + slash + モーダル + message context menu + コンポーネント)を discord.mbt で
書き直した際の発見事項。ファイル・行の参照は `5d31f1c7` 時点。移植は全機能完了
(native gateway bot、コード: gaato/coderunbot リポジトリの `mbt/`)。いずれも回避策あり。優先度順。
[dogfooding-nekosama.md](dogfooding-nekosama.md) と重複する項目は末尾にまとめた。

## 1. @util に escape_markdown / escape_mentions がない

**Resolved**: Pycord parity の `@util.escape_markdown()` / `escape_mentions()` を追加した。

`src/util/format.mbt` は mention/timestamp/CDN URL 系のみ。message context command「escape」
(メッセージ内容をエスケープして ephemeral 返信)のため、Pycord の
`discord.utils.escape_markdown` / `escape_mentions` 相当(URL スキップ、markdown リンク保全、
行頭 quote、`@everyone`/`@here`/スノーフレーク mention への U+200B 挿入)を自前実装した。

**修正案**: `@util` に追加。Pycord のセマンティクスとゴールデンケースは
coderunbot の `mbt/src/core/escaping.mbt` + テストが流用可能。

## 2. Embed にビルダー/コンストラクタがない

**Resolved**: 送信可能フィールドだけを受ける `Embed(...)` と
`EmbedAuthor` / `EmbedFooter` / `EmbedImage` / `EmbedThumbnail` / `EmbedField`
コンストラクタを追加した。

`@model.Embed` は 14 フィールドの `pub(all)` struct でデフォルト構築手段がなく、
生成のたびに全フィールドの列挙が必要。利用側で
`embed(title?, description?, color?, author_name?, image_url?, fields?)` ヘルパーを書いた
(coderunbot `mbt/src/core/embed.mbt`)。

**修正案**: `Embed::new(...?)` かビルダー。`EmbedAuthor` / `EmbedImage` / `EmbedField` も同様。

## 3. error policy から rich な応答が返せない

**Resolved**: `FailureCtx::respond_error()` が embeds / components / files 等を受け取り、
`user()` / `interaction()` / `raw()` も利用できる。

`FailureCtx::respond_error` はプレーンテキストのみで、interaction 本体(user、embeds、
components)にも触れないため、Python 版の「Unhandled Error embed + Delete ボタン」を
error policy 内で再現できない。想定内エラー(未対応言語、レンダリング失敗)はすべて
ハンドラ内で embed を返す設計に倒し、policy はテキスト + ログチャンネル通知のみにした。

**修正案**: `FailureCtx` の応答に `embeds?` / `components?` を追加するか、raw な
interaction ctx への脱出口を用意する。

## 4. MESSAGE_UPDATE に before がなく、非編集更新の識別も利用側任せ

**Resolved**: messages cache から `MessageUpdateEvent.before` を供給し、
`is_edit()` で timestamp 差分または fallback heuristic を判定する。

Pycord は message cache による before/after を提供するが、`Events::message_update()` には
before がない。編集追従(編集されたコマンドの再実行 + 旧返信の削除)のため、
message content を bounded map に自前記録した。さらに embed 展開(unfurl)やピン留めでも
MESSAGE_UPDATE が飛ぶため、追跡外メッセージは `edited_timestamp` が入っているときだけ
「編集」と見なすゲートが必要だった — これを怠るとコマンドが二重実行される
(coderunbot `mbt/src/features/prefix.mbt`)。nekosama メモ #4 の partial payload 懸念とも関連。

**修正案**: `@cache` 有効時に before を供給する仕組み、最低でも
「unfurl/ピン留めでも MESSAGE_UPDATE が来る、編集判定は edited_timestamp で」をガイドに明記。

## 5. autocomplete の 25 件制限をライブラリが clamp しない

**Resolved**: framework 最終送信と app の suggest dispatch で 25 件に clamp し、
app 経路では command path・option・元件数を `on_warn` へ通知する。

suggest コールバックから 25 件超を返すと Discord 側に拒否される(Wandbox の言語一覧は
25 を超える)。利用側で cap した。

**修正案**: 送信前にライブラリ側で 25 件に clamp(+ `on_warn` で通知)。

## nekosama メモとの重複(coderunbot でも該当を確認)

**Resolved**: modal は `text_field(value=...)` / `Modal::show(values=...)`、typing は
`ChannelRef::with_typing()`、ビルド前提は README / guide / template で解消した。

- **typed modal の value プリフィルなし**(nekosama #2): `/tex` の `\begin{env}` プリフィルで
  同じ回避(`handler=Raw` + `show_modal` + `text_input(value=...)` + `on_modal_raw`)。
- **typing keepalive なし**(nekosama #8): `trigger_typing` 一発で妥協(Wandbox は十分速い)。
- **zlib.h のビルド前提が未文書化**(nekosama #6): coderunbot の Dockerfile でも
  `zlib1g-dev` が必要だった。

## 環境メモ(ライブラリの問題ではない)

- openSUSE ホストでは `moon test --target native` に `LIBRARY_PATH=/usr/lib64` が必要だった
  (内蔵 tcc が libpthread/libc を見つけられない)。nekosama メモの `MOON_CC=gcc` でも通る。
- クリーンコンテナでの `moon update` は Mooncakes registry を git clone するため `git` が必要
  (coderunbot の Dockerfile で発覚)。
- `moonbitlang/async` の `@process`(`spawn` + `write_to_process` / `read_from_process`)で
  Node サイドカー(MathJax worker)の常駐運用が問題なく組めた。長寿命子プロセス +
  行指向 JSON プロトコル + タイムアウト + クラッシュ時再起動の実例は
  coderunbot `mbt/src/texrender/client.mbt`。
- 未公開パッケージへの submodule + `moon.work` 依存は coderunbot でも再実証
  (Docker ビルドは workspace ルートを COPY するだけで成立)。
