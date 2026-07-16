///|
/// One application role connection metadata record.
pub(all) struct ApplicationRoleConnectionMetadata {
  typ : ApplicationRoleConnectionMetadataType
  key : String
  name : String
  name_localizations : Nullable[Map[String, String]]?
  description : String
  description_localizations : Nullable[Map[String, String]]?
} derive (
  ToJson(fields(typ(rename="type"))),
  FromJson(fields(typ(rename="type"))),
  Debug,
)

///|
/// The comparison used for an application role connection metadata record.
pub(all) enum ApplicationRoleConnectionMetadataType {
  IntegerLessThanOrEqual
  IntegerGreaterThanOrEqual
  IntegerEqual
  IntegerNotEqual
  DatetimeLessThanOrEqual
  DatetimeGreaterThanOrEqual
  BooleanEqual
  BooleanNotEqual
  Unknown(Int)
} derive(Eq, Debug)

///|
pub fn ApplicationRoleConnectionMetadataType::to_int(
  self : ApplicationRoleConnectionMetadataType,
) -> Int {
  match self {
    IntegerLessThanOrEqual => 1
    IntegerGreaterThanOrEqual => 2
    IntegerEqual => 3
    IntegerNotEqual => 4
    DatetimeLessThanOrEqual => 5
    DatetimeGreaterThanOrEqual => 6
    BooleanEqual => 7
    BooleanNotEqual => 8
    Unknown(value) => value
  }
}

///|
pub fn ApplicationRoleConnectionMetadataType::from_int(
  value : Int,
) -> ApplicationRoleConnectionMetadataType {
  match value {
    1 => IntegerLessThanOrEqual
    2 => IntegerGreaterThanOrEqual
    3 => IntegerEqual
    4 => IntegerNotEqual
    5 => DatetimeLessThanOrEqual
    6 => DatetimeGreaterThanOrEqual
    7 => BooleanEqual
    8 => BooleanNotEqual
    value => Unknown(value)
  }
}

///|
pub impl ToJson for ApplicationRoleConnectionMetadataType with fn to_json(self) {
  Json::number(self.to_int().to_double())
}

///|
pub impl @json.FromJson for ApplicationRoleConnectionMetadataType with fn from_json(
  json,
  path,
) {
  match json {
    Number(value, ..) =>
      ApplicationRoleConnectionMetadataType::from_int(value.to_int())
    _ =>
      raise JsonDecodeError(
        (path, "expected application role connection metadata type (number)"),
      )
  }
}
