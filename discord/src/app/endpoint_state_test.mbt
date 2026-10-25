///|
/// How one racing interaction ended, as the handler, the error policy, or the
/// warning hook saw it.
priv enum RaceEnd {
  Gate(@framework.ResponseState)
  Warned(@app.AppWarning)
} derive(Debug)

///|
async test "deadline races preserve every accepted capture" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  // On virtual time each timing plays out one fixed interleaving; ties fire
  // in the order the timers were registered.
  let timings = [(0, 0), (1, 1), (0, 10), (10, 0)]
  for (delay, deadline) in timings {
    let clock = @netruntime.VirtualClock()
    let app = @app.AppBuilder()
    let ends : Array[RaceEnd] = []
    app.on_warn(warning => ends.push(Warned(warning)))
    app.command(
      @app.slash(
        name="racing",
        description="Race the callback deadline",
        args=@interaction.Args::unit(),
        handler=Raw(raw => {
          (clock : &@hclock.Clock).sleep(delay)
          raw.respond(content="captured")
          ends.push(Gate(raw.response_state()))
        }),
      ),
    )
    app.error_policy((ctx, error) => {
      assert_true(error is @framework.ResponseGateError::Expired)
      ends.push(Gate(ctx.response_state().unwrap()))
    })
    @async.with_task_group(group => {
      let endpoint = app
        .build()
        .serve(
          group,
          access=Client(client),
          application_id=@model.Id::parse("400000000000000001"),
          clock~,
        )
      let handling = group.spawn(() => {
        endpoint.handle_interaction(
          app_command("racing", "500000000000000811"),
          deadline_ms=deadline,
        )
      })
      clock.settle(until=() => !ends.is_empty() || clock.pending().length() == 2)
      if ends.is_empty() {
        assert_true(clock.advance_to_next())
        clock.settle(until=() => !ends.is_empty())
      }
      let outcome = handling.wait()
      match ends {
        [Gate(Sent(ChannelMessageWithSource))] => {
          guard outcome is Reply(response~, ..) else {
            fail("accepted capture was lost: \{Repr(outcome)}")
          }
          json_inspect(response.to_json(), content={
            "type": 4,
            "data": { "content": "captured" },
          })
        }
        [Gate(Expired)] => assert_true(outcome is TimedOut)
        // The window closed before the handler could start.
        [Warned(InteractionDropped(target="command:racing"))] =>
          assert_true(outcome is TimedOut)
        ends => fail("unexpected ends: \{Repr(ends)}")
      }
    })
  }
}

///|
async test "serve looks up the application id when it is not given" {
  let lookups = Ref(0)
  let client = @dhttp.Client::offline(request => {
    lookups.val += 1
    assert_true(request.route is GetCurrentApplication)
    {
      status: 200,
      headers: Map([]),
      body: {
        "id": "400000000000000001",
        "name": "app",
        "icon": null,
        "description": "",
        "bot_public": true,
        "bot_require_code_grant": false,
        "verify_key": "key",
        "team": null,
      },
    }
  })
  defer client.close()
  @async.with_task_group(group => {
    @app.AppBuilder().build().serve(group, access=Client(client)) |> ignore
  })
  assert_eq(lookups.val, 1)
}
