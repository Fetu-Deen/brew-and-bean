data "aws_iam_policy_document" "ecs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "bb-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "bb-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

resource "aws_iam_role_policy" "ecs_task_inline" {
  name = "bb-ecs-task-policy"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PublishOrders"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.orders.arn
      },
      {
        Sid      = "ReadRecommendations"
        Effect   = "Allow"
        Action   = "dynamodb:GetItem"
        Resource = aws_dynamodb_table.recommendations.arn
      }
    ]
  })
}

resource "aws_iam_role" "lambda_path_a" {
  name               = "bb-lambda-path-a-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_a_basic" {
  role       = aws_iam_role.lambda_path_a.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_a_sqs" {
  role       = aws_iam_role.lambda_path_a.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "lambda_a_dynamo" {
  name = "dynamodb-put"
  role = aws_iam_role.lambda_path_a.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PutOrders"
      Effect   = "Allow"
      Action   = "dynamodb:PutItem"
      Resource = aws_dynamodb_table.orders.arn
    }]
  })
}

resource "aws_iam_role" "lambda_path_b" {
  name               = "bb-lambda-path-b-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_b_basic" {
  role       = aws_iam_role.lambda_path_b.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_b_sqs" {
  role       = aws_iam_role.lambda_path_b.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "lambda_b_cw" {
  name = "cloudwatch-put-metrics"
  role = aws_iam_role.lambda_path_b.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "cloudwatch:PutMetricData"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "lambda_path_c" {
  name               = "bb-lambda-path-c-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_c_basic" {
  role       = aws_iam_role.lambda_path_c.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_c_sqs" {
  role       = aws_iam_role.lambda_path_c.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "lambda_c_s3" {
  name = "s3-put-orders"
  role = aws_iam_role.lambda_path_c.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.orders.arn}/*"
    }]
  })
}

resource "aws_iam_role" "lambda_path_d" {
  name               = "bb-lambda-path-d-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_d_basic" {
  role       = aws_iam_role.lambda_path_d.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_d_sqs" {
  role       = aws_iam_role.lambda_path_d.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "lambda_d_inline" {
  name = "bedrock-dynamo"
  role = aws_iam_role.lambda_path_d.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeBedrock"
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = "*"
      },
      {
        Sid      = "WriteRecommendations"
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.recommendations.arn
      },
      {
        Sid      = "ReadOrderHistory"
        Effect   = "Allow"
        Action   = "dynamodb:Query"
        Resource = [
          aws_dynamodb_table.orders.arn,
          "${aws_dynamodb_table.orders.arn}/index/customer-index"
        ]
      }
    ]
  })
}
