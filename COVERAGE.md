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
- [x] GET /applications/{id}/activity-instances/{instance_id} — Get Application Activity Instance (`Client::get_application_activity_instance`)

## Application emojis

- [x] GET /applications/{id}/emojis — List Application Emojis (`Client::list_application_emojis`)
- [x] GET /applications/{id}/emojis/{emoji_id} — Get Application Emoji (`Client::get_application_emoji`)
- [x] POST /applications/{id}/emojis — Create Application Emoji (`Client::create_application_emoji`)
- [x] PATCH /applications/{id}/emojis/{emoji_id} — Modify Application Emoji (`Client::modify_application_emoji`)
- [x] DELETE /applications/{id}/emojis/{emoji_id} — Delete Application Emoji (`Client::delete_application_emoji`)

## Command permissions

- [x] GET /applications/{id}/guilds/{guild}/commands/permissions — Get Guild Application Command Permissions (`Client::get_guild_application_command_permissions`)
- [x] GET /applications/{id}/guilds/{guild}/commands/{cmd}/permissions — Get Application Command Permissions (`Client::get_application_command_permissions`)
- [x] PUT /applications/{id}/guilds/{guild}/commands/{cmd}/permissions — Edit Application Command Permissions (`Client::edit_application_command_permissions`)

## Role connections

- [x] GET /applications/{id}/role-connections/metadata — Get Role Connection Metadata Records (`Client::get_application_role_connection_metadata_records`)
- [x] PUT /applications/{id}/role-connections/metadata — Update Role Connection Metadata Records (`Client::update_application_role_connection_metadata_records`)
- [x] GET /users/@me/applications/{id}/role-connection — Get Current User Application Role Connection (`Client::get_current_user_application_role_connection`)
- [x] PUT /users/@me/applications/{id}/role-connection — Update Current User Application Role Connection (`Client::update_current_user_application_role_connection`)
- [x] DELETE /users/@me/applications/{id}/role-connection — Delete Current User Application Role Connection (`Client::delete_current_user_application_role_connection`)

## Monetization

- [x] GET /applications/{id}/entitlements — List Entitlements (`Client::list_entitlements`)
- [x] GET /applications/{id}/entitlements/{entitlement_id} — Get Entitlement (`Client::get_entitlement`)
- [x] POST /applications/{id}/entitlements — Create Test Entitlement (`Client::create_test_entitlement`)
- [x] POST /applications/{id}/entitlements/{entitlement_id}/consume — Consume Entitlement (`Client::consume_entitlement`)
- [x] DELETE /applications/{id}/entitlements/{entitlement_id} — Delete Test Entitlement (`Client::delete_test_entitlement`)
- [x] GET /applications/{id}/skus — List SKUs (`Client::list_skus`) (documented but absent from the OpenAPI spec)
- [x] GET /skus/{sku_id}/subscriptions — List SKU Subscriptions (`Client::list_sku_subscriptions`)
- [x] GET /skus/{sku_id}/subscriptions/{subscription_id} — Get SKU Subscription (`Client::get_sku_subscription`)

## Channels & messages

- [x] DELETE /channels/{id}/messages/{msg}/reactions/{emoji} — Delete All Reactions for Emoji (`Client::delete_all_reactions_for_emoji`)
- [x] POST /channels/{id}/messages/{msg}/crosspost — Crosspost Message (`Client::crosspost_message`)
- [x] POST /channels/{id}/followers — Follow Announcement Channel (`Client::follow_announcement_channel`)
- [x] PUT /channels/{id}/voice-status — Set Voice Channel Status (`Client::set_voice_channel_status`)
- [x] PUT /channels/{id}/recipients/{user} — Group DM Add Recipient (`Client::group_dm_add_recipient`)
- [x] DELETE /channels/{id}/recipients/{user} — Group DM Remove Recipient (`Client::group_dm_remove_recipient`)
- [x] GET /guilds/{id}/messages/search — Search Guild Messages (`Client::search_guild_messages`)

## Threads

