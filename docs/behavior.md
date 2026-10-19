# Discord REST の再送とレート制限: 公式の約束と gaato/discord の方針 (2026-10-19)

mbt-sdk の [design-m10](https://github.com/gaato/mbt-sdk/blob/main/docs/design-m10.md) の規則に従って調べた結果。

- 規則: A = サーバー側の文書(必ず従う)、B = 提供元の公式 SDK(A と矛盾しない範囲で合わせる)、C = コミュニティの慣習(参考)。
- Discord には公式 SDK がないため、B は無い。A は Discord 開発者ドキュメント、C は discord.js と discord.py。
- gaato/discord 側の参照は `main` = `76d668400ff8`(Release discord 0.11.0)の時点のもの。

## 出典

- **A**: Discord Developer Docs(2026-10-19 に閲覧。ページ単位の commit はない)
  - [Rate Limits](https://discord.com/developers/docs/topics/rate-limits)
  - [Opcodes and Status Codes](https://discord.com/developers/docs/topics/opcodes-and-status-codes)
  - [Create Message](https://discord.com/developers/docs/resources/message#create-message)
  - [API Reference](https://discord.com/developers/docs/reference)
- **C**: 次の 2 つを commit 固定で参照した。
  - [`discordjs/discord.js@03777df`](https://github.com/discordjs/discord.js/tree/03777df7f7cc372de88fd05cd3999ab59e5c36c0) の `packages/rest`
  - [`Rapptz/discord.py@65232c3`](https://github.com/Rapptz/discord.py/tree/65232c38702be5844cf2ce865a4777eb1928b5d0) の `discord/http.py`

## サーバー側の約束(A、原文)

- **固定値を書かない**: "rate limits should not be hard coded into your app. Instead, your app should parse response headers"
- **バケット**: "per-route limits will be shared across a set of similar endpoints, indicated in the `X-RateLimit-Bucket` header. It's recommended to use this header as a unique identifier for a rate limit"
- **429**: "Your application should rely on the `Retry-After` header or `retry_after` field to determine when to retry the request."
- **全体の上限**: "All bots can make up to 50 requests per second to our API."
- **不正リクエスト**:
  - "Currently, this limit is **10,000 per 10 minutes**. An invalid request is one that results in **401**, **403**, or **429** statuses."
  - "429 errors returned with `X-RateLimit-Scope: shared` are not counted against you."
  - 大規模なアプリは "should consider logging and tracking the rate of invalid requests"
- **5xx**:
  - "502 (GATEWAY UNAVAILABLE) | There was not a gateway available to process your request. Wait a bit and retry."
  - "5xx (SERVER ERROR) | The server had an error processing your request (these are rare)."
- **べき等性**:
  - "Clients should operate on events and results from the API in as much of an idempotent behavior as possible."
  - メッセージ作成の `enforce_nonce`: "If true and nonce is present, it will be checked for uniqueness in the past few minutes. If another message was created by the same author with the same nonce, that message will be returned and no new message will be created."

## コミュニティの慣習(C)

| 項目 | discord.js | discord.py |
|---|---|---|
| 5xx | 全メソッドで再送する(Shared.ts の `status >= 500 && status < 600`)。回数は `retries: 3`(constants.ts の `retries`) | 500/502/504/524 を全メソッドで再送する(http.py の `if response.status in {500, 502, 504, 524}`)。間隔は `1 + tries * 2` 秒 |
| 通信の失敗 | AbortError(時間切れを含む)と ECONNRESET を全メソッドで再送する(utils.ts の `shouldRetry`) | errno 54/10054 の OSError だけを再送する(http.py の `except OSError`) |
| 429 の待ち時間 | `Retry-After` ヘッダー × 1000 + `offset: 50` ms(SequentialHandler.ts) | 本文の `retry_after`(http.py の `retry_after: float = data['retry_after']`) |
| JSON のない 429 | 通常の 429 と同じに扱う | Cloudflare によるアクセス禁止とみなし、即座に例外を出す(http.py の "Banned by Cloudflare more than likely.") |
| 不正リクエストの計数 | 401/403/429 を数えて警告を出す(SequentialHandler.ts の `invalidRequestWarningInterval`) | なし |
| 既定の時間制限 | `timeout: 15_000` | 指定なし |

行番号は commit 固定のリンクで確認できる。

- discord.js
  - [constants.ts L24-L29](https://github.com/discordjs/discord.js/blob/03777df7f7cc372de88fd05cd3999ab59e5c36c0/packages/rest/src/lib/utils/constants.ts#L24-L29)
  - [Shared.ts L93](https://github.com/discordjs/discord.js/blob/03777df7f7cc372de88fd05cd3999ab59e5c36c0/packages/rest/src/lib/handlers/Shared.ts#L93)、[L159-L161](https://github.com/discordjs/discord.js/blob/03777df7f7cc372de88fd05cd3999ab59e5c36c0/packages/rest/src/lib/handlers/Shared.ts#L159-L161)
  - [utils.ts L142-L147](https://github.com/discordjs/discord.js/blob/03777df7f7cc372de88fd05cd3999ab59e5c36c0/packages/rest/src/lib/utils/utils.ts#L142-L147)
  - [SequentialHandler.ts L288-L301](https://github.com/discordjs/discord.js/blob/03777df7f7cc372de88fd05cd3999ab59e5c36c0/packages/rest/src/lib/handlers/SequentialHandler.ts#L288-L301)、[L342](https://github.com/discordjs/discord.js/blob/03777df7f7cc372de88fd05cd3999ab59e5c36c0/packages/rest/src/lib/handlers/SequentialHandler.ts#L342)
- discord.py
  - [http.py L649](https://github.com/Rapptz/discord.py/blob/65232c38702be5844cf2ce865a4777eb1928b5d0/discord/http.py#L649)
  - [L713-L716](https://github.com/Rapptz/discord.py/blob/65232c38702be5844cf2ce865a4777eb1928b5d0/discord/http.py#L713-L716)
  - [L732](https://github.com/Rapptz/discord.py/blob/65232c38702be5844cf2ce865a4777eb1928b5d0/discord/http.py#L732)
  - [L767-L770](https://github.com/Rapptz/discord.py/blob/65232c38702be5844cf2ce865a4777eb1928b5d0/discord/http.py#L767-L770)
  - [L784-L787](https://github.com/Rapptz/discord.py/blob/65232c38702be5844cf2ce865a4777eb1928b5d0/discord/http.py#L784-L787)

## gaato/discord の現状(`76d668400ff8`)

- **再送**(`DiscordRetry`、`discord/src/http/retry.mbt`):
  - 429 は全メソッドで再送する。待ち時間は本文の `retry_after` + 1 ms。
  - 送っていないと分かった通信の失敗(`is_unsent`)も再送する。
  - それ以外の `Status`(5xx を含む)は再送しない(`retry.mbt:59` の `_ => None`)。
  - 回数は `max_retries` で、既定 4。
- **時間制限**: 試行ごとに `request_timeout_ms`(既定 30000)。実装は `AttemptDeadline`。
- **レート制限**(`discord/src/ratelimit/ratelimit.mbt`):
  - `WindowLimiter` をルートの雛形と主要パラメーターでバケット分けする。`X-RateLimit-Bucket` は使っていない。
  - 全体の上限は 50/s。`x-ratelimit-global` が付いたら全体を止める。
  - 429 を受けると、scope に関係なくバケット全体を止める。
- **不正リクエストの計数**: なし。

## ずれと方針

| # | ずれ | 区分 | 方針 |
|---|---|---|---|
| 1 | 502 を再送しない | A(「Wait a bit and retry」) | 全メソッドで再送する |
| 2 | べき等なメソッドの 5xx を再送しない | C(両ライブラリとも再送する)。A に反しない | GET/PUT/DELETE などの 500–599 を再送する |
| 3 | べき等なメソッドで、接続後に起きた失敗(時間切れ・リセット)を再送しない | C | べき等なメソッドに限って再送する |
| 4 | POST(メッセージ作成など)の 5xx を再送しない | C は再送するが、重複投稿の危険がある。A が重複防止の手段として示すのは `nonce` + `enforce_nonce` | **今の慎重さを保つ**。ただし `nonce` と `enforce_nonce=true` が付いたメッセージ作成だけは、べき等なものとして再送する |
| 5 | JSON の本文がない 429 を `max_retries` まで再送する | A(401/403/429 は不正リクエストとして数えられ、上限を超えると IP 単位でアクセス禁止になる)、C(discord.py は即座に失敗させる) | 本文に JSON がなく `X-RateLimit-Scope` もない 429 は、再送せずに失敗させる |
| 6 | 401 を受けても止まらない | A(不正リクエストとして数えられる) | 401 で止める。呼び出し側にはそれと分かるエラーで知らせる |
| 7 | 不正リクエストを数えていない | A(「logging and tracking」を推奨) | observer で 401/403/429 を数える。scope が shared の 429 は数えない |
| 8 | バケットの区別がルートの雛形になっている | A(`X-RateLimit-Bucket` を一意の識別子として使う) | `WindowLimiter` の `alias` に、`x-ratelimit-bucket` と主要パラメーターを使う |
| 9 | scope が shared の 429 でもバケット全体を止める | A(shared は利用者に数えられない) | `scope` で `Shared` として扱い、解析した状態を記録するだけにする |
| 10 | 試行ごとの時間制限を自前で持っている(`AttemptDeadline`) | 設計上の重複 | sdk-runtime の `Timeouts` に置き換え、`AttemptDeadline` を削除する |

## 実装メモ(S6)

- **再送の判定**: `discord/src/http/retry.mbt` の `discord_retry_rule` が `gaato/http/retry` の `RetryRule` で、`resend_decision` が Discord 固有の入力(429 の待ち時間と、べき等かどうか)を足して `decide` を呼ぶ。
- **`nonce` の判定**: 再送判定の時点では本文が見えない(multipart の本文は送る直前に組み立てる)。そこで `wire_request` が、`CreateMessage` で本文に `nonce`(文字列か数値)と `enforce_nonce: true` があるときだけ、内部用のヘッダー `x-discord-mbt-replay-safe` を付ける。再送判定はこのヘッダーをべき等の印として読み、`ClosedGate` が transport に渡す前に取り除くので、Discord には届かない。呼び出し側が同じヘッダーを付けても、`wire_request` が先に消す。
- **Discord のレート制限の形をしていない 429**: 判定は `@ratelimit.is_discord_rate_limit` ひとつで、再送判定とリミッターの `scope` の両方が使う。`X-RateLimit-Scope`・`X-RateLimit-Global` のどちらもなく、`Content-Type` も JSON でない 429 は Discord のレート制限ではない。Cloudflare のような前段の何かが返したもので、待つべき時間を示さない。根拠は A の範囲で言える。Discord の 429 は JSON の本文と `X-RateLimit-Scope` を持つと文書にあり、401/403/429 は IP 単位の不正リクエストの上限(10 分で 1 万)に数えられる。だから再送せず、ほかのルートも止める。判定を本文ではなくヘッダーで行うのは、リミッターの `scope` がヘッダーしか受け取らず、両者を一致させるためである(0.12.0 では再送側だけ本文を見ていた。0.12.1 で揃えた)。discord.py(C)の "Banned by Cloudflare more than likely." は、この扱いの参考にしただけ。
- **時間制限**: `Timeouts` は利用者が渡した transport にだけ付ける。既定の `AsyncTransport` は自分で段階ごとに時間を測り、送る前の時間切れ(`Pool`/`Dial`)を区別できるので、外から同じ期限のタイマーを重ねると競合して `Unknown` になってしまう。
