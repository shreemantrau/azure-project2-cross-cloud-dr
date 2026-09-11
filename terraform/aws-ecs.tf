// ECR repositories - AWS equivalent of ACR, holds our container image

resource "aws_ecr_repository" "app" {
  name = "proj2dr-app"
}

resource "aws_ecr_repository" "web" {
  name = "proj2dr-web"
}

// ECS Cluster - logical grouping for Fargate tasks to run in
resource "aws_ecs_cluster" "main" {
  name = "proj2dr-cluster"
}

// IAM role ECS uses to pull images and write logs - not the same as our terraform-admin user
resource "aws_iam_role" "ecs_task_execution" {
  name = "proj2dr-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

// Attaches AWS's managed policy covering ECR pull + CloudWatch logging permissions
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// Task Definition - the container spec: image, resources, port. Equivalent of App Service's application_stack block
resource "aws_ecs_task_definition" "app" {
  family                   = "proj2dr-app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "app-proj2dr-app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "RDS_HOST", value = split(":", aws_db_instance.main.endpoint)[0] },
        { name = "RDS_DB", value = aws_db_instance.main.db_name },
        { name = "RDS_USER", value = aws_db_instance.main.username },
        { name = "RDS_PASSWORD", value = var.rds_password }
      ]
    }
  ])
}

// Cloud Map namespace - private DNS zone for service discovery within our VPC
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "proj2dr.local"
  vpc  = aws_vpc.main.id
}

// Registers the app tier under this namespace, giving it a real internal DNS name
resource "aws_service_discovery_service" "app" {
  name = "app"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_ecs_service" "app" {
  name            = "proj2dr-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.app.arn
  }
}

// Task Definition - web tier container spec
// NOTE: APP_TIER_URL is a placeholder - ECS has no built-in equivalent of App Service's
// default_hostname. Needs AWS Service Discovery (Cloud Map) or an internal load balancer
// to give the app tier a real internal DNS name web tier can reach. Not yet solved.
resource "aws_ecs_task_definition" "web" {
  family                   = "proj2dr-web-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "web-proj2dr-web"
      image     = "${aws_ecr_repository.web.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "APP_TIER_URL", value = "http://app.proj2dr.local:5000" },
        { name = "CLOUD_PROVIDER", value = "AWS" }
      ]
    }
  ])
}

resource "aws_ecs_service" "web" {
  name            = "proj2dr-web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}