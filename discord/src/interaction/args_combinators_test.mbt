///|
fn sum_fixture() -> @interaction.CommandOptions raise {
  typed_options(
    (
      #|{
      #|  "id": "107000000000000106",
      #|  "name": "sum",
      #|  "type": 1,
      #|  "options": [
      #|    {"name": "n1", "type": 4, "value": 1},
      #|    {"name": "n2", "type": 4, "value": 2},
      #|    {"name": "n3", "type": 4, "value": 3},
      #|    {"name": "n4", "type": 4, "value": 4},
      #|    {"name": "n5", "type": 4, "value": 5},
      #|    {"name": "n6", "type": 4, "value": 6},
      #|    {"name": "n7", "type": 4, "value": 7}
      #|  ]
      #|}
    ),
  )
}

///|
fn sum_arg(name : String) -> @interaction.Arg[Int64] {
  @interaction.arg_int(name~, description=name)
}

///|
test "every mapN combinator decodes its arity" {
  let options = sum_fixture()
  inspect(
    @interaction.Args::map1(sum_arg("n1"), a => a * 10L).decode(options),
    content="10",
  )
  inspect(
    @interaction.Args::map4(
      sum_arg("n1"),
      sum_arg("n2"),
      sum_arg("n3"),
      sum_arg("n4"),
      (a, b, c, d) => a + b + c + d,
    ).decode(options),
    content="10",
  )
  inspect(
    @interaction.Args::map5(
      sum_arg("n1"),
      sum_arg("n2"),
      sum_arg("n3"),
      sum_arg("n4"),
      sum_arg("n5"),
      (a, b, c, d, e) => a + b + c + d + e,
    ).decode(options),
    content="15",
  )
  inspect(
    @interaction.Args::map6(
      sum_arg("n1"),
      sum_arg("n2"),
      sum_arg("n3"),
      sum_arg("n4"),
      sum_arg("n5"),
      sum_arg("n6"),
      (a, b, c, d, e, f) => a + b + c + d + e + f,
    ).decode(options),
    content="21",
  )
  inspect(
    @interaction.Args::map7(
      sum_arg("n1"),
      sum_arg("n2"),
      sum_arg("n3"),
      sum_arg("n4"),
      sum_arg("n5"),
      sum_arg("n6"),
      sum_arg("n7"),
      (a, b, c, d, e, f, g) => a + b + c + d + e + f + g,
    ).decode(options),
    content="28",
  )
}

///|
test "number, channel, and mentionable args decode their option kinds" {
  let options = typed_options(
    (
      #|{
      #|  "id": "107000000000000107",
      #|  "name": "kinds",
      #|  "type": 1,
      #|  "options": [
      #|    {"name": "ratio", "type": 10, "value": 1.5},
      #|    {"name": "room", "type": 7, "value": "400000000000000001"},
      #|    {"name": "who", "type": 9, "value": "200000000000000001"}
      #|  ]
      #|}
    ),
  )
  let ratio = @interaction.arg_number(name="ratio", description="ratio")
  inspect(@interaction.Args::of(ratio).decode(options), content="1.5")
  let room = @interaction.arg_channel(name="room", description="room")
  inspect(
    @interaction.Args::of(room).decode(options).to_string(),
    content="400000000000000001",
  )
  let who = @interaction.arg_mentionable(name="who", description="who")
  inspect(
    @interaction.Args::of(who).decode(options).to_string(),
    content="200000000000000001",
  )
}

///|
test "arg map transforms values and validate passes clean input through" {
  let options = sum_fixture()
  let doubled = sum_arg("n2").map(value => value * 2L)
  inspect(@interaction.Args::of(doubled).decode(options), content="4")
  let checked = sum_arg("n3").validate(value => {
    if value > 0L {
      None
    } else {
      Some("must be positive")
    }
  })
  inspect(@interaction.Args::of(checked).decode(options), content="3")
}
