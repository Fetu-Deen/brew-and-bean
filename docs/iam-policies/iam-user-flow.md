
Welcome! The backbone is already live: an order hits our API → publishes to one **SNS topic** (`coffee-shop-orders`). Your job is to hang **your path** off that topic: `SNS → your SQS queue → your Lambda → your destination`. This checklist gets you from "new login" to "my path works."

You can't break the shared backbone — your permissions block it — so build freely.

---

## 1. Sign in & secure your account ☐
- ☐ Sign-in URL: **`https://269742496681.signin.aws.amazon.com/console`**
- ☐ Username = your first name (e.g. `sintayehu`); use the temp password Fatu gave you.
- ☐ **Change your password** when prompted.
- ☐ **Turn on MFA** immediately: top-right name → *Security credentials* → *Multi-factor authentication* → assign (use an authenticator app). Non-negotiable.

## 2. Set your region ☐
- ☐ Top-right region selector → **US West (Oregon) `us-west-2`**. **Everything** we build is here. Wrong region = "it works but I can't see it." Check this on every screen.

## 3. Ground rules (read once)
- **Don't rename/delete shared stuff** — the SNS topic, ECS/ALB, the VPC, `coffee-orders`/`coffee-recommendations`, ECR. (Your IAM will refuse anyway.)
- **Name everything for your path** so ownership is obvious — e.g. `coffee-analytics-queue` / `coffee-analytics` (Path B), `coffee-s3-queue` / `coffee-s3-writer` (Path C).
- **Your Lambda role must start with `bb-`** (e.g. `bb-lambda-path-b-role`) — that's what your permissions let you create.
- **One SNS setting matters:** keep **Raw Message Delivery OFF** on your subscription (the default). It keeps the message shape consistent for everyone.

## 4. The message contract (FROZEN — don't change it)
Every order your Lambda receives is this shape:
```json
{ "orderId": "...", "customer": "Test Tester", "item": "Latte", "size": "M", "timestamp": "2026-06-01T15:04:05Z" }
```
The API already generates `orderId` + `timestamp` — you never make your own.

## 5. Test your Lambda with the fake event FIRST ☐ (no AWS wiring needed)
This is how you build on Day 1 without waiting on anything:
- ☐ Open your stub: `lambdas/path-b-monitoring/index.mjs` (B) or `lambdas/path-c-writer/index.mjs` (C).
- ☐ Lambda console → create your function (Node.js 22.x, role `bb-lambda-path-*-role`) → paste the stub.
- ☐ **Test tab → paste `docs/fake-sqs-event.json` → Test.** Confirm CloudWatch logs print the right `orderId / customer / item / size`.

The unwrap is the same for everyone (double envelope: SQS box → SNS box → order):
```js
const snsEnvelope = JSON.parse(record.body);       // open the SQS box
const order       = JSON.parse(snsEnvelope.Message); // open the SNS box
// order.orderId, order.customer, order.item, order.size, order.timestamp
```

## 6. Build your path's job
- **Path B (Sintayehu) — Monitoring:** publish a CloudWatch metric per order (namespace `CoffeeShop`, e.g. `OrdersPlaced`), then build a dashboard. Role needs `cloudwatch:PutMetricData`.
- **Path C (Demel) — Analytics:** write each order as JSON to S3 under `orders/year=…/month=…/day=…/`, then Glue table → Athena query. Role needs `s3:PutObject` on your bucket.

## 7. Wire it to the real topic ☐ (only after your unwrap works)
Follow the Path A recipe in **`docs/05-path-a-persistence.md`** — it's identical, just your names:
- ☐ Create your **SQS queue**.
- ☐ **Subscribe** the queue to `arn:aws:sns:us-west-2:269742496681:coffee-shop-orders` (Raw Delivery **OFF** — this auto-adds the queue's access policy).
- ☐ Add the **SQS trigger** to your Lambda.
- ☐ Place a test order and confirm your destination gets the data. ✅ (Ask Fatu to place one, or use the ALB URL.)

## 8. Don't blow the budget ☐
- Lambda / SNS / SQS / DynamoDB / S3 cost ~nothing at rest — fine to leave.
- Avoid anything always-on (no NAT gateways, no extra load balancers, don't run a Glue **crawler** on a schedule — make the table manually).
- If you spin up anything pricey, tear it down when done.

## 9. Where things live / who to ask
- **Step docs:** `docs/00` → `06` (networking, image, ECS, SNS, Path A, Path D).
- **Lambda test kit + stubs:** `lambdas/README.md` and your `lambdas/path-*/` folder.
- **Stuck?** Most failures are **IAM** or **networking**, and the answer is in **CloudWatch Logs**. Then ping **Fatu** (lead).

> Definition of done for your path: a test order → your metric/file/row shows up, referencing the same `orderId`. 🎉
