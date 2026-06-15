resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/brew-and-bean-coffee-api"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = "brew-and-bean-cluster"
}

resource "aws_ecs_task_definition" "coffee_api" {
  family                   = "brew-and-bean-coffee-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = "coffee-api"
    image     = "${aws_ecr_repository.coffee_api.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "coffee_api" {
  name            = "brew-and-bean-coffee-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.coffee_api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "coffee-api"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.http]
}
