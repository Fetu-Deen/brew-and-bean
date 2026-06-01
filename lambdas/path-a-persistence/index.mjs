// Path A — Persistence: SNS → SQS → Lambda → DynamoDB
// Function: coffee-processor   Runtime: Node.js 22.x   Role: bb-lambda-path-a-role
//
// TEST FIRST (no AWS needed): Lambda console → Test tab → paste docs/fake-sqs-event.json → Test.
// Confirm CloudWatch Logs print the right orderId/customer/item/size.
// THEN add the DynamoDB write, THEN subscribe the queue to the real SNS topic.

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

const ddb   = DynamoDBDocumentClient.from(new DynamoDBClient({ region: "us-west-2" }));
const TABLE = "coffee-orders";

export const handler = async (event) => {
  // --- unwrap the double envelope (SQS box → SNS box → order) ---
  for (const record of event.Records) {
    const snsEnvelope = JSON.parse(record.body);
    const order       = JSON.parse(snsEnvelope.Message);
    const { orderId, customer, item, size, timestamp } = order;

    console.log("Path A got order:", { orderId, customer, item, size, timestamp });

    // --- do Path A's job: save the order ---
    // While testing the unwrap alone, comment this block out and just read the log.
    await ddb.send(new PutCommand({
      TableName: TABLE,
      Item: { orderId, customer, item, size, timestamp },
    }));
    console.log("✓ Saved to DynamoDB:", orderId);
  }

  return { statusCode: 200 };
};
