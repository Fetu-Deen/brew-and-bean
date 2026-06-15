data "archive_file" "path_a" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/path-a-persistence/index.mjs"
  output_path = "${path.module}/.build/path-a.zip"
}

data "archive_file" "path_b" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/path-b-monitoring/index.mjs"
  output_path = "${path.module}/.build/path-b.zip"
}

data "archive_file" "path_c" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/path-c-writer/index.mjs"
  output_path = "${path.module}/.build/path-c.zip"
}

data "archive_file" "path_d" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/path-d-recommender/index.mjs"
  output_path = "${path.module}/.build/path-d.zip"
}

resource "aws_lambda_function" "coffee_processor" {
  function_name    = "coffee-processor"
  role             = aws_iam_role.lambda_path_a.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  architectures    = ["x86_64"]
  filename         = data.archive_file.path_a.output_path
  source_code_hash = data.archive_file.path_a.output_base64sha256
  timeout          = 10

  tags = { Project = var.project, Path = "A" }
}

resource "aws_lambda_function" "coffee_analytics" {
  function_name    = "coffee-analytics"
  role             = aws_iam_role.lambda_path_b.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  architectures    = ["x86_64"]
  filename         = data.archive_file.path_b.output_path
  source_code_hash = data.archive_file.path_b.output_base64sha256
  timeout          = 10

  tags = { Project = var.project, Path = "B" }
}

resource "aws_lambda_function" "coffee_s3_writer" {
  function_name    = "coffee-s3-writer"
  role             = aws_iam_role.lambda_path_c.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  architectures    = ["x86_64"]
  filename         = data.archive_file.path_c.output_path
  source_code_hash = data.archive_file.path_c.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      BUCKET = var.s3_orders_bucket
    }
  }

  tags = { Project = var.project, Path = "C" }
}

resource "aws_lambda_function" "coffee_recommender" {
  function_name    = "coffee-recommender"
  role             = aws_iam_role.lambda_path_d.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  architectures    = ["x86_64"]
  filename         = data.archive_file.path_d.output_path
  source_code_hash = data.archive_file.path_d.output_base64sha256
  timeout          = 30

  tags = { Project = var.project, Path = "D" }
}

resource "aws_lambda_event_source_mapping" "path_a" {
  event_source_arn = aws_sqs_queue.process.arn
  function_name    = aws_lambda_function.coffee_processor.arn
  batch_size       = 10
}

resource "aws_lambda_event_source_mapping" "path_b" {
  event_source_arn = aws_sqs_queue.analytics.arn
  function_name    = aws_lambda_function.coffee_analytics.arn
  batch_size       = 10
}

resource "aws_lambda_event_source_mapping" "path_c" {
  event_source_arn = aws_sqs_queue.s3_writer.arn
  function_name    = aws_lambda_function.coffee_s3_writer.arn
  batch_size       = 10
}

resource "aws_lambda_event_source_mapping" "path_d" {
  event_source_arn                   = aws_sqs_queue.recommendation.arn
  function_name                      = aws_lambda_function.coffee_recommender.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0
}
