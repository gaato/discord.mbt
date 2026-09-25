///|
/// Fetch the current bot application.
pub async fn Client::get_current_application(
  self : Client,
) -> @model.Application raise DiscordHttpError {
  decode(self.request(GetCurrentApplication))
}

///|
/// Fetch a live application activity instance. Requires a Bot token.
///
/// Returns HTTP 404 when no live instance exists for `instance_id`.
///
/// https://discord.com/developers/docs/resources/application#get-application-activity-instance
pub async fn Client::get_application_activity_instance(
  self : Client,
  application_id : @model.ApplicationId,
  instance_id : String,
) -> @model.ActivityInstance raise DiscordHttpError {
  decode(
    self.request(GetApplicationActivityInstance(application_id~, instance_id~)),
  )
}

///|
fn validate_application_url(
  field : String,
  value : String?,
) -> Unit raise DiscordHttpError {
  validate_length(field, value, max=2048)
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
      validate_length("application tag", Some(tag), max=20)
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

///|
fn update_application_role_connection_metadata_records_body(
  records : Array[@model.ApplicationRoleConnectionMetadata],
) -> Json raise DiscordHttpError {
  if records.length() > 5 {
    raise Validation(
      message="role connection metadata records exceed 5 entries",
    )
  }
  Json(records)
}

///|
/// Fetch the application role connection metadata records for an application.
///
/// https://discord.com/developers/docs/resources/application-role-connection-metadata#get-application-role-connection-metadata-records
pub async fn Client::get_application_role_connection_metadata_records(
  self : Client,
  application_id : @model.ApplicationId,
) -> Array[@model.ApplicationRoleConnectionMetadata] raise DiscordHttpError {
  decode(
    self.request(GetApplicationRoleConnectionMetadataRecords(application_id~)),
  )
}

///|
/// Replace the application role connection metadata records for an application.
///
/// The records are sent as a raw JSON array. Discord accepts at most five.
///
/// https://discord.com/developers/docs/resources/application-role-connection-metadata#update-application-role-connection-metadata-records
pub async fn Client::update_application_role_connection_metadata_records(
  self : Client,
  application_id : @model.ApplicationId,
  records : Array[@model.ApplicationRoleConnectionMetadata],
) -> Array[@model.ApplicationRoleConnectionMetadata] raise DiscordHttpError {
  let body = update_application_role_connection_metadata_records_body(records)
  decode(
    self.request(
      UpdateApplicationRoleConnectionMetadataRecords(application_id~),
      body~,
    ),
  )
}
