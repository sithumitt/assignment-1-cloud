# ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name                 = "my-node-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Force delete repo
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "assignment-1-cluster"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/my-node-app"
  retention_in_days = 7
}

# Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole_Assignment1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-node-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  # App S3 Access
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "my-node-app-container"
    image     = aws_ecr_repository.app_repo.repository_url
    essential = true
    
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/my-node-app"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }

    # Pass Bucket Name
    environment = [
      {
        name  = "BUCKET_NAME"
        value = aws_s3_bucket.app_bucket.id # Terraform fills this
      },
      {
        name  = "AWS_REGION"
        value = "us-east-1"
      }
    ]
  }])
}

resource "aws_ecs_service" "app_service" {
  name            = "my-node-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = true # Public IP required
  }
}