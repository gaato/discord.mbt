///|
/// One entry of a `file_types` upload filter (File Upload components and
/// ATTACHMENT command options): a Discord preset group or a dot-prefixed
/// extension. Discord matches only the filename extension, case-insensitively,
/// and accepts at most 10 entries. Prefer the groups: Discord owns their
/// extension lists and may change them.
///
/// ```mbt check
/// test "restrict an upload to images and PDFs" {
///   let filter : Array[@model.FileTypeFilter] = [Image, Extension(".pdf")]
///   inspect(Json(filter).stringify(), content="[\"image\",\".pdf\"]")
/// }
/// ```
pub(all) enum FileTypeFilter {
  Image
  Video
  Audio
  /// A dot-prefixed extension such as `.pdf`.
  Extension(String)
  /// A value this version does not know (e.g. a future preset group).
  Unknown(String)
} derive(Eq, Debug)

///|
pub fn FileTypeFilter::to_string(self : FileTypeFilter) -> String {
  match self {
    Image => "image"
    Video => "video"
    Audio => "audio"
    Extension(value) | Unknown(value) => value
  }
}

///|
pub fn FileTypeFilter::from_string(value : String) -> FileTypeFilter {
  match value {
    "image" => Image
    "video" => Video
    "audio" => Audio
    _ if value.has_prefix(".") => Extension(value)
    _ => Unknown(value)
  }
}

///|
pub impl ToJson for FileTypeFilter with fn to_json(self) {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for FileTypeFilter with fn from_json(json, path) {
  match json {
    String(value) => FileTypeFilter::from_string(value)
    _ => raise JsonDecodeError((path, "expected a file type filter (string)"))
  }
}
