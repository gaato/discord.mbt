# REST endpoint coverage

Typed `Route` / `Client` coverage of the Discord REST API, diffed against the
official OpenAPI spec ([discord/discord-api-spec], `main`, fetched 2026-07-16).

- Spec: **242** method:path pairs. At diff time **119** had typed routes and
  **119** did not (one of those, `PATCH /applications/@me`, has since landed;
  the remaining 118 are the unchecked items below).
- Every unwrapped endpoint is still reachable today through the escape hatch:
  `Route::custom` + `Client::request` (`src/http/route.mbt`).
- This file is the work list for closing the gap. Check items off as typed
  wrappers land; move deliberate non-goals to the "Out of scope" section with
  a reason.

[discord/discord-api-spec]: https://github.com/discord/discord-api-spec

## Regenerating the diff

```sh
curl -sL https://raw.githubusercontent.com/discord/discord-api-spec/main/specs/openapi.json |
  jq -r '.paths | to_entries[] | .key as $p | .value | keys[]
         | select(. != "parameters") | ascii_upcase + ":" + $p' |
  sed -E 's/\{[^}]*\}/*/g' | sort -u > /tmp/spec.txt
sed -n '/^pub fn Route::bucket/,/^pub fn Route::is_interaction/p' src/http/route.mbt |
  grep -oE '"(GET|POST|PATCH|PUT|DELETE):[^"]*"' | tr -d '"' |
  sed -E 's/\\\{[^}]*\}/*/g; s/\{\}/*/g' | sort -u > /tmp/impl.txt
comm -23 /tmp/spec.txt /tmp/impl.txt   # in spec, not implemented
```

The mechanical diff needs manual review afterwards:

- **Bucket collapsing hides detail.** Bucket strings fold minor IDs and `@me`
  suffixes together, so several spec pairs can map onto one bucket. This
  produces false positives (`PUT .../reactions/{emoji}/@me` looks missing but
  `Client::create_reaction` exists) and false negatives (`DELETE
  .../reactions/{emoji}` looked covered but had no route — it is listed below).
- **Pins moved.** The spec lists `/channels/{id}/messages/pins`; the library
  implements the equivalent legacy `/channels/{id}/pins` routes
  (`GET`/`PUT`/`DELETE`), so those three are covered, not missing.
- **The spec is a lower bound.** Discord's OpenAPI spec omits some documented
  endpoints (e.g. `GET /applications/{id}/skus`, List SKUs), so also compare
  against the developer docs when closing a category.

## Application

- [x] PATCH /applications/@me — Edit Current Application (`Client::edit_current_application`)
- [ ] GET /applications/{id} — Get Application
- [ ] PATCH /applications/{id} — Edit Application
- [ ] GET /applications/{id}/activity-instances/{instance_id} — Get Application Activity Instance
- [ ] POST /applications/{id}/attachment — Upload ephemeral application attachment

## Application emojis

- [ ] GET /applications/{id}/emojis — List Application Emojis
- [ ] GET /applications/{id}/emojis/{emoji_id} — Get Application Emoji
- [ ] POST /applications/{id}/emojis — Create Application Emoji
- [ ] PATCH /applications/{id}/emojis/{emoji_id} — Modify Application Emoji
- [ ] DELETE /applications/{id}/emojis/{emoji_id} — Delete Application Emoji

## Command permissions

- [ ] GET /applications/{id}/guilds/{guild}/commands/permissions — Get Guild Application Command Permissions
- [ ] GET /applications/{id}/guilds/{guild}/commands/{cmd}/permissions — Get Application Command Permissions
- [ ] PUT /applications/{id}/guilds/{guild}/commands/{cmd}/permissions — Edit Application Command Permissions

## Role connections

- [ ] GET /applications/{id}/role-connections/metadata — Get Role Connection Metadata Records
- [ ] PUT /applications/{id}/role-connections/metadata — Update Role Connection Metadata Records
- [ ] GET /users/@me/applications/{id}/role-connection — Get Current User Application Role Connection
- [ ] PUT /users/@me/applications/{id}/role-connection — Update Current User Application Role Connection
- [ ] DELETE /users/@me/applications/{id}/role-connection — Delete Current User Application Role Connection

