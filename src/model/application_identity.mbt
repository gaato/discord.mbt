///|
/// A media value stored in an application identity profile.
pub(all) struct ApplicationIdentityProfileMedia {
  url : String
} derive(ToJson, FromJson, Eq, Debug)

///|
/// Pre-configured game statistics in an application identity profile.
pub(all) struct ApplicationIdentityPrimaryProfileData {
  season : String?
  rank_name : String?
  rank_image : ApplicationIdentityProfileMedia?
  highest_rank : String?
  highest_rank_image : ApplicationIdentityProfileMedia?
  featured_played_character : String?
  featured_played_character_image : ApplicationIdentityProfileMedia?
  playtime_hours : Double?
  total_wins : Int?
  current_period_wins : Int?
  total_games : Int?
  current_period_games : Int?
  total_kills : Int?
  current_period_kills : Int?
  total_assists : Int?
  current_period_assists : Int?
  total_deaths : Int?
  current_period_deaths : Int?
} derive(ToJson, FromJson, Debug)

///|
/// A text-valued custom game statistic.
pub(all) struct ApplicationIdentityDynamicStringField {
  name : String
  value : String
} derive(ToJson, FromJson, Eq, Debug)

///|
/// A number-valued custom game statistic.
pub(all) struct ApplicationIdentityDynamicNumberField {
  name : String
  value : Double
} derive(ToJson, FromJson, Debug)

///|
/// A media-valued custom game statistic.
pub(all) struct ApplicationIdentityDynamicMediaField {
  name : String
  value : ApplicationIdentityProfileMedia
} derive(ToJson, FromJson, Eq, Debug)

///|
/// A custom game statistic dispatched by its numeric wire discriminator.
/// Unknown variants retain their complete JSON object for forward-compatible
/// round trips.
pub(all) enum ApplicationIdentityDynamicField {
  StringField(ApplicationIdentityDynamicStringField)
  NumberField(ApplicationIdentityDynamicNumberField)
  MediaField(ApplicationIdentityDynamicMediaField)
  Unknown(Json)
} derive(Debug)

///|
fn application_identity_dynamic_field_payload(
  payload : Json,
  typ : Int,
) -> Json {
  match payload {
    Object(fields) => {
      fields["type"] = Json::number(typ.to_double())
      Json::object(fields)
    }
    value => value
  }
}

///|
pub impl ToJson for ApplicationIdentityDynamicField with fn to_json(self) {
  match self {
    StringField(value) =>
      application_identity_dynamic_field_payload(ToJson::to_json(value), 1)
    NumberField(value) =>
      application_identity_dynamic_field_payload(ToJson::to_json(value), 2)
    MediaField(value) =>
      application_identity_dynamic_field_payload(ToJson::to_json(value), 3)
    Unknown(value) => value
  }
}

///|
pub impl @json.FromJson for ApplicationIdentityDynamicField with fn from_json(
  json,
  path,
) {
  guard json is Object(fields) else {
    raise JsonDecodeError((path, "expected a dynamic profile field (object)"))
  }
  match fields.get("type") {
    Some(Number(value, ..)) =>
      match value.to_int() {
        1 => StringField(@json.from_json(json, path~))
        2 => NumberField(@json.from_json(json, path~))
        3 => MediaField(@json.from_json(json, path~))
        _ => Unknown(json)
      }
    _ => Unknown(json)
  }
}

///|
/// Game statistics stored in an application identity profile.
pub(all) struct ApplicationIdentityProfileData {
  primary : ApplicationIdentityPrimaryProfileData?
  dynamic : Array[ApplicationIdentityDynamicField]?
} derive(ToJson, FromJson, Debug)

///|
/// Profile data attached to a user's application identity.
pub(all) struct ApplicationIdentityProfile {
  username : Nullable[String]
  metadata : Nullable[Json]
  data : Nullable[ApplicationIdentityProfileData]
} derive(ToJson, FromJson, Debug)

///|
/// An external account identity associated with a Discord user and application.
pub(all) struct ApplicationIdentity {
  user_id : UserId?
  provider_type : String
  provider_id : String?
  provider_issued_user_id : String
} derive(ToJson, FromJson, Debug)
