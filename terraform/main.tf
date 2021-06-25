#######
# VPC #
#######

# Quick and dirty basic VPC for our load balancer and containers to reside in.

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "hello_world"
  }
}

resource "aws_subnet" "a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "hello_world_b"
  }
}

resource "aws_subnet" "b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "hello_world_a"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "r" {
  route_table_id            = aws_vpc.main.main_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

###################
# SECURITY GROUPS #
###################

resource "aws_security_group" "lb" {
  name        = "hello_world_lb"
  description = "Allow http/https traffic from the world."
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 81
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "task" {
  name        = "hello_world_task"
  description = "Allow http/https traffic from the world."
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#######
# ECR #
#######

# ECR repository to store our container images in.
resource "aws_ecr_repository" "hello_world" {
  name                 = "helloworld"
  image_tag_mutability = "MUTABLE"
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for storing the helloworld web app."
  value = aws_ecr_repository.hello_world.repository_url
}

#######
# IAM #
#######

# Role that can read ECR and execute ECS tasks
resource "aws_iam_role" "hello_world" {
  name = "hello_world"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.hello_world.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.hello_world.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

#######
# ECS #
#######

# Cluster
resource "aws_ecs_cluster" "hello_world" {
  name               = "hello_world"
  capacity_providers = ["FARGATE"]
}

# Task definition of our tasks. 
resource "aws_ecs_task_definition" "hello_world" {
  family = "helloworld"
  network_mode = "awsvpc"
  cpu = 256
  memory = 512
  execution_role_arn = aws_iam_role.hello_world.arn
  container_definitions = jsonencode([
    {
      name      = "helloworld"
      image     = "${aws_ecr_repository.hello_world.repository_url}:1"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  # Ignore changes to the task which will be made by subsequent deployments
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# Two services, one green and one blue. 
resource "aws_ecs_service" "green" {
  name            = "green"
  launch_type = "FARGATE"
  cluster         = aws_ecs_cluster.hello_world.id
  task_definition = aws_ecs_task_definition.hello_world.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.green.arn
    container_name   = "helloworld"
    container_port   = 80
  }

  network_configuration {
    subnets = [aws_subnet.a.id, aws_subnet.b.id]
    security_groups = [aws_security_group.task.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "blue" {
  name            = "blue"
  launch_type = "FARGATE"
  cluster         = aws_ecs_cluster.hello_world.id
  task_definition = aws_ecs_task_definition.hello_world.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "helloworld"
    container_port   = 80
  }

  network_configuration {
    subnets = [aws_subnet.a.id, aws_subnet.b.id]
    security_groups = [aws_security_group.task.id]
    assign_public_ip = true
  }
}

#######
# ALB #
#######

# The load balancer itself. 
# In the green/blue architecture this acts as the "router".
resource "aws_lb" "hello_world" {
  name               = "helloworld"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [aws_subnet.a.id, aws_subnet.b.id]
  depends_on         = [aws_internet_gateway.igw]
}

output "load_balancer_url" {
  description = "URL for accessing the helloworld web app."
  value = aws_lb.hello_world.dns_name
}

# Two target groups, one green and one blue.
resource "aws_lb_target_group" "green" {
  name     = "green"
  target_type = "ip"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

output "green_target_group_arn" {
  description = "ARN of the green ALB target group."
  value = aws_lb_target_group.green.arn
}

resource "aws_lb_target_group" "blue" {
  name     = "blue"
  target_type = "ip"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

output "blue_target_group_arn" {
  description = "ARN of the blue ALB target group."
  value = aws_lb_target_group.blue.arn
}

# Two listeners
# This is where the blue/green switch will take place.
# At first active = green, inactive = blue
resource "aws_lb_listener" "active" {
  load_balancer_arn = aws_lb.hello_world.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

output "primary_listener_arn" {
  value = aws_lb_listener.active.arn
  description = "ARN of the primary load balancer listener"
}

resource "aws_lb_listener" "inactive" {
  load_balancer_arn = aws_lb.hello_world.arn
  port              = "81"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

output "secondary_listener_arn" {
  value = aws_lb_listener.inactive.arn
  description = "ARN of the secondary load balancer listener"
}