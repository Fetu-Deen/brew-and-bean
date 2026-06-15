resource "aws_ecr_repository" "coffee_api" {
  name                 = "brew-and-bean-coffee-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = { Project = var.project }
}
