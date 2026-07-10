# =============================================================================
# App Team: Lending Platform
# Platform: PARTIAL MIGRATION (VPC migrated, IAM still legacy)
# Risk: MEDIUM - Mix of old and new patterns
# Owner: Lending Engineering
# Last modified: 2025-03-10
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "fcb-platform-v2-tfstate"
    key            = "lending/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-v2"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Team        = "lending"
      ManagedBy   = "terraform"
      Environment = "production"
    }
  }
}

# --- NETWORKING (MIGRATED TO 2.0 MODULE) ---

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "lending-vpc"
  cidr = "10.3.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.3.1.0/24", "10.3.2.0/24", "10.3.3.0/24"]
  public_subnets  = ["10.3.101.0/24", "10.3.102.0/24", "10.3.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false

  # CCF Compliant - flow logs enabled
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  tags = { Platform = "2.0" }
}

# --- IAM (STILL LEGACY - NOT YET MIGRATED) ---
# TODO: Migrate to platform-modules/iam-role

resource "aws_iam_role" "lending_api_task" {
  name = "lending-api-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  # STILL USING INLINE POLICY - needs migration to managed policy
  inline_policy {
    name = "lending-api-permissions"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::fcb-lending-documents-prod",
            "arn:aws:s3:::fcb-lending-documents-prod/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = [
            "arn:aws:secretsmanager:us-east-1:123456789012:secret:lending/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = ["*"]  # Still overly broad
        }
      ]
    })
  }

  tags = { MigrationStatus = "pending-iam" }
}

resource "aws_iam_role" "lending_execution" {
  name = "lending-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  # Inline policy - should use AWS managed policy
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

# --- S3 (MIGRATED TO 2.0 MODULE) ---

module "lending_documents" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "fcb-lending-documents-prod"

  versioning = { enabled = true }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "aws:kms"
      }
      bucket_key_enabled = true
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = { Platform = "2.0" }
}

# --- SECURITY GROUP (STILL LEGACY) ---
# TODO: Migrate to platform-modules/networking

resource "aws_security_group" "lending_app" {
  name        = "lending-app-sg"
  description = "Lending application"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.3.0.0/16"]
  }

  # STILL OPEN EGRESS - needs restriction
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lending-app-sg", MigrationStatus = "pending-sg" }
}
