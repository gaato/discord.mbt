# AWS Lambda Function URL entry point experiment

Function URLs deliver a payload-format 2.0 JSON object. This adapter decodes
the event body into exact bytes before the shared MoonBit handler checks the
Discord signature, then returns a base64-encoded response envelope.

From the repository root:

```fish
moon build --target js --release --deny-warn src/examples/interactions_js
node --test src/examples/lambda_url_echo/adapter.test.mjs
```

Lambda Function URLs have no `waitUntil` equivalent. This adapter waits for
deferred work before returning the envelope, which delays the Discord ACK and
may exceed its deadline. The test covers the JSON boundary locally; it does
not invoke AWS Lambda or verify a deployment bundle.
