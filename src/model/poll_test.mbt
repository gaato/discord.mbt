///|
test "poll decodes directly and through a message" {
  let poll_fixture =
    #|{
    #|  "question":{"text":"Ship it?"},
    #|  "answers":[
    #|    {"answer_id":1,"poll_media":{"text":"Yes","emoji":{"id":null,"name":"👍"}}},
    #|    {"answer_id":2,"poll_media":{"text":"No"}}
    #|  ],
    #|  "expiry":"2026-08-01T12:00:00Z",
    #|  "allow_multiselect":false,
    #|  "layout_type":1,
    #|  "results":{"is_finalized":false,"answer_counts":[
    #|    {"id":1,"count":7,"me_voted":true},
    #|    {"id":2,"count":2,"me_voted":false}
    #|  ]},
    #|  "future":true
    #|}
  let poll : @model.Poll = @json.from_json(@json.parse(poll_fixture))
  debug_inspect(
    poll,
    content=(
      #|{
      #|  question: { text: Some("Ship it?"), emoji: None },
      #|  answers: [
      #|    {
      #|      answer_id: 1,
      #|      poll_media: {
      #|        text: Some("Yes"),
      #|        emoji: Some(
      #|          {
      #|            id: Some(Null),
      #|            name: Value("👍"),
      #|            animated: None,
      #|            roles: None,
      #|            user: None,
      #|            require_colons: None,
      #|            managed: None,
      #|            available: None,
      #|          },
      #|        ),
      #|      },
      #|    },
      #|    { answer_id: 2, poll_media: { text: Some("No"), emoji: None } },
      #|  ],
      #|  expiry: Value("2026-08-01T12:00:00Z"),
      #|  allow_multiselect: false,
      #|  layout_type: Default,
      #|  results: Some(
      #|    {
      #|      is_finalized: false,
      #|      answer_counts: [
      #|        { id: 1, count: 7, me_voted: true },
      #|        { id: 2, count: 2, me_voted: false },
      #|      ],
      #|    },
      #|  ),
      #|}
    ),
  )
  let message_fixture =
    #|{
    #|  "id":"124000000000000001",
    #|  "channel_id":"41771983423143937",
    #|  "author":{"id":"80351110224678912","username":"Nelly","discriminator":"0","global_name":null,"avatar":null},
    #|  "content":"Vote now","timestamp":"2026-07-14T00:00:00Z",
    #|  "edited_timestamp":null,"tts":false,"mention_everyone":false,
    #|  "mentions":[],"mention_roles":[],"attachments":[],"embeds":[],
    #|  "pinned":false,"type":0,
    #|  "poll":{
    #|    "question":{"text":"Ship it?"},
    #|    "answers":[{"answer_id":1,"poll_media":{"text":"Yes"}}],
    #|    "expiry":null,"allow_multiselect":false,"layout_type":1
    #|  }
    #|}
  let message : @model.Message = @json.from_json(@json.parse(message_fixture))
  assert_true(message.poll is Some(_))
  inspect(
    message.to_json().stringify(),
    content=(
      #|{"id":"124000000000000001","channel_id":"41771983423143937","author":{"id":"80351110224678912","username":"Nelly","discriminator":"0","global_name":null,"avatar":null},"content":"Vote now","timestamp":"2026-07-14T00:00:00Z","edited_timestamp":null,"tts":false,"mention_everyone":false,"mentions":[],"mention_roles":[],"attachments":[],"embeds":[],"pinned":false,"type":0,"poll":{"question":{"text":"Ship it?"},"answers":[{"answer_id":1,"poll_media":{"text":"Yes"}}],"expiry":null,"allow_multiselect":false,"layout_type":1}}
    ),
  )
}

///|
test "poll layout preserves an unknown value" {
  let layout : @model.PollLayoutType = @json.from_json(@json.parse("99"))
  debug_inspect(
    layout,
    content=(
      #|Unknown(99)
    ),
  )
  inspect(
    layout.to_json().stringify(),
    content=(
      #|99
    ),
  )
}
