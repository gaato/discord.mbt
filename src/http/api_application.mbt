///|
/// Fetch the current bot application.
pub async fn Client::get_current_application(
  self : Client,
) -> @model.Application raise DiscordHttpError {
  decode(self.request(GetCurrentApplication))
}

///|
fn validate_application_url(
  field : String,
  value : String?,
) -> Unit raise DiscordHttpError {
  if value is Some(url) && url.length() > 2048 {
    raise Validation(message="\{field} exceeds 2048 characters")
  }
}

///|
fn edit_current_application_body(
  custom_install_url? : String,
  clear_custom_install_url? : Bool = false,
  description? : String,
  clear_description? : Bool = false,
  role_connections_verification_url? : String,
  clear_role_connections_verification_url? : Bool = false,
  install_params? : @model.InstallParams,
  clear_install_params? : Bool = false,
  integration_types_config? : Map[
    String,
    @model.ApplicationIntegrationTypeConfiguration,
  ],
  flags? : @model.ApplicationFlags,
  icon? : String,
  clear_icon? : Bool = false,
  cover_image? : String,
  clear_cover_image? : Bool = false,
  interactions_endpoint_url? : String,
  clear_interactions_endpoint_url? : Bool = false,
  tags? : Array[String],
  clear_tags? : Bool = false,
  event_webhooks_url? : String,
  clear_event_webhooks_url? : Bool = false,
  event_webhooks_status? : @model.ApplicationEventWebhookStatus,
  event_webhooks_types? : Array[String],
) -> Json raise DiscordHttpError {
  validate_application_url("custom_install_url", custom_install_url)
  validate_application_url(
    "role_connections_verification_url", role_connections_verification_url,
  )
  validate_application_url(
    "interactions_endpoint_url", interactions_endpoint_url,
  )
  validate_application_url("event_webhooks_url", event_webhooks_url)
  if tags is Some(values) {
    if values.length() > 5 {
      raise Validation(message="application tags exceed 5 entries")
    }
    for tag in values {
      if tag.length() > 20 {
        raise Validation(message="application tag exceeds 20 characters")
      }
    }
  }
  @model.ObjBuilder()
  .und(
    "custom_install_url",
    patch_nullable(
      "custom_install_url", custom_install_url, clear_custom_install_url,
    ),
  )
  .und(
    "description",
    patch_nullable("description", description, clear_description),
  )
  .und(
    "role_connections_verification_url",
    patch_nullable(
      "role_connections_verification_url", role_connections_verification_url, clear_role_connections_verification_url,
    ),
  )
  .und(
    "install_params",
    patch_nullable("install_params", install_params, clear_install_params),
  )
  .opt("integration_types_config", integration_types_config)
  .opt("flags", flags)
  .und("icon", patch_nullable("icon", icon, clear_icon))
  .und(
    "cover_image",
    patch_nullable("cover_image", cover_image, clear_cover_image),
  )
  .und(
    "interactions_endpoint_url",
    patch_nullable(
      "interactions_endpoint_url", interactions_endpoint_url, clear_interactions_endpoint_url,
    ),
  )
  .und("tags", patch_nullable("tags", tags, clear_tags))
  .und(
    "event_webhooks_url",
    patch_nullable(
      "event_webhooks_url", event_webhooks_url, clear_event_webhooks_url,
    ),
  )
  .opt("event_webhooks_status", event_webhooks_status)
  .opt("event_webhooks_types", event_webhooks_types)
  .build()
}

///|
/// Edit the current bot application. Nullable fields use a matching `clear_*`
/// flag so omission remains distinct from sending JSON null.
///
/// Only the limited-intent flags (`GATEWAY_PRESENCE_LIMITED`,
/// `GATEWAY_GUILD_MEMBERS_LIMITED`, and `GATEWAY_MESSAGE_CONTENT_LIMITED`) can
/// be changed through this API. Discord sends a PING when setting
/// `interactions_endpoint_url` and returns HTTP 400 if the URL does not respond.
/// While an interactions endpoint is configured, interactions are not delivered
/// over the Gateway.
pub async fn Client::edit_current_application(
  self : Client,
  custom_install_url? : String,
  clear_custom_install_url? : Bool = false,
  description? : String,
  clear_description? : Bool = false,
  role_connections_verification_url? : String,
  clear_role_connections_verification_url? : Bool = false,
  install_params? : @model.InstallParams,
  clear_install_params? : Bool = false,
  integration_types_config? : Map[
    String,
    @model.ApplicationIntegrationTypeConfiguration,
  ],
  flags? : @model.ApplicationFlags,
  icon? : String,
  clear_icon? : Bool = false,
  cover_image? : String,
  clear_cover_image? : Bool = false,
  interactions_endpoint_url? : String,
  clear_interactions_endpoint_url? : Bool = false,
  tags? : Array[String],
  clear_tags? : Bool = false,
  event_webhooks_url? : String,
  clear_event_webhooks_url? : Bool = false,
  event_webhooks_status? : @model.ApplicationEventWebhookStatus,
  event_webhooks_types? : Array[String],
) -> @model.Application raise DiscordHttpError {
  let body = edit_current_application_body(
    custom_install_url?,
    clear_custom_install_url~,
    description?,
    clear_description~,
    role_connections_verification_url?,
    clear_role_connections_verification_url~,
    install_params?,
    clear_install_params~,
    integration_types_config?,
    flags?,
    icon?,
    clear_icon~,
    cover_image?,
    clear_cover_image~,
    interactions_endpoint_url?,
    clear_interactions_endpoint_url~,
    tags?,
    clear_tags~,
    event_webhooks_url?,
    clear_event_webhooks_url~,
    event_webhooks_status?,
    event_webhooks_types?,
  )
  decode(self.request(EditCurrentApplication, body~))
}
