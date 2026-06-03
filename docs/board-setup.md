# The Board — our task tracker (GitHub Projects)

We track all work on **one GitHub Projects board**. 

## It's our Trello

GitHub Projects is GitHub's built-in equivalent of **Trello**. Has same drag-cards-across-columns idea. We use it instead of Trello for one reason: it lives **next to our code**, so a card can link to the actual issue, branch, and Pull Request, and can move itself as work progresses.

| Trello | GitHub Projects (what we use) |
|---|---|
| Board | Project |
| List (column) | Column / Status |
| Card | Item / Draft issue |
| Label | Label |
| Member on a card | Assignee |
| Move card between lists | Drag between columns |

**One board, not two.** 
## The columns (fixed)

```
Backlog → Blocked → In Progress → In Review → Done
```

- **Backlog** — not started yet.
- **Blocked** — can't proceed; the card **must say what it's waiting on** (e.g. "Waiting on: SNS topic ARN"). This is how we make dependencies visible.
- **In Progress** — actively being built.
- **In Review** — a Pull Request is open and waiting for review.
- **Done** — merged and verified (Definition of Done met).

## One-time setup (the lead does this)

1. Repo → **Projects** tab → **New project** → **Board** template.
2. Rename the columns to the five above.
3. Project **Settings → Workflows** → enable the built-in automations so the board tracks reality without manual dragging:
   - *Item added to project* → **Backlog**
   - *Pull request opened* → **In Review**
   - *Pull request merged* → **Done**
4. Create the labels (Repo → Issues → Labels): `backbone`, `path-a`, `path-b`, `path-c`, `path-d`, `frontend`, `milestone` — color-code them so the board is scannable.
5. Seed the cards below, assign an owner to each, and drag to the right starting column.

## How we use it (everyone)

- **Move your own card** as you go: pick it up → **In Progress**; open a PR → it lands in **In Review**; merged + verified → **Done**.
- **Use Blocked honestly.** If you're waiting on someone, move the card to **Blocked** and write the reason in it. A card sitting in Blocked for more than a day is the lead's cue to step in.
- **One owner per card.** No unowned work.
- **Link your PR to the card** so it auto-moves and we can trace work → review → merge.

## Starting cards (one per task)

Create each as a **draft issue**: paste the title, then paste the body into the card. Build steps come from the team docs (`README.md`).

> Starting columns: **Backbone, React, and the four path "build" cards → In Progress** · **Path D → Blocked** (Bedrock model access) · **End-to-end test → Backlog**.

### 🏗️ ECS Backbone (API + SNS topic) — `backbone`
```
The API: receives orders, generates orderId + timestamp, publishes ONE message to SNS,
exposes /recommendation. Runs on ECS Fargate behind an ALB. THIS UNBLOCKS EVERYONE.

- [ ] Write + test API locally (node server.mjs) and the Dockerfile
- [ ] IAM: bb-ecs-execution-role + bb-ecs-task-role
- [ ] ECR repo brew-and-bean-coffee-api (private), build & push image
- [ ] ECS cluster brew-and-bean-cluster (Fargate)
- [ ] ALB + Target Group (IP, port 3000, health check /health, listener 80)
- [ ] Create SNS topic coffee-shop-orders  ← what all 4 paths wait on
- [ ] Task Definition (0.25 vCPU / 0.5 GB, both roles, port 3000, logs on)
- [ ] ECS Service (1 task, public IP, SG inbound 3000, attach ALB)
- [ ] CORS: Access-Control-Allow-Origin (coordinate with React owner)

Blocked on: nothing — critical path.
DoD: ALB DNS opens, /health green, test order returns success, ECS logs in CloudWatch.
Share the ALB DNS + SNS topic ARN with the team.
```

### 💾 Path A — Persistence (DynamoDB) — `path-a`
```
SNS → SQS → Lambda → DynamoDB. Save every order.

- [ ] DynamoDB table coffee-orders, PK orderId (String), on-demand
- [ ] (Coordinate w/ Path D) add GSI with PK customer
- [ ] SQS queue coffee-process-queue (Standard, visibility 30s)
- [ ] Lambda coffee-processor (Node 22.x), role bb-lambda-path-a-role
- [ ] Unit-test handler with docs/fake-sqs-event.json (no AWS needed)
- [ ] Subscribe queue to SNS + edit queue access policy (allow topic SendMessage)
- [ ] Add SQS trigger (batch size 1)

NOTE: read orderId + timestamp FROM the message — do NOT generate them.
Blocked on: SNS topic ARN (live test only).
DoD: test order → item in coffee-orders with the SAME orderId the API generated.
```

