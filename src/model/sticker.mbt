///|
/// A Discord standard or guild sticker.
pub(all) struct Sticker {
  id : StickerId
  pack_id : StickerPackId?
  name : String
  description : Nullable[String]
  /// A comma-separated expression list, kept in Discord's wire representation.
  tags : String
  asset : String?
  typ : StickerType
  format_type : StickerFormatType
  available : Bool?
  guild_id : GuildId?
  user : User?
  sort_value : Int?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The origin category of a sticker.
pub(all) enum StickerType {
  Standard
  Guild
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn StickerType::to_int(self : StickerType) -> Int {
  match self {
    Standard => 1
    Guild => 2
    Unknown(value) => value
  }
}

///|
pub fn StickerType::from_int(value : Int) -> StickerType {
  match value {
    1 => Standard
    2 => Guild
    value => Unknown(value)
  }
}

///|
pub impl ToJson for StickerType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for StickerType with fn from_json(json, path) {
  match json {
    Number(value, ..) => StickerType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a sticker type (number)"))
  }
}

///|
/// The media format used by a sticker asset.
pub(all) enum StickerFormatType {
  Png
  Apng
  Lottie
  Gif
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn StickerFormatType::to_int(self : StickerFormatType) -> Int {
  match self {
    Png => 1
    Apng => 2
    Lottie => 3
    Gif => 4
    Unknown(value) => value
  }
}

///|
pub fn StickerFormatType::from_int(value : Int) -> StickerFormatType {
  match value {
    1 => Png
    2 => Apng
    3 => Lottie
    4 => Gif
    value => Unknown(value)
  }
}

///|
pub impl ToJson for StickerFormatType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for StickerFormatType with fn from_json(json, path) {
  match json {
    Number(value, ..) => StickerFormatType::from_int(value.to_int())
    _ => raise JsonDecodeError((path, "expected a sticker format (number)"))
  }
}

///|
/// The compact sticker representation included in messages.
pub(all) struct StickerItem {
  id : StickerId
  name : String
  format_type : StickerFormatType
} derive(ToJson, FromJson, Debug)

///|
/// A purchasable collection of standard stickers.
pub(all) struct StickerPack {
  id : StickerPackId
  stickers : Array[Sticker]
  name : String
  sku_id : SkuId
  cover_sticker_id : StickerId?
  description : String
  banner_asset_id : GenericId?
} derive(ToJson, FromJson, Debug)

///|
/// The envelope returned by the sticker-packs listing endpoint.
pub(all) struct StickerPacksResponse {
  sticker_packs : Array[StickerPack]
} derive(ToJson, FromJson, Debug)
