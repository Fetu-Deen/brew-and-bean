# Lambda test kit — same for all four paths

Goal: **everyone tests their Lambda on Day 1 without waiting on the real SNS topic or ECS.**
You paste one shared fake event into the Lambda console, confirm your unwrap works,
build your path's job, and only *then* subscribe to the real topic — which "just works"
because the fake event is the exact shape the real topic delivers.

## The shared fake event
[`docs/fake-sqs-event.json`](../docs/fake-sqs-event.json) — a **double-envelope** SQS event
(SQS box → SNS box → the frozen 5-field order). It assumes SNS **Raw Message Delivery is OFF**
(the default). Keep it off on every path or the unwrap breaks.

The order inside is the shared test order, with the API's two generated fields faked in:
```json
{ "orderId": "550e8400-e29b-41d4-a716-446655440000", "customer": "Test Tester",
  "item": "Latte", "size": "M", "timestamp": "2026-06-01T15:04:05Z" }
```

## How to test (every path, identical steps)
1. Lambda console → your function → **Test** tab → new event.
2. Paste the contents of `docs/fake-sqs-event.json`.
3. Click **Test**. Read CloudWatch Logs — confirm the unwrapped `orderId/customer/item/size` print.
4. Build your path's real job (DynamoDB / CloudWatch / S3 / Bedrock).
5. Verify your Definition of Done.
6. **Only now**: subscribe your SQS queue to `arn:aws:sns:us-west-2:269742496681:coffee-shop-orders`
   AND edit the queue access policy to let the topic `SendMessage`. Same shape → no code change.

## The unwrap (the one snippet everyone shares)
```js
const snsEnvelope = JSON.parse(record.body);     // open the SQS box
const order       = JSON.parse(snsEnvelope.Message); // open the SNS box
// order.orderId, order.customer, order.item, order.size, order.timestamp
```
Reusable version: [`_shared/unwrap.mjs`](_shared/unwrap.mjs).

## Per-path stubs
- Path A — [`path-a-persistence/index.mjs`](path-a-persistence/index.mjs) → DynamoDB
- Path B — [`path-b-monitoring/index.mjs`](path-b-monitoring/index.mjs) → CloudWatch
- Path C — [`path-c-writer/index.mjs`](path-c-writer/index.mjs) → S3
- Path D — [`path-d-recommender/index.mjs`](path-d-recommender/index.mjs) → Bedrock
