resource "aws_dynamodb_table" "orders" {
  name         = "coffee-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "orderId"

  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "customer"
    type = "S"
  }

  global_secondary_index {
    name            = "customer-index"
    hash_key        = "customer"
    projection_type = "ALL"
  }

  tags = { Project = var.project }
}

resource "aws_dynamodb_table" "recommendations" {
  name         = "coffee-recommendations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customer"

  attribute {
    name = "customer"
    type = "S"
  }

  tags = { Project = var.project }
}
