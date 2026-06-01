// Shared helper — used by ALL four paths so everyone unwraps identically.
//
// The order travels: API → SNS → SQS → your Lambda.
// Each hop wraps it in a string, so what your Lambda receives is double-wrapped:
//
//   event.Records[n].body            → a STRING that is the SNS envelope
//   JSON.parse(...).Message          → a STRING that is the actual order
//   JSON.parse(...)                  → the order object you can finally read
//
// This assumes SNS "Raw Message Delivery" is OFF (the default, and what the
// team doc's "double envelope" wording expects). Keep it off on every path.

export function unwrapOrders(event) {
  return event.Records.map((record) => {
    const snsEnvelope = JSON.parse(record.body);     // open the SQS box
    const order       = JSON.parse(snsEnvelope.Message); // open the SNS box
    return order;                                    // { orderId, customer, item, size, timestamp }
  });
}
