// Path B — Monitoring: SNS → SQS → Lambda → CloudWatch metrics
// Function: coffee-analytics   Runtime: Node.js 22.x   Role: bb-lambda-path-b-role
//
// TEST FIRST: Lambda console → Test tab → paste docs/fake-sqs-event.json → Test.
// Then build a CloudWatch dashboard on the CoffeeShop / OrdersPlaced metric.

import { CloudWatchClient, PutMetricDataCommand } from "@aws-sdk/client-cloudwatch";

const cw = new CloudWatchClient({ region: "us-west-2" });

export const handler = async (event) => {
  // --- unwrap the double envelope ---
  for (const record of event.Records) {
    const snsEnvelope = JSON.parse(record.body);
    const order       = JSON.parse(snsEnvelope.Message);
    const { orderId, item, size } = order;

    console.log("Path B got order:", { orderId, item, size });

    // --- do Path B's job: count the order as a metric ---
    await cw.send(new PutMetricDataCommand({
      Namespace: "CoffeeShop",
      MetricData: [{
        MetricName: "OrdersPlaced",
        Value: 1,
        Unit: "Count",
        Dimensions: [
          { Name: "Item", Value: item },
          { Name: "Size", Value: size },
        ],
      }],
    }));
    console.log("✓ Metric published for:", item, size);
  }

  return { statusCode: 200 };
};
