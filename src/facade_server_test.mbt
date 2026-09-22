///|
async test "root facade serves HTTP interactions and rejects unsigned requests" {
  @async.with_timeout(5000, () => {
    let client = @discord.Client::offline(_ => {
      fail("unsigned requests must not reach Discord REST")
    })
    defer client.close()
    @async.with_task_group(group => {
      let server : @discord.InteractionsServer = @discord.serve_interactions(
        group,
        @discord.App(),
        addr="127.0.0.1:0",
        public_key="d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
        client~,
        application_id=@model.Id::parse("400000000000000001"),
      )
      defer server.close()
      let request = @ahttp.Client("http://\{server.addr()}")
      defer request.close()
      request.request(Post, "/")
      assert_eq(request.end_request().code, 401)
    })
  })
}