### 📊 Path B — Monitoring (CloudWatch) — `path-b`
```
SNS → SQS → Lambda → CloudWatch metrics + dashboard. Count and visualize orders.

- [ ] SQS queue coffee-analytics-queue (Standard)
- [ ] Subscribe to SNS + edit queue access policy
- [ ] Lambda coffee-analytics (Node 22.x), role bb-lambda-path-b-role
- [ ] Unit-test handler with docs/fake-sqs-event.json
- [ ] PutMetricData: namespace CoffeeShop, metric OrdersPlaced, dims item + size
- [ ] Add SQS trigger
- [ ] Build CloudWatch dashboard (OrdersPlaced over time + by drink type)

IAM note: cloudwatch:PutMetricData must be on "*".
Blocked on: SNS topic ARN (live test only).
DoD: test order → data point under Metrics → CoffeeShop → OrdersPlaced; dashboard renders.
```

### 🗄️ Path C — Analytics (S3 → Glue → Athena) — `path-c`
```
SNS → SQS → Lambda → S3 → Glue → Athena. Turn orders into queryable analytics.

- [ ] S3 bucket brew-and-bean-orders-<yourname> (block public access ON), prefixes orders/ and athena/
- [ ] SQS queue coffee-s3-queue + subscribe to SNS + edit access policy
- [ ] Lambda coffee-s3-writer (Node 22.x), role bb-lambda-path-c-role
- [ ] Unit-test with docs/fake-sqs-event.json
- [ ] Write JSON to Hive key orders/year=2026/month=06/day=01/<uuid>.json (from order timestamp)
- [ ] Add SQS trigger
- [ ] Glue DB coffee_db + table coffee_orders (S3 JSON, partitions year/month/day)
- [ ] Athena: result location athena/, MSCK REPAIR TABLE, run GROUP BY item

Blocked on: SNS topic ARN (live test). Glue/Athena blocked until S3 has files.
DoD: test order → partitioned JSON in S3, Athena GROUP BY item returns rows.
```

### 🤖 Path D — AI Recommender (Bedrock) — `path-d`
```
SNS → SQS → Lambda → Bedrock → coffee-recommendations. Suggest what a returning customer tries next.

- [ ] ⏰ Bedrock console (us-west-2) → Model access → request Claude Haiku (DO FIRST — lags hours)
- [ ] DynamoDB table coffee-recommendations, PK customer (String)
- [ ] (Coordinate w/ Path A) GSI on coffee-orders by customer
- [ ] SQS queue coffee-reco-queue + subscribe to SNS + edit access policy
- [ ] Lambda coffee-recommender (Node 22.x), role bb-lambda-path-d-role
- [ ] Unit-test with docs/fake-sqs-event.json
- [ ] Query GSI for history → prompt → InvokeModel (us.anthropic.claude-haiku-4-5-20251001-v1:0) → write reco
- [ ] Add SQS trigger

Blocked on: Bedrock model approval; SNS topic ARN; Path A's GSI.
DoD: returning customer's test order → "next time, try…" row in coffee-recommendations, retrievable via the API.
```

### 🌐 React Deploy (frontend → S3) — `frontend`
```
React order form deployed to S3 static hosting.

- [ ] Build UI against a mock/local API (Day 1): form + success message + amber "next time" box
- [ ] After order, poll GET /recommendation?customer=<name> every ~2s
- [ ] Swap in real ALB DNS once backbone is up
- [ ] npm run build → upload to S3 bucket with static website hosting
- [ ] Test end-to-end in browser

Watch out: CORS (coordinate w/ backbone), keep page on S3 HTTP endpoint (mixed-content trap).
Blocked on: ALB DNS (for real wiring; not blocked for UI build).
DoD: order from deployed S3 page → green success + amber suggestion a few seconds later.
```

### ✅ End-to-end test (the proof) — `milestone`
```
Place ONE order from the deployed page and verify ALL:
- [ ] Green success message
- [ ] Amber "next time" suggestion (~2–3s)
- [ ] Email arrives
- [ ] DynamoDB has the item (Path A)
- [ ] CloudWatch metric data point (Path B)
- [ ] Partitioned JSON in S3 (Path C)
- [ ] Athena query shows the order (Path C)
- [ ] Row in coffee-recommendations (Path D)
- [ ] ECS task logs show publish succeeded

Blocked on: all 6 build cards done.
DoD: every box checked → demo-ready.
```
