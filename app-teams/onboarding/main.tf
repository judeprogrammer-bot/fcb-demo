# =============================================================================
# App Team: Customer Onboarding
# Platform: 2.0 (FULLY MIGRATED)
# Risk: LOW - All pre-approved modules, passes Sentinel + Wiz
# Owner: Digital Banking Team
# Last modified: 2025-04-02
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
    key            = "onboarding/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-v2"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Team        = "onboarding"
      Platform    = "2.0"
      ManagedBy   = "terraform"
      Environment = "production"
      Compliance  = "CCF-approved"
    }
  }
}

# --- NETWORKING (2.0 MODULE) ---

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "onboarding-vpc"
  cidr = "10.4.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.4.1.0/24", "10.4.2.0/24"]
  public_subnets  = ["10.4.101.0/24", "10.4.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
}

# --- IAM (2.0 MODULE - PRE-APPROVED) ---

module "app_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = true
  role_name   = "onboarding-app-role"

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    module.s3_policy.arn,
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

module "s3_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 5.0"

  name        = "onboarding-s3-access"
  description = "Scoped S3 access for onboarding application"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          module.documents_bucket.s3_bucket_arn,
          "${module.documents_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [module.documents_bucket.s3_bucket_arn]
      }
    ]
  })
}

# --- S3 (2.0 MODULE) ---

module "documents_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "fcb-onboarding-documents-prod"

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
}

# --- SECURITY GROUP (2.0 MODULE) ---

module "app_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "onboarding-app-sg"
  description = "Onboarding application - CCF compliant"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = module.vpc.vpc_cidr_block
      description = "App port from VPC only"
    }
  ]

  # RESTRICTED EGRESS - only HTTPS outbound
  egress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS outbound only"
    }
  ]
}
