# main.tf

provider "aws" {
  region = "us-east-1" # You can change this to your preferred region
}

data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# 1. NETWORKING (VPC, Subnets, IGW)
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "assignment-1-vpc" }
}

# Internet Gateway (Required for Fargate to pull images from ECR)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "assignment-1-igw" }
}

# Public Subnet 1
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "assignment-1-subnet-1" }
}

# Public Subnet 2 (High availability requirement)
resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "assignment-1-subnet-2" }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------------------------------------------------------------
# 2. SECURITY GROUPS
# ------------------------------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Allow port 8080"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to world (for testing)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# 3. ECR REPOSITORY (To store Docker Images)
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = "my-node-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Allows destroying repo even if it has images
}

# ------------------------------------------------------------------------------
# 4. ECS CLUSTER (Fargate)
# ------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "assignment-1-cluster"
}

# Create a Log Group in CloudWatch
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/my-node-app"
  retention_in_days = 7
}

# ------------------------------------------------------------------------------
# 5. IAM ROLES (Task Execution Role)
# ------------------------------------------------------------------------------
# This role allows ECS to pull images from ECR and send logs to CloudWatch
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

# ------------------------------------------------------------------------------
# 6. ECS TASK DEFINITION & SERVICE
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-node-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "my-node-app-container"
    image     = aws_ecr_repository.app_repo.repository_url
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    
    # --- NEW: LOGGING CONFIGURATION ---
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/my-node-app"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }
    # ----------------------------------
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
    assign_public_ip = true # Required for pulling images in public subnets
  }

  # Ensure the IAM Role permissions are attached before the service starts
  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy
  ]
}

# ------------------------------------------------------------------------------
# 7. OUTPUTS (Useful for GitHub Actions)
# ------------------------------------------------------------------------------
output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "ecs_service_name" {
  value = aws_ecs_service.app_service.name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}