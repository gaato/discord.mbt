///|
fn route_test_modal(id : String) -> @app.Modal[String] {
  @app.modal(
    custom_id=id,
    title="Route validation",
    fields=@app.ModalFields::of(@app.text_field(custom_id="note", label="Note")),
  )
}

///|
test "validate rejects duplicate component routes" {
  for raw in [false, true] {
    let app = @app.App()
    let route = @app.component_route(
      id="ticket",
      state=@app.CustomIdCodec::unit(),
    )
    for _ in 0..<2 {
      if raw {
        app.on_component_raw(prefix="ticket", _ => ())
      } else {
        app.on_component(route, Raw(_ => ()))
      }
    }
    try app.validate() catch {
      @app.AppConfigError::DuplicateComponentRoute(custom_id~) =>
        assert_eq(custom_id, "ticket")
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected duplicate component route")
    }
  }
}

///|
test "validate rejects duplicate modal routes" {
  for raw in [false, true] {
    let app = @app.App()
    let modal = route_test_modal("ticket")
    for _ in 0..<2 {
      if raw {
        app.on_modal_raw(prefix="ticket", _ => ())
      } else {
        app.on_modal(modal, Raw(_ => ()))
      }
    }
    try app.validate() catch {
      @app.AppConfigError::DuplicateModalRoute(custom_id~) =>
        assert_eq(custom_id, "ticket")
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected duplicate modal route")
    }
  }
}

///|
test "validate rejects empty component routes" {
  for raw in [false, true] {
    let app = @app.App()
    if raw {
      app.on_component_raw(prefix="", _ => ())
    } else {
      app.on_component(
        @app.component_route(id="", state=@app.CustomIdCodec::unit()),
        Raw(_ => ()),
      )
    }
    try app.validate() catch {
      @app.AppConfigError::EmptyComponentRoute => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected empty component route")
    }
  }
}

///|
test "validate rejects empty modal routes" {
  for raw in [false, true] {
    let app = @app.App()
    if raw {
      app.on_modal_raw(prefix="", _ => ())
    } else {
      app.on_modal(route_test_modal(""), Raw(_ => ()))
    }
    try app.validate() catch {
      @app.AppConfigError::EmptyModalRoute => ()
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected empty modal route")
    }
  }
}

///|
test "id route collides with its literal prefix form" {
  for raw_first in [false, true] {
    let components = @app.App()
    let modals = @app.App()
    if raw_first {
      components.on_component_raw(prefix="a:", _ => ())
      modals.on_modal_raw(prefix="a:", _ => ())
    }
    components.on_component(
      @app.component_route(id="a", state=@app.CustomIdCodec::unit()),
      Raw(_ => ()),
    )
    modals.on_modal(route_test_modal("a"), Raw(_ => ()))
    if !raw_first {
      components.on_component_raw(prefix="a:", _ => ())
      modals.on_modal_raw(prefix="a:", _ => ())
    }
    let duplicate = if raw_first { "a" } else { "a:" }
    try components.validate() catch {
      @app.AppConfigError::DuplicateComponentRoute(custom_id~) =>
        assert_eq(custom_id, duplicate)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected duplicate component route")
    }
    try modals.validate() catch {
      @app.AppConfigError::DuplicateModalRoute(custom_id~) =>
        assert_eq(custom_id, duplicate)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected duplicate modal route")
    }
  }
}

///|
test "invalid route ids are rejected" {
  for id in ["x".repeat(101), "😀".repeat(51)] {
    for modal in [false, true] {
      let app = @app.App()
      if modal {
        app.on_modal(route_test_modal(id), Raw(_ => ()))
      } else {
        app.on_component(
          @app.component_route(id~, state=@app.CustomIdCodec::unit()),
          Raw(_ => ()),
        )
      }
      try app.validate() catch {
        @app.AppConfigError::InvalidRouteId(custom_id~, reason~) => {
          assert_eq(custom_id, id)
          assert_false(reason.is_empty())
        }
        error => fail("unexpected error: \{Repr(error)}")
      } noraise {
        _ => fail("expected invalid route id")
      }
    }
  }
}

///|
test "typed route ids may contain the separator but not nest at it" {
  let route = @app.component_route(
    id="bot:rolemenu",
    state=@app.CustomIdCodec::int(),
  )
  assert_eq(route.custom_id(7), "bot:rolemenu:7")
  assert_eq(route.decode("bot:rolemenu:7"), 7)
  let legal = @app.App()
  legal.on_component(route, Raw(_ => ()))
  legal.on_modal(route_test_modal("bot:rolemenu"), Raw(_ => ()))
  // Siblings share a prefix without either extending the other at a `:`.
  for id in ["bot:rolemenus", "bot:role", "bot:rolemenu-x"] {
    legal.on_component(
      @app.component_route(id~, state=@app.CustomIdCodec::unit()),
      Raw(_ => ()),
    )
    legal.on_modal(route_test_modal(id), Raw(_ => ()))
  }
  legal.validate()
  for ids in [("bot", "bot:rolemenu"), ("bot:rolemenu", "bot")] {
    for modal in [false, true] {
      let app = @app.App()
      for id in [ids.0, ids.1] {
        if modal {
          app.on_modal(route_test_modal(id), Raw(_ => ()))
        } else {
          app.on_component(
            @app.component_route(id~, state=@app.CustomIdCodec::string()),
            Raw(_ => ()),
          )
        }
      }
      try app.validate() catch {
        @app.AppConfigError::InvalidRouteId(custom_id~, reason~) => {
          assert_eq(custom_id, ids.1)
          assert_true(reason.contains("'\{ids.0}'"))
        }
        error => fail("unexpected error: \{Repr(error)}")
      } noraise {
        _ => fail("expected overlapping route ids")
      }
    }
  }
}

///|
test "strict prefix routes and separate interaction kinds remain legal" {
  let app = @app.App()
  for prefix in ["ticket:", "ticket:close:"] {
    app.on_component_raw(prefix~, _ => ())
    app.on_modal_raw(prefix~, _ => ())
  }
  for id in ["same", "x".repeat(100), "😀".repeat(50)] {
    app.on_component(
      @app.component_route(id~, state=@app.CustomIdCodec::unit()),
      Raw(_ => ()),
    )
    app.on_modal(route_test_modal(id), Raw(_ => ()))
  }
  app.validate()
}
