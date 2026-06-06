import express from "express";
import { SNSClient, PublishCommand } from "@aws-sdk/client-sns";
import { randomUUID } from "crypto";

const REGION    = "us-west-2";
const TOPIC_ARN = "arn:aws:sns:us-west-2:269742496681:coffee-shop-orders";

const app = express();
const sns = new SNSClient({ region: REGION });

app.use(express.json());

// Let the browser frontend call this API.
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.sendStatus(200);
  next();
});

// The ALB hits this to check the container is alive.
app.get("/health", (_req, res) => res.json({ status: "ok" }));

// Place an order: the API creates the orderId, then publishes the order to SNS.
app.post("/", async (req, res) => {
  const { customer, item, size } = req.body;

  if (!customer || !item || !size) {
    return res.status(400).json({ error: "Missing customer, item, or size" });
  }

  const order = {
    orderId:   randomUUID(),
    customer,
    item,
    size,
    timestamp: new Date().toISOString(),
  };

  try {
    await sns.send(new PublishCommand({
      TopicArn: TOPIC_ARN,
      Subject:  `New coffee order: ${item}`,
      Message:  JSON.stringify(order),
    }));
    console.log("Published order:", order.orderId);
    res.json({ status: "Order received! Check your email.", orderId: order.orderId });
  } catch (err) {
    console.error("Error:", err);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`coffee-api listening on port ${PORT}`));
