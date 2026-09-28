///|
test "AppWarning renders stable operator messages" {
  let origin = @app.FailureOrigin::Command(name="echo")
  let error = Failure::Failure("boom")
  inspect(
    @app.AppWarning::AutoDeferFailed(target="command:echo", error~).to_string(),
    content=(
      #|automatic defer failed (command:echo): Failure("boom")
    ),
  )
  inspect(
    @app.AppWarning::InteractionDropped(target="command:echo").to_string(),
    content=(
      #|interaction dropped (command:echo): no handler capacity before the response deadline
    ),
  )
  inspect(
    @app.AppWarning::ErrorResponseWithoutInteraction(summary="plain failure").to_string(),
    content=(
      #|cannot respond to a non-interaction failure: plain failure
    ),
  )
  inspect(
    @app.AppWarning::ErrorResponseExpired(summary="late reply").to_string(),
    content=(
      #|cannot respond to an expired interaction: late reply
    ),
  )
  inspect(
    @app.AppWarning::MalformedInteraction(origin~, reason="bad payload").to_string(),
    content=(
      #|malformed interaction (Command(name="echo")): bad payload
    ),
  )
  inspect(
    @app.AppWarning::UnhandledFailure(origin~, error~).to_string(),
    content=(
      #|unhandled app failure (Command(name="echo")): Failure("boom")
    ),
  )
  inspect(
    @app.AppWarning::ErrorPolicyFailed(error~).to_string(),
    content=(
      #|error policy failed: Failure("boom")
    ),
  )
  inspect(
    @app.AppWarning::AutocompleteTruncated(
      command_path="admin/user",
      option="name",
      count=26,
    ).to_string(),
    content=(
      #|autocomplete choices truncated for command path admin/user, option name: 26 choices exceeds the limit of 25
    ),
  )
  inspect(
    @app.AppWarning::HandlerFailed(target="command:echo", error~).to_string(),
    content=(
      #|framework handler failed (command:echo): Failure("boom")
    ),
  )
  inspect(
    @app.AppWarning::WaiterUnavailable.to_string(),
    content=(
      #|component waiting is unavailable without a gateway connection
    ),
  )
  inspect(
    @app.AppWarning::InteractionProcessingFailed(error~).to_string(),
    content=(
      #|interaction processing failed: Failure("boom")
    ),
  )
  inspect(
    @app.AppWarning::Executor(source="gateway", message="gateway warning").to_string(),
    content=(
      #|gateway warning
    ),
  )
}
