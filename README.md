# Brew & Bean — Team Documentation

**Event-driven coffee-ordering app · 6-person bootcamp capstone · Final demo: Saturday, June 13**

> **Let's read this whole page once before we touch AWS.** Then we'll jump to *your* task section and follow it.

---

## What we're building (the one-paragraph version)

A customer places a coffee order in a web page. The order hits our **API** (running in a container on ECS Fargate). The API drops the order onto a single **SNS topic** and immediately confirms the order. From that one topic, the order **fans out to four independent paths at the same time** — one saves it, one counts it, one files it away for analytics, one asks an AI what the customer might like next time — plus an email notification. None of the four paths knows the others exist. *That decoupling is the whole point of the project.*

```
                        Web page (React on S3/or runs locally for demo)
                                │  places order
                                ▼
                    API container (ECS Fargate, behind an ALB)
                                │  publishes ONE message
                                ▼
                        SNS topic: coffee-shop-orders
                                │  fans out to everyone
        ┌───────────────┬───────────────┬───────────────┬──────────── Email
        ▼               ▼               ▼               ▼            (direct
   SQS → Lambda     SQS → Lambda    SQS → Lambda    SQS → Lambda   subscription)
        │               │               │               │
   Path A          Path B          Path C          Path D
   DynamoDB        CloudWatch      S3 → Glue →     Bedrock AI
   (saves it)      (counts it)     Athena          ("next time
                                   (analytics)      try…")
```

---

## Confirmed decisions (do not change these without telling the whole team)

| Decision | The call | Why it matters |
|---|---|---|
| **AWS account** | One shared account, everyone has their own login | The four paths must subscribe to the same SNS topic, so they live in one account. |
| **Region** | **`us-west-2` (Oregon)** — everywhere, no exceptions | Wrong region = "it works but I can't see it." Oregon has full Bedrock/Claude support. |
| **Account ID** | `269742496681` | Appears in every ARN. |
| **Naming** | Use the exact names in this doc | Mismatched names break the wiring between services. |
| **IAM role names** | **must start with `bb-`** | Your login is only allowed to create roles named `bb-*` (see GitHub/IAM section). |
| **Tags** | Tag every resource: `Project=brew-and-bean`, `Owner=<your-name>` | So we know who made what and can clean up safely. |
| **Secrets** | **No AWS access keys** in the repo, in chat, or in screenshots. Ever. | The `.gitignore` covers `.env`. |

---

## The Golden Rules (memorize these — they save hours)

1. **Most failures are IAM.** If a service "does nothing," it's usually missing a permission. Check the role.
2. **The answer is always in CloudWatch Logs.** Every Lambda and the ECS task write logs there. When something fails silently, read the logs *first*.
3. **Verify the previous step before building on it.** Don't build a Lambda before confirming its SQS queue gets messages. Don't build Athena before confirming S3 has files.
4. **Everything in `us-west-2`.** If you don't see your resource, check the region selector in the top-right corner of the console.

---

## The Message Contract (FROZEN — every path depends on this)

The API publishes **exactly this shape** to SNS. 

```json
{
  "orderId":   "550e8400-e29b-41d4-a716-446655440000",
  "customer":  "string — customer name",
  "item":      "string — e.g. Latte, Cappuccino, Cold Brew",
  "size":      "string — S | M | L",
  "timestamp": "2026-06-01T15:04:05Z"
}
```

- **The API creates `orderId` (a uuid) and `timestamp` before publishing.** Path owners do **not** generate their own — that way DynamoDB, S3, CloudWatch, and Bedrock all reference the *same* order.
- **Two shapes, don't confuse them:** the frontend sends the **3-field** order below; the API adds `orderId`+`timestamp`; SNS then carries all **5 fields**. Your Lambda receives all five — **read them, never regenerate them.**
- **Shared test order** everyone uses, so results are comparable:

```json
{ "customer": "Test Tester", "item": "Latte", "size": "M" }
```

### Delivery setting (don't change this) — why you "unwrap a double envelope"

SQS subscriptions use **default delivery — Raw Message Delivery stays OFF.** That means your order arrives wrapped twice: the **SQS** record wraps the **SNS** envelope, which wraps your **order** (each as a string). So every path unwraps with two parses:

```js
const order = JSON.parse(JSON.parse(record.body).Message);
// → order.orderId, order.customer, order.item, order.size, order.timestamp
```

