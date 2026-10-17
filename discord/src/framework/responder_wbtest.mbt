///|
fn route_label(route : ReplyRoute) -> String {
  match route {
    Initial => "initial"
    EditPlaceholder(fallback_on_error~) =>
      "edit placeholder, fallback=\{fallback_on_error}"
    Followup => "followup"
    Expired => "expired"
  }
}

///|
test "reply route follows the callback state and the placeholder" {
  for
    row in [
      (Pending, false, "initial"),
      (Pending, true, "initial"),
      (Expired, false, "expired"),
      (Expired, true, "expired"),
      (
        Sent(DeferredChannelMessageWithSource),
        true,
        "edit placeholder, fallback=false",
      ),
      (Sent(DeferredChannelMessageWithSource), false, "followup"),
      (
        Unconfirmed(DeferredChannelMessageWithSource),
        true,
        "edit placeholder, fallback=true",
      ),
      (Unconfirmed(DeferredChannelMessageWithSource), false, "followup"),
      (Sent(DeferredUpdateMessage), true, "followup"),
      (Sent(DeferredUpdateMessage), false, "followup"),
      (Sent(ChannelMessageWithSource), true, "followup"),
      (Sent(ChannelMessageWithSource), false, "followup"),
      (Unconfirmed(Modal), true, "followup"),
      (Unconfirmed(Modal), false, "followup"),
    ] {
    let (state, placeholder_open, route) = row
    assert_eq(route_label(reply_route(state, placeholder_open)), route)
  }
}
