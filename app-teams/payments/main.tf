# =============================================================================
# App Team: Payments Processing
# Platform: 1.0 (LEGACY - NOT MIGRATED)
# Risk: HIGH - Inline IAM policies, open egress, no flow logs
# Owner: Jeremy Axmacher
# Last modified: 2024-11-15
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
    key            = "payments/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-legacy"
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- NETWORKING (legacy, no flow logs) ---

resource "aws_vpc" "payments" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "payments-vpc"
    Team = "payments"
  }
}

resource "aws_subnet" "payments_private_a" {
  vpc_id            = aws_vpc.payments.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "payments-private-a" }
}

resource "aws_subnet" "payments_private_b" {
  vpc_id            = aws_vpc.payments.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "payments-private-b" }
}

# --- ECS CLUSTER AND SERVICE ---

resource "aws_ecs_cluster" "payments" {
  name = "payments-cluster"
  tags = { Team = "payments" }
}

resource "aws_ecs_task_definition" "payments_api" {
  family                   = "payments-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.payments_task.arn

  container_definitions = jsonencode([
    {
      name      = "payments-api"
      image     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/payments-api:latest"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.payments.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "payments-api"
        }
      }
      environment = [
        { name = "DB_HOST", value = aws_db_instance.payments.endpoint },
        { name = "S3_BUCKET", value = aws_s3_bucket.payments_data.bucket }
      ]
    }
  ])
}

resource "aws_ecs_service" "payments_api" {
  name            = "payments-api"
  cluster         = aws_ecs_cluster.payments.id
  task_definition = aws_ecs_task_definition.payments_api.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.payments_private_a.id, aws_subnet.payments_private_b.id]
    security_groups = [aws_security_group.payments_app.id]
  }
}

# --- IAM ROLES (LEGACY - INLINE POLICIES) ---
# WARNING: These trigger Sentinel soft-fail requiring Cloud Security manual review

resource "aws_iam_role" "payments_task" {
  name = "payments-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  # INLINE POLICY - Sentinel soft-fail trigger
  inline_policy {
    name = "payments-s3-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.payments_data.arn,
            "${aws_s3_bucket.payments_data.arn}/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
          Resource = ["*"]  # OVERLY BROAD - Wiz will flag this
        },
        {
          Effect = "Allow"
          Action = [
            "rds:DescribeDBInstances",
            "rds:DescribeDBClusters"
          ]
          Resource = ["*"]
        }
      ]
    })
  }

  # ANOTHER INLINE POLICY - SQS access
  inline_policy {
    name = "payments-sqs-access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [aws_sqs_queue.payment_events.arn]
      }]
    })
  }

  tags = { Team = "payments" }
}

resource "aws_iam_role" "ecs_execution" {
  name = "payments-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  # INLINE POLICY for ECR pull + CloudWatch
  inline_policy {
    name = "ecs-execution-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage"
          ]
          Resource = ["*"]
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = ["*"]
        }
      ]
    })
  }
}

# --- SECURITY GROUPS (LEGACY - OPEN EGRESS) ---

resource "aws_security_group" "payments_app" {
  name        = "payments-app-sg"
  description = "Payments application"
  vpc_id      = aws_vpc.payments.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
    description = "App port from VPC"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
    description = "HTTPS from VPC"
  }

  # OPEN EGRESS - Platform 2.0 requires restricted egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "payments-app-sg", Team = "payments" }
}

resource "aws_security_group" "payments_db" {
  name        = "payments-db-sg"
  description = "Payments database"
  vpc_id      = aws_vpc.payments.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.payments_app.id]
    description     = "PostgreSQL from app"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "payments-db-sg", Team = "payments" }
}

# --- RDS DATABASE ---

resource "aws_db_instance" "payments" {
  identifier     = "payments-db"
  engine         = "postgres"
  engine_version = "14.9"
  instance_class = "db.r5.large"

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_encrypted     = true

  db_name  = "payments"
  username = "payments_admin"
  password = "CHANGEME_not_in_real_code"  # Should use Secrets Manager

  vpc_security_group_ids = [aws_security_group.payments_db.id]
  db_subnet_group_name   = aws_db_subnet_group.payments.name

  backup_retention_period = 7
  multi_az                = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "payments-db-final"

  tags = { Team = "payments" }
}

resource "aws_db_subnet_group" "payments" {
  name       = "payments-db-subnets"
  subnet_ids = [aws_subnet.payments_private_a.id, aws_subnet.payments_private_b.id]
}

# --- S3 BUCKET (no public access block - Wiz will flag) ---

resource "aws_s3_bucket" "payments_data" {
  bucket = "fcb-payments-transaction-data-prod"
  tags   = { Team = "payments" }
}

resource "aws_s3_bucket_versioning" "payments_data" {
  bucket = aws_s3_bucket.payments_data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "payments_data" {
  bucket = aws_s3_bucket.payments_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# MISSING: aws_s3_bucket_public_access_block - Wiz critical finding

# --- SQS QUEUE ---

resource "aws_sqs_queue" "payment_events" {
  name                       = "payment-events"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 1209600
  # MISSING: KMS encryption - Sentinel hard-fail on 2.0
  tags = { Team = "payments" }
}

# --- CLOUDWATCH ---

resource "aws_cloudwatch_log_group" "payments" {
  name              = "/ecs/payments-api"
  retention_in_days = 90
  # MISSING: KMS encryption for logs
  tags = { Team = "payments" }
}