If anyone turns Raw Message Delivery **ON**, they'd get a single envelope and this shared snippet breaks for them — so **leave it off on every path.**


---

## 🔎 Find Your Task

| Section | Owner | You build… |
|---|---|---|
| [ECS Backbone](#ecs-backbone) |  One/two members | The API container, ECR, ECS, the load balancer |
| [Path A — Persistence](#path-a--persistence) | — | DynamoDB + SQS + Lambda (saves orders) |
| [Path B — Monitoring](#path-b--monitoring) | — | SQS + Lambda + CloudWatch metrics & dashboard |
| [Path C — Analytics](#path-c--analytics) | — | S3 + SQS + Lambda + Glue + Athena |
| [Path D — AI Recommender](#path-d--ai-recommender) | — | SQS + Lambda + Bedrock + a recommendations table |
| [React Deploy](#react-deploy) | — | The web page, deployed to S3 |

**When can you start?** The ECS Backbone and React UI can start on **Day 1**. The four paths need the **SNS topic to exist** before they can do their *live* test — but you can build and unit-test your Lambda against a fake event immediately, so nobody sits idle. Each section says exactly what you can do now vs. what waits.

---

## How we collaborate on GitHub

One repo: `brew-and-bean`. AWS resources are clicked in the console; the repo holds **code, queries, IAM policy files, and this documentation.**

```
brew-and-bean/
├── README.md                 ← team documentation (this file)
├── .gitignore                ← .env, *.pem, credentials, node_modules
├── docs/
│   ├── message-contract.md
│   └── iam-policies/
├── api/                      ← server.mjs, Dockerfile, package.json
├── lambdas/
│   ├── path-a-persistence/
│   ├── path-b-monitoring/
│   ├── path-c-writer/
│   └── path-d-recommender/
├── analytics/                ← glue-table notes, athena-queries.sql
└── frontend/                 ← React app
```

**The flow (everyone follows this):**

1. `main` is **protected** — no one pushes to it directly.
2. Make your own branch: `git checkout -b feature/p3-path-a` (use your path).
3. Commit and push to *your* branch.
4. Open a **Pull Request** on GitHub, request someone as reviewer.
5. That person reviews and merges into `main`.
6. Before starting new work, pull the latest `main` so you're not behind.

**The daily git loop** (copy this):

```bash
git checkout main && git pull          # get the latest
git checkout -b feature/your-task      # (first time) or: git checkout feature/your-task
# ... do your work ...
git add .
git commit -m "clear message about what you did"
git push -u origin feature/your-task
# then open a Pull Request on github.com
```

---

## The Board (GitHub Projects)

We use **GitHub Projects** — not Trello — because it lives next to the repo: cards become issues and link to branches and PRs, and can move automatically as work progresses. **One board, not two**, or tasks drift out of sync.

**Set it up:** Repo → **Projects** tab → **New project** → **Board** template.

**Columns:** **Backlog → Blocked (waiting on a dependency) → In Progress → In Review (PR open) → Done**

**Automate it (optional, worth it):** in the Project's **Workflows**, enable the built-in rules so the board tracks real activity without manual dragging — e.g. *item added → Backlog*, *PR opened → In Review*, *PR merged → Done*.

Use **Blocked** honestly — a card there should say *what* it's waiting on, e.g. "Waiting on: SNS topic ARN." That's how we make "we'll wait for each other at the right moments" visible instead of silent.

**Full setup + the ready-to-paste cards:** see [docs/board-setup.md](docs/board-setup.md) — it explains the board (our Trello equivalent), the columns, the automations, and has one starter card per task.

---

## Free Tier survival (we do NOT want a surprise bill)

Most of this stack is free-tier friendly (Lambda, SNS, SQS, S3, DynamoDB on-demand, ECR for 12 months, Athena is pennies). A few pieces are **not free** and run quietly:

| Service | Reality | What we do |
|---|---|---|
| **Application Load Balancer** | ~$0.55–0.75/day, **not free tier**, 24/7 | Acceptable for two weeks (~$10–15) **if we delete it the day after the demo.** |
| **Fargate task** | ~$0.30/day, **not free tier** | **Scale the ECS service to 0 tasks overnight/weekends** when nobody's testing; back to 1 when we resume. |
| **QuickSight** | ~$9/user/month after trial | **Skippable.** Athena query results already prove the analytics path. Only use it on the free trial. |
| Bedrock (Haiku) | Pennies per project | Fine. |

**A $10 budget alert is set.**

---
---

# ECS Backbone
**Owner: One person here/or two if needed · This is the critical path — everyone else waits on the SNS topic, which sits behind this.**

### What you build
The API is the brain. It receives orders, generates the `orderId` + `timestamp`, publishes to SNS, and exposes a `/recommendation` endpoint the frontend polls. It runs as a Docker container on ECS Fargate, behind an Application Load Balancer.

### Start now
Write and test the API locally (`node server.mjs`) and the Dockerfile on **Day 1**. If it doesn't run locally, it won't run in ECS.

### Build order (each step depends on the one above)
1. **IAM roles first.** `bb-ecs-execution-role` (lets ECS pull the image + write logs → attach `AmazonECSTaskExecutionRolePolicy`) and `bb-ecs-task-role` (your running code's permissions — starts empty, gains `sns:Publish` and later `bedrock:InvokeModel`).
2. **ECR repository** `brew-and-bean-coffee-api` (Private). This is where the Docker image lives in AWS.
3. **Build & push the image** (the four `docker` commands — see the Lead Guide for what each does).
4. **ECS cluster** `brew-and-bean-cluster`, infrastructure = AWS Fargate.
5. **ALB + Target Group** *before* the service (the service needs a target group to register into). Target type **IP** (required for Fargate), port **3000**, health check path **/health**, listener on port 80 → forward to the target group. **Note the ALB DNS name — the frontend needs it.**
6. **Task Definition** `brew-and-bean-coffee-api`, Fargate, 0.25 vCPU / 0.5 GB, both IAM roles attached, container port 3000, CloudWatch logging on.
7. **ECS Service** `brew-and-bean-service`, 1 task, in the default VPC across the subnets, **public IP on**, security group allowing inbound HTTP 3000, attached to the ALB + target group.

### IAM this section needs
- `bb-ecs-execution-role` → `AmazonECSTaskExecutionRolePolicy`
- `bb-ecs-task-role` → `sns:Publish` on `arn:aws:sns:us-west-2:269742496681:coffee-shop-orders` (add when SNS exists), plus `bedrock:InvokeModel` on `*` later.

### CORS note (important once the frontend is on S3)
The API must send an `Access-Control-Allow-Origin` header, or the deployed S3 page can't call it. Coordinate with the React Deploy owner.

### Definition of Done
- The ALB DNS name opens and `/health` returns green.
- A test order returns a success response.
- The ECS task's logs appear in CloudWatch.

---

# Path A — Persistence
**SNS → SQS → Lambda → DynamoDB. You save every order.**

### Start now
Write the Lambda and test it against a fake SQS event locally/in the console. You only need SNS live for the *integration* test.

### Build order
1. **DynamoDB table** `coffee-orders`, partition key `orderId` (String), on-demand capacity (free-tier friendly). *(If we add the AI recommender's history lookup, also add a GSI with partition key `customer` — coordinate with Path D.)*
2. **SQS queue** `coffee-process-queue`, Standard, visibility timeout 30s.
3. **Subscribe the queue to SNS** (protocol Amazon SQS, endpoint = the queue ARN). Then **edit the queue's access policy** to allow the SNS topic to `SendMessage` to it — without this, messages never arrive.
4. **Lambda** `coffee-processor`, Node.js 22.x, role `bb-lambda-path-a-role`. Code: unwrap the double envelope → take `orderId, customer, item, size, timestamp` → write to DynamoDB.
5. **Add the SQS trigger** to the Lambda (batch size 1).

### IAM this section needs
`bb-lambda-path-a-role` → `dynamodb:PutItem` on `arn:aws:dynamodb:us-west-2:269742496681:table/coffee-orders` (plus the basic Lambda logging policy so it can write to CloudWatch).

### Definition of Done
A test order → a matching item appears in `coffee-orders` with the same `orderId` the API generated.

---

# Path B — Monitoring
**SNS → SQS → Lambda → CloudWatch. You count and visualize orders.**

### Start now
Write the Lambda against a fake event; build the dashboard once metrics exist.

### Build order
1. **SQS queue** `coffee-analytics-queue`, Standard.
2. **Subscribe to SNS** + **edit the queue access policy** (same pattern as Path A).
3. **Lambda** `coffee-analytics`, Node.js 22.x, role `bb-lambda-path-b-role`. Code: unwrap the order → call `PutMetricData` with namespace `CoffeeShop`, metric `OrdersPlaced`, dimensions for drink type and size.
4. **Add the SQS trigger.**
5. **Build a CloudWatch dashboard** showing `OrdersPlaced` over time and by drink type. *(Stretch: add a CloudWatch Alarm — see the future-integrations table.)*

### IAM this section needs
`bb-lambda-path-b-role` → `cloudwatch:PutMetricData` on `"*"`. **It must be `*`** — this action cannot be scoped to a specific ARN. (Plus the basic Lambda logging policy.)

### Definition of Done
A test order → a data point appears under **Metrics → CoffeeShop → OrdersPlaced**, and the dashboard renders it.

---

# Path C — Analytics
**SNS → SQS → Lambda → S3 → Glue → Athena (→ QuickSight, optional). You turn orders into queryable analytics.**

### Start now
Write the S3-writer Lambda against a fake event. Glue/Athena wait until S3 actually has files.

### Build order
1. **S3 bucket** `brew-and-bean-orders-<yourname>` (globally unique), region us-west-2, block all public access ON. Create two prefixes: `orders/` (Lambda writes here) and `athena/` (Athena writes results here).
2. **SQS queue** `coffee-s3-queue` + **subscribe to SNS** + **edit access policy** (same pattern).
3. **Lambda** `coffee-s3-writer`, Node.js 22.x, role `bb-lambda-path-c-role`. Code: unwrap the order → write JSON to S3 with a **Hive-style partitioned key**: `orders/year=2026/month=06/day=01/<uuid>.json`.
4. **Add the SQS trigger.**
5. **Glue database** `coffee_db` + **table** `coffee_orders` (created manually, data store = S3, path `s3://.../orders/`, format JSON). Columns: `orderId, customer, item, size, timestamp` (all string). Partition keys: `year, month, day` (all string).
6. **Athena**: set the query-result location to `s3://.../athena/`, run `MSCK REPAIR TABLE coffee_db.coffee_orders` to register partitions, then test:
   ```sql
   SELECT item, COUNT(*) AS total
   FROM coffee_db.coffee_orders
   GROUP BY item ORDER BY total DESC;
   ```
7. **(Optional) QuickSight** — only on the free trial. Athena results alone are enough to demo this path.

### IAM this section needs
`bb-lambda-path-c-role` → `s3:PutObject` on `arn:aws:s3:::brew-and-bean-orders-<yourname>/orders/*` (plus the basic Lambda logging policy).

### Definition of Done
A test order → a JSON file appears at the partitioned path, and the Athena `GROUP BY item` query returns rows.

---

# Path D — AI Recommender
**SNS → SQS → Lambda → Bedrock → recommendations table. You suggest what a returning customer might like next time.**

This path runs **asynchronously** — it does not block the order. It looks the customer up by name (no accounts), reads their past orders, and asks Bedrock for one *new-but-related* suggestion. First-time customers (no history) fall back to a suggestion based on their current order.

### Start now
Write the Lambda logic against a fake event. The Bedrock model access request can take minutes to hours, so **request it early.**

### Build order
1. **Request model access**: Bedrock console (us-west-2) → Model access → request **Claude Haiku**. Wait for approval.
2. **Recommendations table** `coffee-recommendations`, partition key `customer` (String). Stores each customer's latest "next time" suggestion.
3. **(Coordinate with Path A)** add a **GSI on `coffee-orders`** with partition key `customer`, so you can query a customer's history.
4. **SQS queue** `coffee-reco-queue` + **subscribe to SNS** + **edit access policy** (same pattern).
5. **Lambda** `coffee-recommender`, Node.js 22.x, role `bb-lambda-path-d-role`. Code: unwrap the order → `Query` the GSI for this customer's past orders → build a prompt (history + current order, constrained to our menu, asking for ONE new related item + a one-line reason) → call Bedrock (model `us.anthropic.claude-haiku-4-5-20251001-v1:0`) → write the result to `coffee-recommendations`.
6. **Add the SQS trigger.**
7. The frontend polls `GET /recommendation?customer=<name>` (served by the API) until the suggestion appears.

### IAM this section needs
`bb-lambda-path-d-role` → `dynamodb:Query` on the orders table **and its index**, `dynamodb:PutItem` on `coffee-recommendations`, and `bedrock:InvokeModel` on `"*"` (inference-profile ARNs can't be scoped predictably). Plus the basic Lambda logging policy.

### Definition of Done
A returning customer's test order → a "next time, try…" suggestion lands in `coffee-recommendations` and is retrievable via the API.

---

# React Deploy
**The web page, built in React and deployed to S3 static hosting (not opened locally).**

### Start now
Build the **entire UI against a mock/local API** on Day 1. Swap in the real ALB URL once the backbone is up — so you're never blocked-idle.

### Build order
1. **Build the React app** (Vite). An order form (customer, item, size) + a success message + an amber box that shows the AI "next time" suggestion. After placing an order, **poll** `GET /recommendation?customer=<name>` every ~2s until the suggestion appears.
2. **Point it at the API**: set the API base URL to the **ALB DNS name** (from the ECS Backbone owner).
3. **Build for production** (`npm run build`) and **upload the build output to an S3 bucket** with static website hosting enabled.
4. **Test end-to-end** in the browser.

### Two things that will bite you (handle them early)
- **CORS**: the API must allow your S3 site's origin (coordinate with the Backbone owner).
- **Mixed content**: keep the page on the **S3 website endpoint (HTTP)** so it can call the HTTP ALB. If we add CloudFront (HTTPS) later, the HTTP ALB becomes a problem — that's a stretch item, not for the core demo.

### Definition of Done
Placing an order from the deployed S3 page shows the green success message and, a few seconds later, the amber "next time" suggestion.

---

## Troubleshooting — ask yourself these three, in order

1. **Does this service have the IAM permission it needs?** Most failures are IAM.
2. **Did I read the CloudWatch logs?** Every Lambda and ECS task logs there. Silent failure → the answer is in the logs.
3. **Did I verify the previous step?** Confirm SQS receives messages before blaming the Lambda; confirm S3 has files before touching Athena.

---

## End-to-end test (the proof it all works)

Place one order from the deployed page and verify **all** of these:

- ✅ Green success message appears
- ✅ Amber "next time" suggestion appears (~2–3s later)
- ✅ Email arrives in the inbox
- ✅ DynamoDB has a new item (Path A)
- ✅ A new CloudWatch metric data point (Path B)
- ✅ A new partitioned JSON file in S3 (Path C)
- ✅ The Athena query shows the order (Path C)
- ✅ A suggestion row in `coffee-recommendations` (Path D)
- ✅ The ECS task logs show the publish succeeded

---

## Future integrations (only if we have time — each layers onto an existing path, no new roles)

| Integration | Layers onto | Owner | Watch out for |
|---|---|---|---|
| **CloudWatch alarm** | Path B (monitoring) | Path B owner | Easy + high-impact. Wire alarm → SNS → email for a clean closed loop in the demo. |
| **AWS Backup plan** | Path A (DynamoDB) | Path A owner | Easy, basically free at our data size. |
| **QuickSight** | Path C (analytics) | Path C owner | Costs ~$9/user after trial — only on the free trial. Athena alone already proves the path. |
| **CloudFront** | React/S3 frontend | React owner | **Mixed-content trap**: CloudFront is HTTPS, the ALB is HTTP — an HTTPS page can't call an HTTP API. Would need HTTPS on the ALB too. True stretch, not core. |
| **AWS Config** | governance (whole account) | Admin | Has its own per-item cost that creeps — enable selectively, turn off after the demo. |
| **CloudFormation / CodePipeline** | *post-project* | — | Infrastructure-as-code + CI/CD. Out of scope for these two weeks; planned as self-study after our bootcamp. |

Some additional features to be added on:

-->DLQ (Dead-Letter Queue) — A backup queue that catches messages our Lambdas fail to process. SQS retries a failed message a few times; if it still won't process (bad data, a bug, Bedrock down), it lands in the DLQ instead of looping forever or vanishing. Why we need it: so a failed Bedrock recommendation doesn't silently drop the message — we keep it, inspect it, and replay it once fixed. It's our safety net for the async paths.

-->X-Ray — Distributed tracing. It tags each request and follows it across every hop (API → Fargate → SNS → SQS → Lambdas → DynamoDB/Bedrock), giving us a service map and a per-request timeline. Why we need it: when something is slow or broken, it shows us which hop, instead of us hand-stitching five CloudWatch log groups by timestamp. It's the difference between "something's wrong" and "the Bedrock call is taking 4 seconds."

-->AWS WAF (Web Application Firewall) — A filter that sits in front of our ALB/CloudFront and blocks malicious traffic (SQL injection, bad bots, rate-floods) before it reaches our app. Why we need it: our ordering API is internet-facing, so WAF is the front door bouncer that stops common attacks and abusive request volume hitting Fargate.