## Monetization

List SKUs (`GET /applications/{id}/skus`) is documented but absent from the
OpenAPI spec; include it when doing this category.

- [ ] GET /applications/{id}/entitlements — List Entitlements
- [ ] GET /applications/{id}/entitlements/{entitlement_id} — Get Entitlement
- [ ] POST /applications/{id}/entitlements — Create Test Entitlement
- [ ] POST /applications/{id}/entitlements/{entitlement_id}/consume — Consume Entitlement
- [ ] DELETE /applications/{id}/entitlements/{entitlement_id} — Delete Test Entitlement
- [ ] GET /users/@me/applications/{id}/entitlements — List user entitlements
- [ ] GET /skus/{sku_id}/subscriptions — List SKU Subscriptions
- [ ] GET /skus/{sku_id}/subscriptions/{subscription_id} — Get SKU Subscription

## Channels & messages

- [ ] DELETE /channels/{id}/messages/{msg}/reactions/{emoji} — Delete All Reactions for Emoji (hidden by bucket collapsing; see notes above)
- [ ] POST /channels/{id}/messages/{msg}/crosspost — Crosspost Message
- [ ] POST /channels/{id}/followers — Follow Announcement Channel
- [ ] PUT /channels/{id}/voice-status — Set Voice Channel Status
- [ ] PUT /channels/{id}/recipients/{user} — Group DM Add Recipient
- [ ] DELETE /channels/{id}/recipients/{user} — Group DM Remove Recipient
- [ ] GET /guilds/{id}/messages/search — Search Guild Messages (limited availability)

## Threads

- [ ] GET /channels/{id}/thread-members — List Thread Members
- [ ] GET /channels/{id}/thread-members/{user} — Get Thread Member
- [ ] PUT /channels/{id}/thread-members/{user} — Add Thread Member
- [ ] DELETE /channels/{id}/thread-members/{user} — Remove Thread Member
- [ ] GET /channels/{id}/threads/archived/public — List Public Archived Threads
- [ ] GET /channels/{id}/threads/archived/private — List Private Archived Threads
- [ ] GET /channels/{id}/users/@me/threads/archived/private — List Joined Private Archived Threads
- [ ] GET /channels/{id}/threads/search — Search Threads (limited availability)
- [ ] GET /guilds/{id}/threads/active — List Active Guild Threads

## Guild management

- [ ] GET /guilds/{id}/preview — Get Guild Preview
- [ ] GET /guilds/{id}/bans/{user} — Get Guild Ban
- [ ] POST /guilds/{id}/bulk-ban — Bulk Guild Ban
- [ ] GET /guilds/{id}/prune — Get Guild Prune Count
- [ ] POST /guilds/{id}/prune — Begin Guild Prune
- [ ] GET /guilds/{id}/regions — Get Guild Voice Regions
- [ ] GET /guilds/{id}/invites — Get Guild Invites
- [ ] GET /guilds/{id}/integrations — Get Guild Integrations
- [ ] DELETE /guilds/{id}/integrations/{integration} — Delete Guild Integration
- [ ] GET /guilds/{id}/vanity-url — Get Guild Vanity URL
- [ ] GET /guilds/{id}/widget — Get Guild Widget Settings
- [ ] PATCH /guilds/{id}/widget — Modify Guild Widget
- [ ] GET /guilds/{id}/widget.json — Get Guild Widget
- [ ] GET /guilds/{id}/widget.png — Get Guild Widget Image
- [ ] GET /guilds/{id}/welcome-screen — Get Guild Welcome Screen
- [ ] PATCH /guilds/{id}/welcome-screen — Modify Guild Welcome Screen
- [ ] GET /guilds/{id}/onboarding — Get Guild Onboarding
- [ ] PUT /guilds/{id}/onboarding — Modify Guild Onboarding
- [ ] PUT /guilds/{id}/incident-actions — Modify Guild Incident Actions
- [ ] GET /guilds/{id}/roles/{role} — Get Guild Role
- [ ] GET /guilds/{id}/roles/member-counts — Get role member counts
- [ ] PATCH /guilds/{id}/roles — Modify Guild Role Positions
- [ ] PUT /guilds/{id}/members/{user} — Add Guild Member (OAuth2 `guilds.join`)
- [ ] GET /guilds/{id}/requests — List guild join requests
- [ ] PATCH /guilds/{id}/requests/{user} — Act on a guild join request
- [ ] GET /guilds/{id}/new-member-welcome — Get new member welcome (not in public docs)

