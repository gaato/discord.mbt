///|
async test "exported two-promise flow returns echo then completes background" {
  let body =
    #|{
    #|  "id": "500000000000000201",
    #|  "application_id": "400000000000000001",
    #|  "type": 2,
    #|  "token": "interaction-token",
    #|  "version": 1,
    #|  "user": {
    #|    "id": "200000000000000001",
    #|    "username": "nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "data": {
    #|    "id": "600000000000000201",
    #|    "name": "echo",
    #|    "type": 1,
    #|    "options": [
    #|      {"name": "text", "type": 3, "value": "hello from Workers"}
    #|    ]
    #|  }
    #|}
  let controller = @js_async.AbortController::new()
  let dispatch = start_interaction(
    "test-token",
    body,
    "https://discord.com",
    controller.signal(),
  )
  let response = dispatch.response().wait()
  inspect(response.kind(), content="Reply")
  inspect(response.content_type(), content="application/json")
  inspect(
    response.body(),
    content=(
      #|{"type":4,"data":{"content":"hello from Workers"}}
    ),
  )
  dispatch.background().wait()
}

///|
async test "structurally invalid interaction is an explicit client error" {
  let controller = @js_async.AbortController::new()
  let dispatch = start_interaction(
    "test-token",
    "{\"type\":2}",
    "https://discord.com",
    controller.signal(),
  )
  let response = dispatch.response().wait()
  inspect(response.kind(), content="InvalidPayload")
  dispatch.background().wait()
}

///|
async test "file reply exposes multipart metadata" {
  let body =
    #|{
    #|  "id": "500000000000000202",
    #|  "application_id": "400000000000000001",
    #|  "type": 2,
    #|  "token": "interaction-token",
    #|  "version": 1,
    #|  "user": {
    #|    "id": "200000000000000001",
    #|    "username": "nelly",
    #|    "discriminator": "0",
    #|    "global_name": "Nelly",
    #|    "avatar": null
    #|  },
    #|  "data": {
    #|    "id": "600000000000000202",
    #|    "name": "file",
    #|    "type": 1
    #|  }
    #|}
  let controller = @js_async.AbortController::new()
  let dispatch = start_interaction(
    "test-token",
    body,
    "https://discord.com",
    controller.signal(),
  )
  let response = dispatch.response().wait()
  inspect(response.kind(), content="Reply")
  assert_true(
    response.content_type().has_prefix("multipart/form-data; boundary="),
  )
  dispatch.background().wait()
}
