// Source: discord/discord-api-docs @ 845fcaa38e1653d19420311a8e42635eca8de7e5
// Documentation excerpts are attributed under CC-BY-SA 4.0.
// Page: developers/interactions/application-commands.mdx
// Skipped blocks from this page:
// - line 396, Example of editing permissions — application-command edit request body.
// - line 455, Example Slash Command — illustrative command definition omits response-only fields.
// - line 498, Example Interaction — illustrative interaction fragment omits application_id and version.
// - line 836, Example User Command — tiny user-command definition fragment.
// - line 930, Example Message Command — tiny message-command definition fragment.
// - line 1026, Example Entry Point Command — entry-point command definition omits response-only fields.
// - line 1058, Autocomplete — autocomplete fragment omits the interaction envelope.
// - line 1090, Localization — localized application-command request body.
// - line 1138, Retrieving localized commands — invalid JSON (trailing comma).

///|
test "discord docs: example interaction (line 852)" {
  let fixture =
    #|{
    #|    "application_id": "775799577604522054",
    #|    "channel_id": "772908445358620702",
    #|    "data": {
    #|        "id": "866818195033292850",
    #|        "name": "context-menu-user-2",
    #|        "resolved": {
    #|            "members": {
    #|                "809850198683418695": {
    #|                    "avatar": null,
    #|                    "is_pending": false,
    #|                    "joined_at": "2021-02-12T18:25:07.972000+00:00",
    #|                    "nick": null,
    #|                    "pending": false,
    #|                    "permissions": "246997699136",
    #|                    "premium_since": null,
    #|                    "roles": []
    #|                }
    #|            },
    #|            "users": {
    #|                "809850198683418695": {
    #|                    "avatar": "afc428077119df8aabbbd84b0dc90c74",
    #|                    "bot": true,
    #|                    "discriminator": "7302",
    #|                    "id": "809850198683418695",
    #|                    "public_flags": 0,
    #|                    "username": "VoltyDemo"
    #|                }
    #|            }
    #|        },
    #|        "target_id": "809850198683418695",
    #|        "type": 2
    #|    },
    #|    "guild_id": "772904309264089089",
    #|    "guild_locale": "en-US",
    #|    "app_permissions": "442368",
    #|    "id": "867794291820986368",
    #|    "locale": "en-US",
    #|    "member": {
    #|        "avatar": null,
    #|        "deaf": false,
    #|        "is_pending": false,
    #|        "joined_at": "2020-11-02T20:46:57.364000+00:00",
    #|        "mute": false,
    #|        "nick": null,
    #|        "pending": false,
    #|        "permissions": "274877906943",
    #|        "premium_since": null,
    #|        "roles": ["785609923542777878"],
    #|        "user": {
    #|            "avatar": "a_f03401914fb4f3caa9037578ab980920",
    #|            "discriminator": "6538",
    #|            "id": "167348773423415296",
    #|            "public_flags": 1,
    #|            "username": "ian"
    #|        }
    #|    },
    #|    "token": "UNIQUE_TOKEN",
    #|    "type": 2,
    #|    "version": 1
    #|}
  let first : @model.Interaction = @json.from_json(@json.parse(fixture))
  let second : @model.Interaction = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="867794291820986368")
  inspect(first.typ.to_int(), content="2")
}

///|
test "discord docs: example interaction (line 946)" {
  let fixture =
    #|{
    #|    "application_id": "775799577604522054",
    #|    "channel_id": "772908445358620702",
    #|    "data": {
    #|        "id": "866818195033292851",
    #|        "name": "context-menu-message-2",
    #|        "resolved": {
    #|            "messages": {
    #|                "867793854505943041": {
    #|                    "attachments": [],
    #|                    "author": {
    #|                        "avatar": "a_f03401914fb4f3caa9037578ab980920",
    #|                        "discriminator": "6538",
    #|                        "id": "167348773423415296",
    #|                        "public_flags": 1,
    #|                        "username": "ian"
    #|                    },
    #|                    "channel_id": "772908445358620702",
    #|                    "components": [],
    #|                    "content": "some message",
    #|                    "edited_timestamp": null,
    #|                    "embeds": [],
    #|                    "flags": 0,
    #|                    "id": "867793854505943041",
    #|                    "mention_everyone": false,
    #|                    "mention_roles": [],
    #|                    "mentions": [],
    #|                    "pinned": false,
    #|                    "timestamp": "2021-07-22T15:42:57.744000+00:00",
    #|                    "tts": false,
    #|                    "type": 0
    #|                }
    #|            }
    #|        },
    #|        "target_id": "867793854505943041",
    #|        "type": 3
    #|    },
    #|    "guild_id": "772904309264089089",
    #|    "guild_locale": "en-US",
    #|    "app_permissions": "442368",
    #|    "id": "867793873336926249",
    #|    "locale": "en-US",
    #|    "member": {
    #|        "avatar": null,
    #|        "deaf": false,
    #|        "is_pending": false,
    #|        "joined_at": "2020-11-02T20:46:57.364000+00:00",
    #|        "mute": false,
    #|        "nick": null,
    #|        "pending": false,
    #|        "permissions": "274877906943",
    #|        "premium_since": null,
    #|        "roles": ["785609923542777878"],
    #|        "user": {
    #|            "avatar": "a_f03401914fb4f3caa9037578ab980920",
    #|            "discriminator": "6538",
    #|            "id": "167348773423415296",
    #|            "public_flags": 1,
    #|            "username": "ian"
    #|        }
    #|    },
    #|    "token": "UNIQUE_TOKEN",
    #|    "type": 2,
    #|    "version": 1
    #|}
  let first : @model.Interaction = @json.from_json(@json.parse(fixture))
  let second : @model.Interaction = @json.from_json(first.to_json())
  assert_eq("\{to_repr(first)}", "\{to_repr(second)}")
  inspect(first.id.to_string(), content="867793873336926249")
  inspect(first.typ.to_int(), content="2")
}
