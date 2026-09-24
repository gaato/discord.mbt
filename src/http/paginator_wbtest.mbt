///|
async test "paginator advances a before cursor and stops on a short page" {
  let seen : Array[Int?] = []
  let calls = Ref(0)
  let paginator = paginator_from_cursor(
    2,
    None,
    (cursor, _limit) => {
      seen.push(cursor)
      calls.val += 1
      match calls.val {
        1 => [3, 2]
        2 => [1]
        _ =>
          raise Validation(message="short page should have ended the paginator")
      }
    },
    page => minimum_cursor(page, value => value),
  )
  debug_inspect(paginator.next_page(), content="Some([3, 2])")
  debug_inspect(paginator.next_page(), content="Some([1])")
  debug_inspect(paginator.next_page(), content="None")
  debug_inspect(seen, content="[None, Some(2)]")
  inspect(calls.val, content="2")
}

///|
async test "paginator empty page is terminal" {
  let calls = Ref(0)
  let paginator = paginator_from_cursor(
    100,
    None,
    (_cursor : Int?, _limit) => {
      calls.val += 1
      []
    },
    page => maximum_cursor(page, value => value),
  )
  debug_inspect(paginator.next_page(), content="None")
  debug_inspect(paginator.next_page(), content="None")
  inspect(calls.val, content="1")
}

///|
async test "paginator after cursor uses the maximum id" {
  let seen : Array[Int?] = []
  let paginator = paginator_from_cursor(
    3,
    Some(1),
    (cursor, _limit) => {
      seen.push(cursor)
      match seen.length() {
        1 => [2, 4, 3]
        _ => []
      }
    },
    page => maximum_cursor(page, value => value),
  )
  debug_inspect(paginator.next_page(), content="Some([2, 4, 3])")
  debug_inspect(paginator.next_page(), content="None")
  debug_inspect(seen, content="[Some(1), Some(4)]")
}

///|
async test "paginator collect truncates without fetching another page" {
  let calls = Ref(0)
  let paginator = paginator_from_cursor(
    3,
    None,
    (_cursor : Int?, _limit) => {
      calls.val += 1
      match calls.val {
        1 => [6, 5, 4]
        2 => [3, 2, 1]
        _ => raise Validation(message="collect max should stop after two pages")
      }
    },
    page => minimum_cursor(page, value => value),
  )
  debug_inspect(paginator.collect(max=4), content="[6, 5, 4, 3]")
  inspect(calls.val, content="2")
  debug_inspect(paginator.next_page(), content="Some([2, 1])")
  inspect(calls.val, content="2")

  let untouched_calls = Ref(0)
  let untouched = paginator_from_cursor(
    1,
    None,
    (_cursor : Int?, _limit) => {
      untouched_calls.val += 1
      [1]
    },
    page => minimum_cursor(page, value => value),
  )
  debug_inspect(untouched.collect(max=0), content="[]")
  inspect(untouched_calls.val, content="0")
}

///|
async test "paginator each visits every remaining item" {
  let calls = Ref(0)
  let visited : Array[Int] = []
  let paginator = paginator_from_cursor(
    2,
    None,
    (_cursor : Int?, _limit) => {
      calls.val += 1
      match calls.val {
        1 => [4, 3]
        2 => [2]
        _ =>
          raise Validation(message="short page should have ended the paginator")
      }
    },
    page => minimum_cursor(page, value => value),
  )
  paginator.each(item => visited.push(item))
  debug_inspect(visited, content="[4, 3, 2]")
  inspect(calls.val, content="2")
}

///|
test "pagination validation is pre-IO" {
  let client = Client("test-token")
  let channel_id : @model.ChannelId = Id(1UL)
  let first : @model.MessageId = Id(2UL)
  let second : @model.MessageId = Id(3UL)
  try client.paginate_messages(channel_id, before=first, after=second) catch {
    Validation(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => raise Validation(message="expected cursor validation")
  }
  try client.paginate_messages(channel_id, page_size=101) catch {
    Validation(_) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => raise Validation(message="expected page size validation")
  }
  client.close()
}
