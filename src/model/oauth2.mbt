///|
/// A user's linked external service account.
pub(all) struct Connection {
  id : String
  name : String
  typ : ConnectionService
  revoked : Bool?
  integrations : Array[Integration]?
  verified : Bool
  friend_sync : Bool
  show_activity : Bool
  two_way_link : Bool
  visibility : Int
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// An external service linked to a Discord user account.
pub(all) enum ConnectionService {
  AmazonMusic
  BattleNet
  Bluesky
  BungieNet
  Crunchyroll
  Domain
  Ebay
  EpicGames
  Facebook
  Github
  Instagram
  LeagueOfLegends
  Mastodon
  Paypal
  PlaystationNetwork
  Reddit
  RiotGames
  Roblox
  Spotify
  Skype
  Steam
  Tiktok
  Twitch
  X
  Xbox
  Youtube
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn ConnectionService::to_string(self : ConnectionService) -> String {
  match self {
    AmazonMusic => "amazon-music"
    BattleNet => "battlenet"
    Bluesky => "bluesky"
    BungieNet => "bungie"
    Crunchyroll => "crunchyroll"
    Domain => "domain"
    Ebay => "ebay"
    EpicGames => "epicgames"
    Facebook => "facebook"
    Github => "github"
    Instagram => "instagram"
    LeagueOfLegends => "leagueoflegends"
    Mastodon => "mastodon"
    Paypal => "paypal"
    PlaystationNetwork => "playstation"
    Reddit => "reddit"
    RiotGames => "riotgames"
    Roblox => "roblox"
    Spotify => "spotify"
    Skype => "skype"
    Steam => "steam"
    Tiktok => "tiktok"
    Twitch => "twitch"
    X => "twitter"
    Xbox => "xbox"
    Youtube => "youtube"
    Unknown(value) => value
  }
}

///|
pub fn ConnectionService::from_string(value : String) -> ConnectionService {
  match value {
    "amazon-music" => AmazonMusic
    "battlenet" => BattleNet
    "bluesky" => Bluesky
    "bungie" => BungieNet
    "crunchyroll" => Crunchyroll
    "domain" => Domain
    "ebay" => Ebay
    "epicgames" => EpicGames
    "facebook" => Facebook
    "github" => Github
    "instagram" => Instagram
    "leagueoflegends" => LeagueOfLegends
    "mastodon" => Mastodon
    "paypal" => Paypal
    "playstation" => PlaystationNetwork
    "reddit" => Reddit
    "riotgames" => RiotGames
    "roblox" => Roblox
    "spotify" => Spotify
    "skype" => Skype
    "steam" => Steam
    "tiktok" => Tiktok
    "twitch" => Twitch
    "twitter" => X
    "xbox" => Xbox
    "youtube" => Youtube
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ConnectionService with fn to_json(self) {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for ConnectionService with fn from_json(json, path) {
  match json {
    String(value) => ConnectionService::from_string(value.to_string())
    _ =>
      raise @json.JsonDecodeError(
        (path, "expected connection service (string)"),
      )
  }
}

///|
/// Metadata attached to a user's application role connection.
pub(all) struct ApplicationRoleConnection {
  platform_name : Nullable[String]
  platform_username : Nullable[String]
  metadata : Json
} derive(ToJson, FromJson, Debug)