- [x] GET /channels/{id}/thread-members — List Thread Members (`Client::list_thread_members`)
- [x] GET /channels/{id}/thread-members/{user} — Get Thread Member (`Client::get_thread_member`)
- [x] PUT /channels/{id}/thread-members/{user} — Add Thread Member (`Client::add_thread_member`)
- [x] DELETE /channels/{id}/thread-members/{user} — Remove Thread Member (`Client::remove_thread_member`)
- [x] GET /channels/{id}/threads/archived/public — List Public Archived Threads (`Client::list_public_archived_threads`)
- [x] GET /channels/{id}/threads/archived/private — List Private Archived Threads (`Client::list_private_archived_threads`)
- [x] GET /channels/{id}/users/@me/threads/archived/private — List Joined Private Archived Threads (`Client::list_joined_private_archived_threads`)
- [x] GET /guilds/{id}/threads/active — List Active Guild Threads (`Client::list_active_guild_threads`)

## Guild management

- [x] GET /guilds/{id}/preview — Get Guild Preview (`Client::get_guild_preview`)
- [x] GET /guilds/{id}/bans/{user} — Get Guild Ban (`Client::get_guild_ban`)
- [x] POST /guilds/{id}/bulk-ban — Bulk Guild Ban (`Client::bulk_guild_ban`)
- [x] GET /guilds/{id}/prune — Get Guild Prune Count (`Client::get_guild_prune_count`)
- [x] POST /guilds/{id}/prune — Begin Guild Prune (`Client::begin_guild_prune`)
- [x] GET /guilds/{id}/regions — Get Guild Voice Regions (`Client::get_guild_voice_regions`)
- [x] GET /guilds/{id}/invites — Get Guild Invites (`Client::get_guild_invites`)
- [x] GET /guilds/{id}/integrations — Get Guild Integrations (`Client::get_guild_integrations`)
- [x] DELETE /guilds/{id}/integrations/{integration} — Delete Guild Integration (`Client::delete_guild_integration`)
- [x] GET /guilds/{id}/vanity-url — Get Guild Vanity URL (`Client::get_guild_vanity_url`)
- [x] GET /guilds/{id}/widget — Get Guild Widget Settings (`Client::get_guild_widget_settings`)
- [x] PATCH /guilds/{id}/widget — Modify Guild Widget (`Client::modify_guild_widget`)
- [x] GET /guilds/{id}/widget.json — Get Guild Widget (`Client::get_guild_widget`)
- [x] GET /guilds/{id}/widget.png — Get Guild Widget Image (covered by `Client::guild_widget_image_url`; binary endpoint, no JSON route)
- [x] GET /guilds/{id}/welcome-screen — Get Guild Welcome Screen (`Client::get_guild_welcome_screen`)
- [x] PATCH /guilds/{id}/welcome-screen — Modify Guild Welcome Screen (`Client::modify_guild_welcome_screen`)
- [x] GET /guilds/{id}/onboarding — Get Guild Onboarding (`Client::get_guild_onboarding`)
- [x] PUT /guilds/{id}/onboarding — Modify Guild Onboarding (`Client::modify_guild_onboarding`)
- [x] PUT /guilds/{id}/incident-actions — Modify Guild Incident Actions (`Client::modify_guild_incident_actions`)
- [x] GET /guilds/{id}/roles/{role} — Get Guild Role (`Client::get_guild_role`)
- [x] PATCH /guilds/{id}/roles — Modify Guild Role Positions (`Client::modify_guild_role_positions`)
- [x] PUT /guilds/{id}/members/{user} — Add Guild Member (`Client::add_guild_member`; OAuth2 `guilds.join`)

## Voice

- [x] GET /voice/regions — List Voice Regions (`Client::list_voice_regions`)
- [x] GET /guilds/{id}/voice-states/@me — Get Current User Voice State (`Client::get_current_user_voice_state`)
- [x] GET /guilds/{id}/voice-states/{user} — Get User Voice State (`Client::get_user_voice_state`)
- [x] PATCH /guilds/{id}/voice-states/@me — Modify Current User Voice State (`Client::modify_current_user_voice_state`)
- [x] PATCH /guilds/{id}/voice-states/{user} — Modify User Voice State (`Client::modify_user_voice_state`)

## Guild scheduled events

