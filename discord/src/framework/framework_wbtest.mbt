///|
test "a component waiter accepts its exact custom id and optional user" {
  let user : @model.UserId = @model.Id::parse("200000000000000001")
  let other : @model.UserId = @model.Id::parse("200000000000000002")
  for
    row in [
      ("confirm", None, "confirm", user, true),
      ("confirm", Some(user), "confirm", user, true),
      ("confirm", Some(user), "confirm", other, false),
      ("confirm", None, "cancel", user, false),
      ("confirm", Some(user), "cancel", user, false),
      ("Confirm", None, "confirm", user, false),
    ] {
    let (custom_id, filter, clicked, clicker, accepted) = row
    let waiter = ComponentWaiter::{
      custom_id,
      user: filter,
      queue: Queue(kind=Unbounded),
    }
    assert_eq(waiter.accepts(clicked, clicker), accepted)
  }
}
