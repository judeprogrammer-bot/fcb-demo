# =============================================================================
# App Team: Wealth Management Portal
# Platform: 1.0 (LEGACY - NOT MIGRATED)
# Risk: MEDIUM - RDS + legacy networking, standard patterns
# Owner: Wealth Management Engineering
# Last modified: 2024-09-18
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67"
    }
  }
  backend "s3" {
    bucket         = "fcb-legacy-tfstate"
    key            = "wealth-mgmt/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-legacy"
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- NETWORKING (legacy) ---

resource "aws_vpc" "wealth" {
  cidr_block           = "10.5.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  # MISSING: VPC flow logs
  tags = { Name = "wealth-mgmt-vpc", Team = "wealth-management" }
}

resource "aws_subnet" "wealth_private_a" {
  vpc_id            = aws_vpc.wealth.id
  cidr_block        = "10.5.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "wealth-private-a" }
}

resource "aws_subnet" "wealth_private_b" {
  vpc_id            = aws_vpc.wealth.id
  cidr_block        = "10.5.2.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "wealth-private-b" }
}

# --- ECS SERVICE ---

resource "aws_ecs_cluster" "wealth" {
  name = "wealth-mgmt-cluster"
  tags = { Team = "wealth-management" }
}

resource "aws_ecs_task_definition" "wealth_portal" {
  family                   = "wealth-portal"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.wealth_execution.arn
  task_role_arn            = aws_iam_role.wealth_task.arn

  container_definitions = jsonencode([
    {
      name      = "wealth-portal"
      image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/wealth-portal:latest"
      cpu       = 2048
      memory    = 4096
      essential = true
      portMappings = [{ containerPort = 443, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/wealth-portal"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "wealth"
        }
      }
    }
  ])
}

# --- IAM (LEGACY - INLINE POLICIES) ---

resource "aws_iam_role" "wealth_task" {
  name = "wealth-portal-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "wealth-data-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["s3:GetObject", "s3:ListBucket"]
          Resource = [
            "arn:aws:s3:::fcb-wealth-client-data-prod",
            "arn:aws:s3:::fcb-wealth-client-data-prod/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:wealth/*"]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = ["*"]
        }
      ]
    })
  }
}

resource "aws_iam_role" "wealth_execution" {
  name = "wealth-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "execution-permissions"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["*"]
      }]
    })
  }
}

# --- SECURITY GROUPS (LEGACY) ---

resource "aws_security_group" "wealth_app" {
  name        = "wealth-portal-sg"
  description = "Wealth management portal"
  vpc_id      = aws_vpc.wealth.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.5.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "wealth-portal-sg", Team = "wealth-management" }
}

# --- RDS ---

resource "aws_db_subnet_group" "wealth" {
  name       = "wealth-db-subnets"
  subnet_ids = [aws_subnet.wealth_private_a.id, aws_subnet.wealth_private_b.id]
}

resource "aws_db_instance" "wealth" {
  identifier     = "wealth-portal-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.xlarge"

  allocated_storage     = 200
  max_allocated_storage = 1000
  storage_encrypted     = true

  db_name  = "wealth_portal"
  username = "wealth_admin"
  password = "PLACEHOLDER_USE_SECRETS_MANAGER"

  vpc_security_group_ids = [aws_security_group.wealth_db.id]
  db_subnet_group_name   = aws_db_subnet_group.wealth.name

  backup_retention_period = 14
  multi_az                = true
  skip_final_snapshot     = false

  tags = { Team = "wealth-management" }
}

resource "aws_security_group" "wealth_db" {
  name        = "wealth-db-sg"
  vpc_id      = aws_vpc.wealth.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.wealth_app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "wealth-db-sg" }
}

# --- S3 (no public access block) ---

resource "aws_s3_bucket" "wealth_data" {
  bucket = "fcb-wealth-client-data-prod"
  tags   = { Team = "wealth-management" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "wealth_data" {
  bucket = aws_s3_bucket.wealth_data.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
  }
}
