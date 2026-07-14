///|
async test "exported two-promise flow returns echo then completes background" {
  let body =
    #|{
    #|  "id": "500000000000000201",
    #|  "application_id": "400000000000000001",
    #|  "type": 2,
    #|  "token": "interaction-token",
    #|  "version": 1,
    #|  "data": {
    #|    "id": "600000000000000201",
    #|    "name": "echo",
    #|    "type": 1,
    #|    "options": [
    #|      {"name": "text", "type": 3, "value": "hello from Workers"}
    #|    ]
    #|  }
    #|}
  let dispatch = start_interaction("test-token", body)
  let response = dispatch.response().wait()
  inspect(response.kind(), content="Reply")
  inspect(
    response.body(),
    content=(
      #|{"type":4,"data":{"content":"hello from Workers"}}
    ),
  )
  dispatch.background().wait()
}
