resource "aws_sqs_queue" "process" {
  name = "coffee-process-queue"
}

resource "aws_sqs_queue" "analytics" {
  name = "coffee-analytics-queue"
}

resource "aws_sqs_queue" "s3_writer" {
  name = "coffee-s3-queue"
}

resource "aws_sqs_queue" "recommendation" {
  name = "coffee-recommendation-queue"
}

resource "aws_sns_topic_subscription" "path_a" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.process.arn
  raw_message_delivery = false
}

resource "aws_sns_topic_subscription" "path_b" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.analytics.arn
  raw_message_delivery = false
}

resource "aws_sns_topic_subscription" "path_c" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.s3_writer.arn
  raw_message_delivery = false
}

resource "aws_sns_topic_subscription" "path_d" {
  topic_arn            = aws_sns_topic.orders.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.recommendation.arn
  raw_message_delivery = false
}

resource "aws_sqs_queue_policy" "process" {
  queue_url = aws_sqs_queue.process.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.process.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.orders.arn } }
    }]
  })
}

resource "aws_sqs_queue_policy" "analytics" {
  queue_url = aws_sqs_queue.analytics.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.analytics.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.orders.arn } }
    }]
  })
}

resource "aws_sqs_queue_policy" "s3_writer" {
  queue_url = aws_sqs_queue.s3_writer.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.s3_writer.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.orders.arn } }
    }]
  })
}

resource "aws_sqs_queue_policy" "recommendation" {
  queue_url = aws_sqs_queue.recommendation.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.recommendation.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.orders.arn } }
    }]
  })
}
