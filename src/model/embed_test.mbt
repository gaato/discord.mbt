///|
test "embed decodes a rich fixture with every sub-object" {
  let fixture =
    #|{
    #|  "title": "Discord API",
    #|  "type": "rich",
    #|  "url": "https://discord.com/developers/docs/resources/message",
    #|  "description": "A rich embed example",
    #|  "timestamp": "2024-01-02T03:04:05.000000+00:00",
    #|  "color": 5793266,
    #|  "footer": {
    #|    "text": "Footer text",
    #|    "icon_url": "https://cdn.example/footer.png",
    #|    "proxy_icon_url": "https://proxy.example/footer.png"
    #|  },
    #|  "image": {
    #|    "url": "https://cdn.example/image.png",
    #|    "proxy_url": "https://proxy.example/image.png",
    #|    "height": 600,
    #|    "width": 800
    #|  },
    #|  "thumbnail": {
    #|    "url": "https://cdn.example/thumb.png",
    #|    "proxy_url": "https://proxy.example/thumb.png",
    #|    "height": 80,
    #|    "width": 80
    #|  },
    #|  "video": {
    #|    "url": "https://cdn.example/video.mp4",
    #|    "proxy_url": "https://proxy.example/video.mp4",
    #|    "height": 720,
    #|    "width": 1280
    #|  },
    #|  "provider": {
    #|    "name": "Discord",
    #|    "url": "https://discord.com"
    #|  },
    #|  "author": {
    #|    "name": "Nelly",
    #|    "url": "https://example.com/nelly",
    #|    "icon_url": "https://cdn.example/author.png",
    #|    "proxy_icon_url": "https://proxy.example/author.png"
    #|  },
    #|  "fields": [{
    #|    "name": "Status",
    #|    "value": "Operational",
    #|    "inline": true
    #|  }],
    #|  "brand_new_field_from_discord": true
    #|}
  let embed : @model.Embed = @json.from_json(@json.parse(fixture))
  debug_inspect(
    embed,
    content=(
      #|{
      #|  title: Some("Discord API"),
      #|  typ: Some(Rich),
      #|  url: Some("https://discord.com/developers/docs/resources/message"),
      #|  description: Some("A rich embed example"),
      #|  timestamp: Some("2024-01-02T03:04:05.000000+00:00"),
      #|  color: Some(5793266),
      #|  footer: Some(
      #|    {
      #|      text: "Footer text",
      #|      icon_url: Some("https://cdn.example/footer.png"),
      #|      proxy_icon_url: Some("https://proxy.example/footer.png"),
      #|    },
      #|  ),
      #|  image: Some(
      #|    {
      #|      url: "https://cdn.example/image.png",
      #|      proxy_url: Some("https://proxy.example/image.png"),
      #|      height: Some(600),
      #|      width: Some(800),
      #|    },
      #|  ),
      #|  thumbnail: Some(
      #|    {
      #|      url: "https://cdn.example/thumb.png",
      #|      proxy_url: Some("https://proxy.example/thumb.png"),
      #|      height: Some(80),
      #|      width: Some(80),
      #|    },
      #|  ),
      #|  video: Some(
      #|    {
      #|      url: Some("https://cdn.example/video.mp4"),
      #|      proxy_url: Some("https://proxy.example/video.mp4"),
      #|      height: Some(720),
      #|      width: Some(1280),
      #|    },
      #|  ),
      #|  provider: Some({ name: Some("Discord"), url: Some("https://discord.com") }),
      #|  author: Some(
      #|    {
      #|      name: "Nelly",
      #|      url: Some("https://example.com/nelly"),
      #|      icon_url: Some("https://cdn.example/author.png"),
      #|      proxy_icon_url: Some("https://proxy.example/author.png"),
      #|    },
      #|  ),
      #|  fields: Some([{ name: "Status", value: "Operational", inline: Some(true) }]),
      #|  flags: None,
      #|}
    ),
  )
}

///|
test "embed decodes an empty object" {
  let embed : @model.Embed = @json.from_json(@json.parse("{}"))
  debug_inspect(
    embed,
    content=(
      #|{
      #|  title: None,
      #|  typ: None,
      #|  url: None,
      #|  description: None,
      #|  timestamp: None,
      #|  color: None,
      #|  footer: None,
      #|  image: None,
      #|  thumbnail: None,
      #|  video: None,
      #|  provider: None,
      #|  author: None,
      #|  fields: None,
      #|  flags: None,
      #|}
    ),
  )
}

///|
test "embed encode omits absent optional fields" {
  let embed : @model.Embed = {
    title: None,
    typ: None,
    url: None,
    description: None,
    timestamp: None,
    color: None,
    footer: None,
    image: None,
    thumbnail: None,
    video: None,
    provider: None,
    author: None,
    fields: None,
    flags: None,
  }
  inspect(
    embed.to_json().stringify(),
    content=(
      #|{}
    ),
  )
}

///|
test "embed type string enum preserves unknown values" {
  let known : @model.EmbedType = @json.from_json(Json::string("gifv"))
  debug_inspect(
    known,
    content=(
      #|Gifv
    ),
  )
  let unknown : @model.EmbedType = @json.from_json(Json::string("future_card"))
  debug_inspect(
    unknown,
    content=(
      #|Unknown("future_card")
    ),
  )
  inspect(
    unknown.to_json().stringify(),
    content=(
      #|"future_card"
    ),
  )
  let round_trip : @model.EmbedType = @json.from_json(unknown.to_json())
  assert_true(round_trip == unknown)
}