- [ ] GET /guilds/{id}/scheduled-events/{event}/users/counts — Get event user counts
- [ ] GET /guilds/{id}/scheduled-events/{event}/{exception}/users — Get exception users
- [ ] POST /guilds/{id}/scheduled-events/{event}/exceptions — Create event exception
- [ ] PATCH /guilds/{id}/scheduled-events/{event}/exceptions/{exception} — Modify event exception
- [ ] DELETE /guilds/{id}/scheduled-events/{event}/exceptions/{exception} — Delete event exception

## Guild templates

- [x] GET /guilds/templates/{code} — Get Guild Template (`Client::get_guild_template`)
- [x] POST /guilds/templates/{code} — Create Guild From Template (`Client::create_guild_from_template`) (documented but absent from the OpenAPI spec)
- [x] GET /guilds/{id}/templates — Get Guild Templates (`Client::get_guild_templates`)
- [x] POST /guilds/{id}/templates — Create Guild Template (`Client::create_guild_template`)
- [x] PUT /guilds/{id}/templates/{code} — Sync Guild Template (`Client::sync_guild_template`)
- [x] PATCH /guilds/{id}/templates/{code} — Modify Guild Template (`Client::modify_guild_template`)
- [x] DELETE /guilds/{id}/templates/{code} — Delete Guild Template (`Client::delete_guild_template`)

## Webhooks (token-authenticated)

- [x] GET /webhooks/{id}/{token} — Get Webhook with Token (`get_webhook_with_token`)
- [x] PATCH /webhooks/{id}/{token} — Modify Webhook with Token (`modify_webhook_with_token`)
- [x] DELETE /webhooks/{id}/{token} — Delete Webhook with Token (`delete_webhook_with_token`)
- [x] POST /webhooks/{id}/{token}/github — Execute GitHub-Compatible Webhook (`execute_github_compatible_webhook`)
- [x] POST /webhooks/{id}/{token}/slack — Execute Slack-Compatible Webhook (`execute_slack_compatible_webhook`)

## Invites

- [ ] GET /invites/{code}/target-users — List invite target users
- [ ] PUT /invites/{code}/target-users — Set invite target users
- [ ] GET /invites/{code}/target-users/job-status — Get invite target users job status

## Users & OAuth2

- [x] GET /users/@me/connections — Get Current User Connections (`Client::get_current_user_connections`)
- [x] GET /users/@me/guilds/{id}/member — Get Current User Guild Member (`Client::get_current_user_guild_member`)
- [x] DELETE /users/@me/guilds/{id} — Leave Guild (`Client::leave_guild`)
- [x] GET /oauth2/@me — Get Current Authorization Information (`Client::get_current_authorization_information`)
- [x] GET /oauth2/applications/@me — Get Current Bot Application Information (`Client::get_current_bot_application_information`)

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

## Out of scope: undocumented OAuth2 endpoints

These endpoints are not present in the official developer docs. Discord's
public docs reference OIDC only in the Social SDK provisional-accounts
context; both remain reachable through `Route::custom`.

- GET /oauth2/keys — Get OAuth2 signing keys
- GET /oauth2/userinfo — OAuth2 userinfo

## Out of scope: undocumented endpoints

- GET /applications/{id} — Get Application: not present in the official
  developer docs (only the `@me` application endpoints are documented);
  reachable via `Route::custom`.
- PATCH /applications/{id} — Edit Application: not present in the official
  developer docs (only the `@me` application endpoints are documented);
  reachable via `Route::custom`.
- POST /applications/{id}/attachment — Upload ephemeral application
  attachment: not present in the official developer docs (only the `@me`
  application endpoints are documented); reachable via `Route::custom`.
- GET /guilds/{id}/requests — List guild join requests: not present in the
  official developer docs; reachable via `Route::custom`.
- PATCH /guilds/{id}/requests/{user} — Act on a guild join request: not present
  in the official developer docs; reachable via `Route::custom`.
- GET /guilds/{id}/roles/member-counts — Get role member counts: not present in
  the official developer docs; reachable via `Route::custom`.
- GET /guilds/{id}/new-member-welcome — Get new member welcome: not present in
  the official developer docs; reachable via `Route::custom`.
- GET /channels/{id}/threads/search — Search Threads: not present in the
  official developer docs (limited-availability endpoint); reachable via
  `Route::custom`.
- GET /users/@me/applications/{id}/entitlements — List user entitlements: not
  present in the official developer docs; reachable via `Route::custom`.
