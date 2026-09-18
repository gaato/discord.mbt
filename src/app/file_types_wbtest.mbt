///|
fn expect_invalid_file_types(
  app : App,
  owner : String,
  reason : String,
) -> Unit raise {
  try app.validate() catch {
    InvalidFileTypes(owner=actual_owner, reason=actual_reason) => {
      inspect(actual_owner, content=owner)
      inspect(actual_reason, content=reason)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an invalid file types error")
  }
}

///|
test "app validation rejects malformed attachment option file types" {
  let too_many = App(sync=Disabled)
  too_many.command(
    slash(
      name="upload",
      description="Upload",
      args=@interaction.Args::of(
        @interaction.arg_attachment(
          name="file",
          description="File",
          file_types=Array::make(11, @model.FileTypeFilter::Image),
        ),
      ),
      handler=Raw(_ => ()),
    ),
  )
  expect_invalid_file_types(too_many, "upload/file", "11 entries (at most 10)")
  let bare_extension = App(sync=Disabled)
  bare_extension.command(
    slash(
      name="upload",
      description="Upload",
      args=@interaction.Args::of(
        @interaction.arg_attachment(name="file", description="File", file_types=[
          Extension("pdf"),
        ]),
      ),
      handler=Raw(_ => ()),
    ),
  )
  expect_invalid_file_types(
    bare_extension, "upload/file", "extension pdf is not dot-prefixed",
  )
  let valid = App(sync=Disabled)
  valid.command(
    slash(
      name="upload",
      description="Upload",
      args=@interaction.Args::of(
        @interaction.arg_attachment(name="file", description="File", file_types=[
          Image,
          Extension(".pdf"),
        ]),
      ),
      handler=Raw(_ => ()),
    ),
  )
  valid.validate()
}

///|
test "app validation rejects malformed modal file field types" {
  let app = App(sync=Disabled)
  app.on_modal(
    modal(
      custom_id="report",
      title="Report",
      fields=ModalFields::of(
        file_field(custom_id="proof", label="Proof", file_types=[Extension("")]),
      ),
    ),
    Raw(_ => ()),
  )
  expect_invalid_file_types(
    app, "report/proof", "extension  is not dot-prefixed",
  )
}

///|
test "modal file field decodes resolved attachments" {
  let fields = ModalFields::map2(
    file_field(custom_id="proof", label="Proof", file_types=[Image]),
    file_field(custom_id="extra", label="Extra").optional(),
    (proof, extra) => (proof.map(a => a.filename), extra),
  )
  let data : @model.ModalData = @json.from_json(
    @json.parse(
      (
        #|{"custom_id":"report","components":[{"type":18,"id":1,"component":{"type":19,"id":2,"custom_id":"proof","values":["111"]}},{"type":18,"id":3,"component":{"type":19,"id":4,"custom_id":"extra","values":[]}}],"resolved":{"attachments":{"111":{"id":"111","filename":"shot.png","size":10,"url":"https://cdn.example/shot.png","proxy_url":"https://media.example/shot.png"}}}}
      ),
    ),
  )
  debug_inspect(
    (fields.decode_)({ components: data.components, resolved: data.resolved, }),
    content=(
      #|(["shot.png"], None)
    ),
  )
  // A value without its resolved attachment is rejected, not silently dropped.
  try
    (fields.decode_)({ components: data.components, resolved: None, }) |> ignore
  catch {
    InvalidArgument(message) =>
      inspect(
        message,
        content="unresolved attachment 111 in modal field: proof",
      )
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected an unresolved attachment error")
  }
}

///|
test "file field emits a label-wrapped file upload with its filter" {
  let handle = modal(
    custom_id="report",
    title="Report",
    fields=ModalFields::of(
      file_field(custom_id="proof", label="Proof", max_values=3, file_types=[
        Image,
        Extension(".pdf"),
      ]).optional(),
    ),
  ).show()
  inspect(
    handle.components_.to_json().stringify(),
    content=(
      #|[{"label":"Proof","component":{"custom_id":"proof","min_values":0,"max_values":3,"required":false,"file_types":["image",".pdf"],"type":19},"type":18}]
    ),
  )
}
