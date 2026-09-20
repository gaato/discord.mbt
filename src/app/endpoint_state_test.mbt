///|
async test "deadline races preserve every accepted capture" {
  let client = @dhttp.Client("test-token")
  defer client.close()
  let timings = [(0, 0), (1, 1), (0, 10), (10, 0)]
  for _attempt in 0..<4 {
    for (delay, deadline) in timings {
      let app = @app.App()
      let states : @aqueue.Queue[@framework.ResponseState] = Queue(
        kind=Unbounded,
      )
      let warnings : Array[String] = []
      app.on_warn(message => warnings.push(message))
      app.command(
        @app.slash(
          name="racing",
          description="Race the callback deadline",
          args=@interaction.Args::unit(),
          handler=Raw(raw => {
            @async.sleep(delay)
            raw.respond(content="captured")
            states.put(raw.response_state())
          }),
        ),
      )
      app.error_policy((ctx, error) => {
        assert_true(error is @framework.ResponseGateError::Expired)
        states.put(ctx.response_state().unwrap())
      })
      @async.with_task_group(group => {
        let endpoint = app.serve(
          group,
          client~,
          application_id=@model.Id::parse("400000000000000001"),
        )
        let outcome = @async.with_timeout(1000, () => {
          endpoint.handle_interaction(
            app_command("racing", "500000000000000811"),
            deadline_ms=deadline,
          )
        })
        match @async.with_timeout(1000, () => states.get()) {
          Sent(ChannelMessageWithSource) => {
            guard outcome is Reply(response~, ..) else {
              fail("accepted capture was lost: \{Repr(outcome)}")
            }
            json_inspect(response.to_json(), content={
              "type": 4,
              "data": { "content": "captured" },
            })
          }
          Expired => assert_true(outcome is TimedOut)
          state => fail("unexpected gate state: \{Repr(state)}")
        }
        assert_eq(warnings, [])
      })
    }
  }
}
