// Path C — Analytics: SNS → SQS → Lambda → S3 (→ Glue → Athena)
// Function: coffee-s3-writer   Runtime: Node.js 22.x   Role: bb-lambda-path-c-role
//
// TEST FIRST: Lambda console → Test tab → paste docs/fake-sqs-event.json → Test.
// Then point Glue at s3://<bucket>/orders/ and run MSCK REPAIR TABLE in Athena.

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { randomUUID } from "node:crypto";

const s3     = new S3Client({ region: "us-west-2" });
const BUCKET = "brew-and-bean-orders-CHANGEME"; // <-- your globally-unique bucket

export const handler = async (event) => {
  // --- unwrap the double envelope ---
  for (const record of event.Records) {
    const snsEnvelope = JSON.parse(record.body);
    const order       = JSON.parse(snsEnvelope.Message);
    const { orderId, customer, item, size, timestamp } = order;

    console.log("Path C got order:", { orderId, customer, item, size, timestamp });

    // --- do Path C's job: write JSON to a Hive-partitioned S3 key ---
    // Derive year/month/day from the order's timestamp (NOT "now").
    const d     = new Date(timestamp);
    const year  = d.getUTCFullYear();
    const month = String(d.getUTCMonth() + 1).padStart(2, "0");
    const day   = String(d.getUTCDate()).padStart(2, "0");
    const key   = `orders/year=${year}/month=${month}/day=${day}/${randomUUID()}.json`;

    await s3.send(new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      ContentType: "application/json",
      Body: JSON.stringify({ orderId, customer, item, size, timestamp }),
    }));
    console.log("✓ Wrote to S3:", key);
  }

  return { statusCode: 200 };
};
