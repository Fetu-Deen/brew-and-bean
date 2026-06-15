resource "aws_s3_bucket" "orders" {
  bucket        = var.s3_orders_bucket
  force_destroy = true

  tags = { Project = var.project }
}
