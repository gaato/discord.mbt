///|
fn list_entitlements_query(
  user_id? : @model.UserId,
  sku_ids? : Array[@model.SkuId],
  before? : @model.EntitlementId,
  after? : @model.EntitlementId,
  limit? : Int,
  guild_id? : @model.GuildId,
  exclude_ended? : Bool,
  exclude_deleted? : Bool,
) -> String raise DiscordHttpError {
  validate_page_limit("entitlement", limit, 100)
  let params : Array[String] = []
  if user_id is Some(value) {
    params.push("user_id=\{value}")
  }
  if sku_ids is Some(values) && values.length() > 0 {
    params.push("sku_ids=" + values.map(value => value.to_string()).join(","))
  }
  if before is Some(value) {
    params.push("before=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if guild_id is Some(value) {
    params.push("guild_id=\{value}")
  }
  if exclude_ended is Some(value) {
    params.push("exclude_ended=\{value}")
  }
  if exclude_deleted is Some(value) {
    params.push("exclude_deleted=\{value}")
  }
  if params.length() == 0 {
    ""
  } else {
    "?" + params.join("&")
  }
}

///|
fn create_test_entitlement_body(
  sku_id : @model.SkuId,
  owner_id : @model.GenericId,
  owner_type : @model.EntitlementOwnerType,
) -> Json {
  @model.ObjBuilder()
  .field("sku_id", sku_id)
  .field("owner_id", owner_id)
  .field("owner_type", owner_type)
  .build()
}

///|
fn list_sku_subscriptions_query(
  before? : @model.SubscriptionId,
  after? : @model.SubscriptionId,
  limit? : Int,
  user_id? : @model.UserId,
) -> String raise DiscordHttpError {
  validate_page_limit("SKU subscription", limit, 100)
  let params : Array[String] = []
  if before is Some(value) {
    params.push("before=\{value}")
  }
  if after is Some(value) {
    params.push("after=\{value}")
  }
  if limit is Some(value) {
    params.push("limit=\{value}")
  }
  if user_id is Some(value) {
    params.push("user_id=\{value}")
  }
  if params.length() == 0 {
    ""
  } else {
    "?" + params.join("&")
  }
}

///|
/// List entitlements for an application.
///
/// https://discord.com/developers/docs/resources/entitlement#list-entitlements
pub async fn Client::list_entitlements(
  self : Client,
  application_id : @model.ApplicationId,
  user_id? : @model.UserId,
  sku_ids? : Array[@model.SkuId],
  before? : @model.EntitlementId,
  after? : @model.EntitlementId,
  limit? : Int,
  guild_id? : @model.GuildId,
  exclude_ended? : Bool,
  exclude_deleted? : Bool,
) -> Array[@model.Entitlement] raise DiscordHttpError {
  let query = list_entitlements_query(
    user_id?,
    sku_ids?,
    before?,
    after?,
    limit?,
    guild_id?,
    exclude_ended?,
    exclude_deleted?,
  )
  decode(self.request(ListEntitlements(application_id~, query~)))
}

///|
/// Fetch an entitlement for an application.
///
/// https://discord.com/developers/docs/resources/entitlement#get-entitlement
pub async fn Client::get_entitlement(
  self : Client,
  application_id : @model.ApplicationId,
  entitlement_id : @model.EntitlementId,
) -> @model.Entitlement raise DiscordHttpError {
  decode(self.request(GetEntitlement(application_id~, entitlement_id~)))
}

///|
/// Create a test entitlement. The returned entitlement has no subscription
/// information.
///
/// https://discord.com/developers/docs/resources/entitlement#create-test-entitlement
pub async fn Client::create_test_entitlement(
  self : Client,
  application_id : @model.ApplicationId,
  sku_id : @model.SkuId,
  owner_id : @model.GenericId,
  owner_type : @model.EntitlementOwnerType,
) -> @model.Entitlement raise DiscordHttpError {
  let body = create_test_entitlement_body(sku_id, owner_id, owner_type)
  decode(self.request(CreateTestEntitlement(application_id~), body~))
}

///|
/// Mark an entitlement as consumed.
///
/// https://discord.com/developers/docs/resources/entitlement#consume-an-entitlement
pub async fn Client::consume_entitlement(
  self : Client,
  application_id : @model.ApplicationId,
  entitlement_id : @model.EntitlementId,
) -> Unit raise DiscordHttpError {
  self.request(ConsumeEntitlement(application_id~, entitlement_id~)) |> ignore
}

///|
/// Delete a test entitlement.
///
/// https://discord.com/developers/docs/resources/entitlement#delete-test-entitlement
pub async fn Client::delete_test_entitlement(
  self : Client,
  application_id : @model.ApplicationId,
  entitlement_id : @model.EntitlementId,
) -> Unit raise DiscordHttpError {
  self.request(DeleteTestEntitlement(application_id~, entitlement_id~))
  |> ignore
}

///|
/// List the SKUs available for an application.
///
/// https://discord.com/developers/docs/resources/sku#list-skus
pub async fn Client::list_skus(
  self : Client,
  application_id : @model.ApplicationId,
) -> Array[@model.Sku] raise DiscordHttpError {
  decode(self.request(ListSkus(application_id~)))
}

///|
/// List subscriptions for a SKU. Discord requires `user_id` except for OAuth
/// queries.
///
/// https://discord.com/developers/docs/resources/subscription#list-sku-subscriptions
pub async fn Client::list_sku_subscriptions(
  self : Client,
  sku_id : @model.SkuId,
  before? : @model.SubscriptionId,
  after? : @model.SubscriptionId,
  limit? : Int,
  user_id? : @model.UserId,
) -> Array[@model.Subscription] raise DiscordHttpError {
  let query = list_sku_subscriptions_query(before?, after?, limit?, user_id?)
  decode(self.request(ListSkuSubscriptions(sku_id~, query~)))
}

///|
/// Fetch a subscription for a SKU.
///
/// https://discord.com/developers/docs/resources/subscription#get-sku-subscription
pub async fn Client::get_sku_subscription(
  self : Client,
  sku_id : @model.SkuId,
  subscription_id : @model.SubscriptionId,
) -> @model.Subscription raise DiscordHttpError {
  decode(self.request(GetSkuSubscription(sku_id~, subscription_id~)))
}
