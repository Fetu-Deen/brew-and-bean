// Path D — AI Recommender: SNS → SQS → Lambda → Bedrock → coffee-recommendations
// Function: coffee-recommender   Runtime: Node.js 22.x   Role: bb-lambda-path-d-role
//
// TEST FIRST: Lambda console → Test tab → paste docs/fake-sqs-event.json → Test.
// (Request Bedrock "Claude Haiku" model access EARLY — approval can take hours.)

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

const ddb     = DynamoDBDocumentClient.from(new DynamoDBClient({ region: "us-west-2" }));
const bedrock = new BedrockRuntimeClient({ region: "us-west-2" });
const MODEL_ID    = "us.anthropic.claude-haiku-4-5-20251001-v1:0";
const ORDERS      = "coffee-orders";
const RECO_TABLE  = "coffee-recommendations";

export const handler = async (event) => {
  // --- unwrap the double envelope ---
  for (const record of event.Records) {
    const snsEnvelope = JSON.parse(record.body);
    const order       = JSON.parse(snsEnvelope.Message);
    const { customer, item, size } = order;

    console.log("Path D got order:", { customer, item, size });

    // --- look up this customer's history via the GSI on coffee-orders ---
    // (Requires the "customer" GSI — coordinate with Path A.)
    const history = await ddb.send(new QueryCommand({
      TableName: ORDERS,
      IndexName: "customer-index",
      KeyConditionExpression: "customer = :c",
      ExpressionAttributeValues: { ":c": customer },
    })).catch((e) => { console.log("history lookup skipped:", e.message); return { Items: [] }; });

    const past = (history.Items || []).map((o) => o.item).join(", ") || "none";

    // --- ask Bedrock for ONE new-but-related suggestion ---
    const prompt = `A coffee shop customer named ${customer} just ordered a ${size} ${item}. ` +
      `Their past orders: ${past}. Suggest ONE different drink from a typical coffee menu ` +
      `they might enjoy next time, with a one-line reason. Reply with just that sentence.`;

    const res = await bedrock.send(new InvokeModelCommand({
      modelId: MODEL_ID,
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify({
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 80,
        messages: [{ role: "user", content: prompt }],
      }),
    }));
    const recommendation = JSON.parse(Buffer.from(res.body).toString()).content[0].text.trim();
    console.log("✓ Recommendation:", recommendation);

    // --- save the latest suggestion for this customer ---
    await ddb.send(new PutCommand({
      TableName: RECO_TABLE,
      Item: { customer, recommendation, updatedAt: new Date().toISOString() },
    }));
  }

  return { statusCode: 200 };
};