## Voice

- [ ] GET /voice/regions — List Voice Regions
- [ ] GET /guilds/{id}/voice-states/@me — Get Current User Voice State
- [ ] GET /guilds/{id}/voice-states/{user} — Get User Voice State
- [ ] PATCH /guilds/{id}/voice-states/@me — Modify Current User Voice State
- [ ] PATCH /guilds/{id}/voice-states/{user} — Modify User Voice State

## Guild scheduled events

- [ ] GET /guilds/{id}/scheduled-events/{event}/users/counts — Get event user counts
- [ ] GET /guilds/{id}/scheduled-events/{event}/{exception}/users — Get exception users
- [ ] POST /guilds/{id}/scheduled-events/{event}/exceptions — Create event exception
- [ ] PATCH /guilds/{id}/scheduled-events/{event}/exceptions/{exception} — Modify event exception
- [ ] DELETE /guilds/{id}/scheduled-events/{event}/exceptions/{exception} — Delete event exception

## Guild templates

- [ ] GET /guilds/templates/{code} — Get Guild Template
- [ ] GET /guilds/{id}/templates — Get Guild Templates
- [ ] POST /guilds/{id}/templates — Create Guild Template
- [ ] PUT /guilds/{id}/templates/{code} — Sync Guild Template
- [ ] PATCH /guilds/{id}/templates/{code} — Modify Guild Template
- [ ] DELETE /guilds/{id}/templates/{code} — Delete Guild Template

## Webhooks (token-authenticated)

- [ ] GET /webhooks/{id}/{token} — Get Webhook with Token
- [ ] PATCH /webhooks/{id}/{token} — Modify Webhook with Token
- [ ] DELETE /webhooks/{id}/{token} — Delete Webhook with Token
- [ ] POST /webhooks/{id}/{token}/github — Execute GitHub-Compatible Webhook
- [ ] POST /webhooks/{id}/{token}/slack — Execute Slack-Compatible Webhook

## Invites

- [ ] GET /invites/{code}/target-users — List invite target users
- [ ] PUT /invites/{code}/target-users — Set invite target users
- [ ] GET /invites/{code}/target-users/job-status — Get invite target users job status

## Users & OAuth2

- [ ] GET /users/@me/connections — Get Current User Connections
- [ ] GET /users/@me/guilds/{id}/member — Get Current User Guild Member
- [ ] DELETE /users/@me/guilds/{id} — Leave Guild
- [ ] GET /oauth2/@me — Get Current Authorization Information
- [ ] GET /oauth2/applications/@me — Get Current Bot Application Information
- [ ] GET /oauth2/keys — Get OAuth2 signing keys
- [ ] GET /oauth2/userinfo — OAuth2 userinfo

## Out of scope (proposed): Discord Social SDK

Lobbies and the Partner SDK back the Discord Social SDK for games; they are
not useful to a bot library. Proposed as deliberate non-goals — `Route::custom`
remains available if someone needs them.

- POST /lobbies · PUT /lobbies · GET/PATCH/DELETE /lobbies/{id}
- PATCH /lobbies/{id}/channel-linking
- PUT/DELETE /lobbies/{id}/members/{user} · DELETE /lobbies/{id}/members/@me
- POST /lobbies/{id}/members/bulk
- POST /lobbies/{id}/members/@me/invites · POST /lobbies/{id}/members/{user}/invites
- GET/POST /lobbies/{id}/messages
- PUT /lobbies/{id}/messages/{msg}/moderation-metadata
- POST /partner-sdk/token · POST /partner-sdk/token/bot
- POST /partner-sdk/provisional-accounts/unmerge · POST /partner-sdk/provisional-accounts/unmerge/bot
- PUT /partner-sdk/dms/{a}/{b}/messages/{msg}/moderation-metadata
