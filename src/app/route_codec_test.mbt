///|
test "custom_id over 100 characters raises at encode" {
  let codec = @app.CustomIdCodec::string()
  let route = @app.component_route(id="a", state=codec)
  assert_eq(codec.encode("x".repeat(100)).length(), 100)
  assert_eq(route.custom_id("x".repeat(98)).length(), 100)
  assert_eq(route.custom_id("😀".repeat(49)).length(), 100)
  for text in ["x".repeat(101), "😀".repeat(51)] {
    try codec.encode(text) |> ignore catch {
      @app.CustomIdError::TooLong(custom_id~, length~) => {
        assert_eq(custom_id, text)
        assert_eq(length, text.length())
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected oversized encoded state")
    }
  }
  for text in ["x".repeat(99), "x".repeat(101), "😀".repeat(50)] {
    try route.custom_id(text) |> ignore catch {
      @app.CustomIdError::TooLong(custom_id~, length~) => {
        assert_eq(custom_id, "a:\{text}")
        assert_eq(length, text.length() + 2)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected oversized complete id")
    }
  }
  let unit = @app.component_route(
    id="x".repeat(101),
    state=@app.CustomIdCodec::unit(),
  )
  try unit.custom_id(()) |> ignore catch {
    @app.CustomIdError::TooLong(length=101, ..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected oversized bare id")
  }
}

///|
test "zip rejects a separator in a non-final segment" {
  let codec = @app.CustomIdCodec::string().zip(@app.CustomIdCodec::string())
  assert_eq(codec.decode(codec.encode(("", "a:b:c"))), ("", "a:b:c"))
  for
    encode in [
      () => codec.encode(("a:b", "c")),
      () => @app.component_route(id="zip", state=codec).custom_id(("a:b", "c")),
      () => {
        codec.imap(to=value => value, from=value => value).encode(("a:b", "c"))
      },
      () => @app.CustomIdCodec::int().zip(codec).encode((42, ("a:b", "c"))),
    ] {
    try encode() |> ignore catch {
      @app.CustomIdError::SeparatorInSegment(segment~) =>
        assert_eq(segment, "a:b")
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected ambiguous zip segment")
    }
  }
  try codec.decode("missing-separator") |> ignore catch {
    @app.HandlerError::InvalidArgument(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing separator error")
  }
}

///|
test "custom and imap codecs round-trip application state" {
  let codec = @app.CustomIdCodec::custom(
    encode=(value : Bool) => if value { "yes" } else { "no" },
    decode=text => {
      match text {
        "yes" => true
        "no" => false
        _ => raise @app.HandlerError::InvalidArgument("expected yes or no")
      }
    },
  ).imap(to=value => if value { 1 } else { 0 }, from=value => value == 1)
  assert_eq(codec.decode(codec.encode(1)), 1)
  assert_eq(codec.decode(codec.encode(0)), 0)
  try codec.decode("maybe") |> ignore catch {
    @app.HandlerError::InvalidArgument(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid custom state")
  }
  let positive = @app.CustomIdCodec::int().imap(
    to=value => {
      guard value > 0 else {
        raise @app.HandlerError::InvalidArgument("expected positive state")
      }
      value
    },
    from=value => value,
  )
  try positive.decode("0") |> ignore catch {
    @app.HandlerError::InvalidArgument(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected imap validation error")
  }
}

///|
test "modal show enforces the custom id limit" {
  let modal = route_test_modal("feedback")
  modal.show(state="x".repeat(91)) |> ignore
  route_test_modal("x".repeat(100)).show() |> ignore
  for
    show in [
      () => modal.show(state="x".repeat(92)),
      () => route_test_modal("x".repeat(101)).show(),
      () => route_test_modal("😀".repeat(50)).show(state=""),
    ] {
    try show() |> ignore catch {
      @app.CustomIdError::TooLong(custom_id~, length~) => {
        assert_eq(length, 101)
        assert_eq(custom_id.length(), length)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected oversized modal id")
    }
  }
}

///|
priv struct CodecSnowflake(UInt64) derive(Debug)

///|
impl @qc.Arbitrary for CodecSnowflake with fn arbitrary(size, state) {
  CodecSnowflake(
    match size {
      0 => 0UL
      1 => 1UL
      2 => 9007199254740993UL
      3 => 9223372036854775808UL
      4 => 18446744073709551615UL
      _ => state.next_uint64()
    },
  )
}

///|
impl @qc.Shrink for CodecSnowflake with fn shrink(self) {
  @qc.Shrink::shrink(self.0).map(value => CodecSnowflake(value))
}

///|
test "quickcheck custom id int encode then decode is identity" {
  let codec = @app.CustomIdCodec::int()
  for value in [-2147483648, -1, 0, 1, 2147483647] {
    assert_eq(codec.decode(codec.encode(value)), value)
  }
  @qc.check(
    (value : Int) => codec.decode(codec.encode(value)) == value,
    count=256,
    max_size=255,
    seed=0xD15C2301UL,
  )
}

///|
test "quickcheck custom id snowflake encode then decode is identity" {
  let codec : @app.CustomIdCodec[@model.UserId] = @app.CustomIdCodec::id()
  @qc.check(
    (input : CodecSnowflake) => {
      let value : @model.UserId = @model.Id(input.0)
      codec.decode(codec.encode(value)) == value
    },
    count=256,
    max_size=255,
    seed=0xD15C2302UL,
  )
}

///|
test "quickcheck custom id zip int string encode then decode is identity" {
  let codec = @app.CustomIdCodec::int().zip(@app.CustomIdCodec::string())
  @qc.check(
    (input : (Int, String)) => {
      let value = (
        input.0,
        String::from_iter(input.1.iter().take(30)) + ":tail",
      )
      codec.decode(codec.encode(value)) == value
    },
    count=256,
    max_size=255,
    seed=0xD15C2303UL,
  )
}

///|
test "built-in codecs reject state they cannot decode" {
  try @app.CustomIdCodec::unit().decode("extra") catch {
    @app.HandlerError::InvalidArgument(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("unit accepted state")
  }
  let id : @app.CustomIdCodec[@model.UserId] = @app.CustomIdCodec::id()
  try id.decode("not-a-snowflake") |> ignore catch {
    @app.HandlerError::InvalidArgument(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("id accepted a non-snowflake")
  }
}

///|
test "a route decodes the ids it produces and rejects foreign ones" {
  let route = @app.component_route(
    id="docs",
    state=@app.CustomIdCodec::int().zip(@app.CustomIdCodec::string()),
  )
  let id = route.custom_id((3, "02-two.mbt.md#a::b"))
  assert_eq(id, "docs:3:02-two.mbt.md#a::b")
  assert_eq(route.decode(id), (3, "02-two.mbt.md#a::b"))
  let bare = @app.component_route(id="done", state=@app.CustomIdCodec::unit())
  assert_eq(bare.decode(bare.custom_id(())), ())
  for foreign in ["docsy:3:x", "other:3:x", "docs:indicator", "docs"] {
    try route.decode(foreign) |> ignore catch {
      @app.HandlerError::InvalidArgument(_) => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("decoded a foreign or malformed id: \{foreign}")
    }
  }
}
